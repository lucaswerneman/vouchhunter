import concurrent.futures
import hashlib
import hmac
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from backend.app import App, Problem, now, uid


class PlatformTests(unittest.TestCase):
    def setUp(self):
        self.app = App(
            Path(tempfile.mkdtemp(prefix="vouchhunter-tests-")) / "test.sqlite3"
        )
        self.owner = self.register("owner@example.test", company="Pizzeria Ett")
        self.other = self.register("other@example.test", company="Pizzeria Två")
        self.customer = self.register("customer@example.test")
        self.admin = self.register("admin@example.test")
        admin_id = self.call("/api/me", token=self.admin)[1]["id"]
        with self.app.store.transaction() as db:
            db.execute("INSERT INTO platform_admins VALUES(?)", (admin_id,))
            for aid, kind in [("asset_glb", "glb"), ("asset_usdz", "usdz")]:
                db.execute(
                    "INSERT INTO assets VALUES(?,?,?,?,?,?,?)",
                    (
                        aid,
                        "Test asset",
                        kind,
                        aid + "." + kind,
                        100,
                        "test-checksum",
                        now(),
                    ),
                )
            db.execute(
                "INSERT INTO models VALUES(?,?,?,?,?)",
                ("test_model", "Test model", "asset_glb", "asset_usdz", now()),
            )
        self.org = self.call("/api/me", token=self.owner)[1]["organizations"][0]["id"]
        self.campaign = self.make_campaign()

    def call(self, path, body=None, token="", headers=None):
        raw = json.dumps(body).encode() if body is not None else b""
        environ = {
            "PATH_INFO": path,
            "REQUEST_METHOD": "POST" if body is not None else "GET",
            "CONTENT_LENGTH": str(len(raw)),
            "CONTENT_TYPE": "application/json",
            "wsgi.input": io.BytesIO(raw),
            "HTTP_HOST": "localhost:8080",
            "REMOTE_ADDR": "127.0.0.1",
            "HTTP_AUTHORIZATION": "Bearer " + token,
        }
        environ.update(headers or {})
        result = []
        response = b"".join(
            self.app(environ, lambda status, headers: result.append(status))
        )
        return int(result[0].split()[0]), json.loads(response)

    def register(self, email, company=""):
        status, result = self.call(
            "/api/register",
            {
                "email": email,
                "password": "test-password-long",
                "name": "Test User",
                "company": company,
                "native": True,
            },
        )
        self.assertEqual(status, 200, result)
        return result["token"]

    def make_campaign(self, capacity=2, target=1):
        body = {
            "org_id": self.org,
            "title": "En riktig jakt",
            "description": "Hitta en pizza utomhus.",
            "reward": "En gratis pizza",
            "terms": "En pizza per person under perioden.",
            "venue": "Pizzeria Ett, Stockholm",
            "starts": now() - 30,
            "ends": now() + 3600,
            "target": target,
            "capacity": capacity,
            "voucher_days": 14,
            "stops": [
                {"name": "Sergels torg", "lat": 59.3326, "lon": 18.0649, "radius": 40}
            ],
        }
        status, c = self.call("/api/admin/campaigns", body, self.admin)
        self.assertEqual(status, 200, c)
        status, c = self.call(
            "/api/admin/campaigns/" + c["id"] + "/model",
            {"model_id": "test_model"},
            self.admin,
        )
        self.assertEqual(status, 200, c)
        return c

    def test_customer_can_brand_only_own_unlocked_campaign(self):
        path = "/api/manage/campaigns/" + self.campaign["id"] + "/branding"
        brand = {
            "accent_color": "#ff113a",
            "background_color": "#fff7ef",
            "logo_url": "https://example.com/logo.png",
            "hero_url": "",
        }
        self.assertEqual(self.call(path, brand, self.other)[0], 403)
        self.assertEqual(self.call(path, brand, self.customer)[0], 403)
        status, changed = self.call(path, brand, self.owner)
        self.assertEqual(status, 200, changed)
        self.assertEqual(changed["branding"]["accent_color"], "#FF113A")
        self.assertEqual(changed["reward"], self.campaign["reward"])
        self.assertEqual(changed["stops"], self.campaign["stops"])
        for bad in [
            "javascript:alert(1)",
            "http://example.com/logo.png",
            "https://127.0.0.1/a",
            "https://user:secret@example.com/a",
            "https://example.local/a",
        ]:
            self.assertEqual(
                self.call(path, dict(brand, hero_url=bad), self.owner)[0], 400
            )
        self.assertEqual(self.call(path, dict(brand, paid=True), self.owner)[0], 400)
        self.assertEqual(
            self.call(path, dict(brand, accent_color="red;display:none"), self.owner)[
                0
            ],
            400,
        )
        with self.app.store.transaction() as db:
            db.execute("UPDATE campaigns SET paid=1 WHERE id=?", (self.campaign["id"],))
        self.assertEqual(self.call(path, brand, self.owner)[0], 409)

    def test_admin_edits_draft_preserving_locations_and_model(self):
        c = self.campaign
        body = dict(c, title="Ny kampanjtitel", capacity=20)
        path = "/api/admin/campaigns/" + c["id"] + "/edit"
        self.assertEqual(self.call(path, body, self.owner)[0], 403)
        status, updated = self.call(path, body, self.admin)
        self.assertEqual(status, 200, updated)
        self.assertEqual(updated["title"], "Ny kampanjtitel")
        self.assertEqual(updated["capacity"], 20)
        self.assertEqual(updated["stops"], c["stops"])
        self.assertEqual(updated["model_id"], c["model_id"])
        self.assertEqual(self.call(path, dict(body, target=2), self.admin)[0], 400)
        self.assertEqual(
            self.call(path, dict(body, ends=body["starts"]), self.admin)[0], 400
        )
        with self.app.store.transaction() as db:
            self.assertEqual(
                db.execute(
                    "SELECT count(*) FROM audit WHERE action='campaign.updated' AND entity=?",
                    (c["id"],),
                ).fetchone()[0],
                1,
            )

    def test_checkout_locks_campaign_even_before_payment_completes(self):
        c = self.campaign
        with self.app.store.transaction() as db:
            db.execute(
                "INSERT INTO payment_orders VALUES(?,?,?,?,?,?,?)",
                (
                    "pending-test",
                    c["id"],
                    10000,
                    "sek",
                    "https://checkout.stripe.com/test",
                    now() - 60,
                    0,
                ),
            )
        status, result = self.call(
            "/api/admin/campaigns/" + c["id"] + "/edit",
            dict(c, title="Changed title"),
            self.admin,
        )
        self.assertEqual(status, 409, result)
        listing = self.call("/api/admin/campaigns", token=self.admin)[1]
        self.assertTrue(listing["campaigns"][0]["editing_locked"])
        self.assertEqual(
            self.call(
                "/api/admin/campaigns/" + c["id"] + "/model",
                {"model_id": "test_model"},
                self.admin,
            )[0],
            409,
        )

    def test_paid_campaign_cannot_be_edited(self):
        self.publish_for_test()
        c = self.campaign
        self.assertEqual(
            self.call("/api/admin/campaigns/" + c["id"] + "/edit", c, self.admin)[0],
            409,
        )

    def test_payment_status_is_scoped_and_uses_confirmed_server_state(self):
        cid = self.campaign["id"]

        def state():
            return self.call("/api/manage/campaigns", token=self.owner)[1]["campaigns"][
                0
            ]["payment_state"]

        self.assertEqual(state(), "ready")
        with self.app.store.transaction() as db:
            db.execute(
                "INSERT INTO payment_orders VALUES(?,?,?,?,?,?,?)",
                (
                    "status-test",
                    cid,
                    10000,
                    "sek",
                    "https://checkout.stripe.com/test",
                    now() + 3600,
                    0,
                ),
            )
        self.assertEqual(state(), "pending")
        self.assertEqual(
            self.call("/api/manage/campaigns", token=self.other)[1]["campaigns"], []
        )
        with self.app.store.transaction() as db:
            db.execute(
                "UPDATE payment_orders SET expires=? WHERE campaign_id=?",
                (now() - 60, cid),
            )
        self.assertEqual(state(), "expired")
        self.publish_for_test()
        self.assertEqual(state(), "paid")

    def test_expired_campaign_cannot_start_checkout(self):
        cid = self.campaign["id"]
        with self.app.store.transaction() as db:
            db.execute("UPDATE campaigns SET ends=? WHERE id=?", (now() - 60, cid))
        with patch("backend.app.urlopen") as gateway:
            status, result = self.call(
                "/api/manage/campaigns/" + cid + "/checkout", {}, self.owner
            )
        self.assertEqual(status, 409, result)
        gateway.assert_not_called()

    def publish_for_test(self, c=None):
        c = c or self.campaign
        # Test fixture only: no production endpoint bypasses a payment.
        with self.app.store.transaction() as db:
            db.execute("UPDATE campaigns SET paid=1 WHERE id=?", (c["id"],))
        status, result = self.call(
            "/api/admin/campaigns/" + c["id"] + "/publish", {}, self.admin
        )
        self.assertEqual(status, 200, result)

    def collect(self, token=None, c=None, **override):
        c = c or self.campaign
        body = {
            "stop_id": c["stops"][0]["id"],
            "lat": 59.3326,
            "lon": 18.0649,
            "accuracy": 8,
            "captured_at": now(),
        }
        body.update(override)
        return self.call(
            "/api/hunts/" + c["id"] + "/collect", body, token or self.customer
        )

    def start(self, token=None, c=None):
        return self.call(
            "/api/hunts/" + (c or self.campaign)["id"] + "/start",
            {},
            token or self.customer,
        )

    def test_unpaid_cannot_publish(self):
        status, _ = self.call(
            "/api/admin/campaigns/" + self.campaign["id"] + "/publish", {}, self.admin
        )
        self.assertEqual(status, 409)
        self.assertEqual(self.call("/api/campaigns")[1]["campaigns"], [])

    def test_cross_company_cannot_publish_or_list(self):
        status, _ = self.call(
            "/api/manage/campaigns/" + self.campaign["id"] + "/publish", {}, self.other
        )
        self.assertEqual(status, 403)
        self.assertEqual(
            self.call("/api/manage/campaigns", token=self.other)[1]["campaigns"], []
        )

    def test_far_away_stale_and_inaccurate_locations_fail(self):
        self.publish_for_test()
        self.start()
        for changes in [
            {"lat": 59.4},
            {"captured_at": now() - 120},
            {"accuracy": 60},
            {"lat": float("nan")},
            {"lon": float("inf")},
        ]:
            with self.subTest(changes=changes):
                self.assertIn(self.collect(**changes)[0], (400, 409))

    def test_duplicate_collection_issues_one_voucher(self):
        self.publish_for_test()
        self.start()
        first = self.collect()
        second = self.collect()
        self.assertEqual(first[0], 200)
        self.assertEqual(first[1]["voucher"]["id"], second[1]["voucher"]["id"])
        with self.app.store.transaction() as db:
            self.assertEqual(
                db.execute("SELECT count(*) FROM vouchers").fetchone()[0], 1
            )

    def test_voucher_information_survives_issue_restore_and_redemption(self):
        cid = self.campaign["id"]
        branding = {"accent_color": "#FF113A", "logo_url": "https://example.com/logo.png"}
        status, branded = self.call("/api/manage/campaigns/" + cid + "/branding", branding, self.owner)
        self.assertEqual(status, 200, branded)
        self.publish_for_test()
        self.start()
        status, issued = self.collect()
        self.assertEqual(status, 200, issued)
        voucher = issued["voucher"]
        for key in ("title", "reward", "venue", "terms"):
            self.assertEqual(voucher[key], self.campaign[key])
        self.assertEqual(voucher["campaign_id"], cid)
        self.assertEqual(voucher["brand"], "Pizzeria Ett")
        self.assertEqual(voucher["branding"], branded["branding"])
        restored = self.call("/api/hunts/" + cid, token=self.customer)[1]["hunt"]
        self.assertEqual(restored["voucher"], voucher)
        self.assertEqual(self.call("/api/vouchers", token=self.customer)[1]["vouchers"], [voucher])
        self.assertEqual(self.call("/api/vouchers", token=self.other)[1]["vouchers"], [])
        self.assertEqual(self.call("/api/vouchers")[0], 401)
        self.assertEqual(self.call("/api/vouchers/redeem", {"code": voucher["code"]}, self.owner)[0], 200)
        redeemed = self.call("/api/vouchers", token=self.customer)[1]["vouchers"][0]
        self.assertIsNotNone(redeemed["redeemed"])
        self.assertEqual(redeemed["branding"], voucher["branding"])
        self.assertEqual(redeemed["terms"], voucher["terms"])

    def test_redeem_once_and_cross_company_denied(self):
        self.publish_for_test()
        self.start()
        code = self.collect()[1]["voucher"]["code"]
        self.assertEqual(
            self.call("/api/vouchers/check", {"code": code}, self.other)[0], 403
        )
        self.assertEqual(
            self.call("/api/vouchers/check", {"code": code}, self.owner)[0], 200
        )

        def redeem():
            return self.call("/api/vouchers/redeem", {"code": code}, self.owner)[0]

        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: redeem(), range(2)))
        self.assertEqual(sorted(results), [200, 409])

    def test_capacity_under_simultaneous_starts(self):
        c = self.make_campaign(capacity=1)
        self.publish_for_test(c)
        customer2 = self.register("another@example.test")
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results = list(
                pool.map(lambda t: self.start(t, c)[0], [self.customer, customer2])
            )
        self.assertEqual(sorted(results), [200, 409])

    def test_expired_reservation_cannot_collect_and_can_restart(self):
        self.publish_for_test()
        h = self.start()[1]
        with self.app.store.transaction() as db:
            db.execute("UPDATE hunts SET expires=? WHERE id=?", (now() - 1, h["id"]))
        self.assertEqual(self.collect()[0], 409)
        self.assertEqual(self.start()[0], 200)
        self.assertEqual(self.collect()[0], 200)

    def test_paused_campaign_preserves_issued_voucher(self):
        self.publish_for_test()
        self.start()
        code = self.collect()[1]["voucher"]["code"]
        self.call(
            "/api/admin/campaigns/" + self.campaign["id"] + "/pause", {}, self.admin
        )
        self.assertEqual(
            self.call("/api/vouchers/redeem", {"code": code}, self.owner)[0], 200
        )

    def test_logout_revokes_token(self):
        self.assertEqual(self.call("/api/logout", {}, self.customer)[0], 200)
        self.assertEqual(self.call("/api/me", token=self.customer)[0], 401)

    def test_customer_cannot_administer_own_campaign(self):
        self.assertEqual(
            self.call(
                "/api/admin/campaigns/" + self.campaign["id"] + "/pause", {}, self.owner
            )[0],
            403,
        )
        self.assertEqual(self.call("/api/admin/assets", token=self.owner)[0], 403)
        self.assertEqual(
            self.call("/api/admin/organizations", token=self.owner)[0], 403
        )

    def test_customer_brief_is_isolated(self):
        status, _ = self.call(
            "/api/manage/briefs",
            {
                "org_id": self.org,
                "title": "Ny lansering",
                "description": "Marknadsför vår nya pizza.",
                "reward": "En pizza",
                "area": "Stockholm",
                "preferred_start": "Oktober 2026",
            },
            self.owner,
        )
        self.assertEqual(status, 200)
        self.assertEqual(
            len(self.call("/api/manage/briefs", token=self.other)[1]["briefs"]), 0
        )
        self.assertEqual(
            len(self.call("/api/admin/briefs", token=self.admin)[1]["briefs"]), 1
        )

    def test_csrf_origin_rejected(self):
        status, _ = self.call(
            "/api/logout", {}, self.customer, {"HTTP_ORIGIN": "https://evil.example"}
        )
        self.assertEqual(status, 403)

    def test_signed_payment_webhook_is_idempotent(self):
        with self.app.store.transaction() as db:
            db.execute(
                "INSERT INTO payment_orders VALUES(?,?,?,?,?,?,0)",
                (
                    "cs_test",
                    self.campaign["id"],
                    10000,
                    "sek",
                    "https://checkout.stripe.com/test",
                    now() + 3600,
                ),
            )
        event = {
            "id": "evt_123",
            "type": "checkout.session.completed",
            "data": {
                "object": {
                    "id": "cs_test",
                    "mode": "payment",
                    "amount_total": 10000,
                    "currency": "sek",
                    "payment_status": "paid",
                    "metadata": {"campaign_id": self.campaign["id"]},
                }
            },
        }
        stamp = str(now())
        raw = json.dumps(event).encode()
        signature = hmac.new(
            b"test-secret", stamp.encode() + b"." + raw, hashlib.sha256
        ).hexdigest()
        with patch.dict(os.environ, {"STRIPE_WEBHOOK_SECRET": "test-secret"}):
            self.assertEqual(
                self.call(
                    "/api/payments/webhook",
                    event,
                    headers={"HTTP_STRIPE_SIGNATURE": f"t={stamp},v1=wrong"},
                )[0],
                400,
            )
            for _ in range(2):
                self.assertEqual(
                    self.call(
                        "/api/payments/webhook",
                        event,
                        headers={"HTTP_STRIPE_SIGNATURE": f"t={stamp},v1={signature}"},
                    )[0],
                    200,
                )
        with self.app.store.transaction() as db:
            self.assertEqual(
                db.execute("SELECT count(*) FROM webhook_events").fetchone()[0], 1
            )
            self.assertEqual(
                db.execute(
                    "SELECT paid FROM campaigns WHERE id=?", (self.campaign["id"],)
                ).fetchone()[0],
                1,
            )

    def test_path_traversal_cannot_serve_source(self):
        output = []
        body = b"".join(
            self.app(
                {"PATH_INFO": "/../backend/app.py", "REQUEST_METHOD": "GET"},
                lambda status, headers: output.append(status),
            )
        )
        self.assertTrue(output[0].startswith("404"))


if __name__ == "__main__":
    unittest.main()
