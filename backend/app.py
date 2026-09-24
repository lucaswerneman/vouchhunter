"""VoucherHunt WSGI API. Run locally with python3 -m backend.app.
Production deployment requires TLS and a production WSGI host; see docs/OPERATIONS.md.
"""

import base64, hashlib, hmac, json, math, os, re, secrets, sqlite3, time
from contextlib import contextmanager
from http.cookies import SimpleCookie
from pathlib import Path
from urllib.parse import parse_qs, urlencode
from urllib.request import Request, urlopen
from backend.assets import validate_model
from backend.branding import validate_branding

ROOT = Path(__file__).resolve().parents[1]


class Problem(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message


def require(condition, message, status=400):
    if not condition:
        raise Problem(status, message)


def now():
    return int(time.time())


def uid():
    return secrets.token_hex(12)


def hash_token(token):
    return hashlib.sha256(token.encode()).hexdigest()


def password_hash(password, salt=None):
    salt = salt or secrets.token_hex(16)
    return (
        salt
        + ":"
        + hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 600000).hex()
    )


def text_field(data, key, minimum=1, maximum=200):
    value = data.get(key)
    require(
        isinstance(value, str) and minimum <= len(value.strip()) <= maximum,
        f"Kontrollera fältet {key}.",
    )
    return value.strip()


def number(value, low, high):
    require(
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(value)
        and low <= value <= high,
        "Ogiltigt numeriskt värde.",
    )
    return value


def integer(value, low, high):
    number(value, low, high)
    require(int(value) == value, "Ange ett heltal.")
    return int(value)


def distance(a, b, c, d):
    p1, p2 = math.radians(a), math.radians(c)
    v = (
        math.sin((p2 - p1) / 2) ** 2
        + math.cos(p1) * math.cos(p2) * math.sin(math.radians(d - b) / 2) ** 2
    )
    return 6371000 * 2 * math.asin(math.sqrt(min(1, max(0, v))))


class Store:
    def __init__(self, path):
        self.path = str(path)
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        with self.connect() as db:
            db.executescript((ROOT / "backend/schema.sql").read_text())
        with self.transaction() as db:
            version = db.execute("PRAGMA user_version").fetchone()[0]
            for migration in sorted((ROOT / "backend/migrations").glob("*.sql")):
                number = int(migration.name.split("_")[0])
                if number > version:
                    require(
                        number == version + 1,
                        "Databasens migreringsordning är fel.",
                        500,
                    )
                    for statement in migration.read_text().split(";"):
                        if statement.strip():
                            db.execute(statement)
                    db.execute(f"PRAGMA user_version={number}")
                    version = number

    def connect(self):
        db = sqlite3.connect(self.path, timeout=15)
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA foreign_keys=ON")
        db.execute("PRAGMA journal_mode=WAL")
        return db

    @contextmanager
    def transaction(self):
        db = self.connect()
        try:
            db.execute("BEGIN IMMEDIATE")
            yield db
            db.commit()
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()

    def audit(self, db, actor, action, entity):
        db.execute(
            "INSERT INTO audit(actor,action,entity,created) VALUES(?,?,?,?)",
            (actor, action, entity, now()),
        )

    def user(self, db, token):
        row = db.execute(
            "SELECT u.id,u.name,u.email FROM users u JOIN sessions s ON s.user_id=u.id WHERE s.token=? AND s.expires>? AND s.revoked=0",
            (hash_token(token), now()),
        ).fetchone()
        require(row, "Logga in för att fortsätta.", 401)
        return dict(row)

    def member(self, db, user, org, owner=False):
        row = db.execute(
            "SELECT role FROM memberships WHERE user_id=? AND org_id=?", (user, org)
        ).fetchone()
        require(
            row and (not owner or row["role"] == "owner"), "Du saknar behörighet.", 403
        )

    def admin(self, db, user):
        require(
            db.execute(
                "SELECT 1 FROM platform_admins WHERE user_id=?", (user,)
            ).fetchone(),
            "Endast plattformens administratör har åtkomst.",
            403,
        )

    def campaign(self, db, cid):
        c = db.execute(
            "SELECT c.*,o.name AS brand FROM campaigns c JOIN organizations o ON o.id=c.org_id WHERE c.id=?",
            (cid,),
        ).fetchone()
        require(c, "Kampanjen hittades inte.", 404)
        result = dict(c)
        result["branding"] = json.loads(result.pop("branding_json", "{}"))
        result["stops"] = [
            dict(s)
            for s in db.execute(
                "SELECT * FROM stops WHERE campaign_id=? ORDER BY rowid", (cid,)
            )
        ]
        model = db.execute(
            "SELECT * FROM models WHERE id=?", (result["model_id"],)
        ).fetchone()
        result["model"] = dict(model) if model else None
        return result

    def vouchers(self, db, user, hunt_id=None):
        # Same contract for initial issuance, restored hunts and the wallet.
        query = (
            "SELECT v.*,c.id AS campaign_id,c.title,c.reward,c.venue,c.terms,"
            "c.branding_json,o.name AS brand FROM vouchers v "
            "JOIN hunts h ON h.id=v.hunt_id JOIN campaigns c ON c.id=h.campaign_id "
            "JOIN organizations o ON o.id=c.org_id WHERE h.user_id=?"
        )
        params = [user]
        if hunt_id is not None:
            query += " AND h.id=?"
            params.append(hunt_id)
        result = []
        for row in db.execute(query + " ORDER BY v.expires DESC,v.id", params):
            voucher = dict(row)
            voucher["branding"] = json.loads(voucher.pop("branding_json", "{}"))
            result.append(voucher)
        return result

    def hunt(self, db, user, cid):
        h = db.execute(
            "SELECT * FROM hunts WHERE user_id=? AND campaign_id=?", (user, cid)
        ).fetchone()
        if not h:
            return None
        result = dict(h)
        result["collected"] = [
            r[0]
            for r in db.execute(
                "SELECT stop_id FROM collections WHERE hunt_id=?", (h["id"],)
            )
        ]
        vouchers = self.vouchers(db, user, h["id"])
        result["voucher"] = vouchers[0] if vouchers else None
        return result

    def start(self, db, user, cid):
        c = self.campaign(db, cid)
        existing = self.hunt(db, user, cid)
        if existing and (existing["completed"] or existing["expires"] > now()):
            return existing
        require(
            c["status"] == "active" and c["starts"] <= now() < c["ends"],
            "Kampanjen är inte öppen.",
            409,
        )
        taken = db.execute(
            "SELECT count(*) FROM hunts WHERE campaign_id=? AND (completed IS NOT NULL OR expires>?)",
            (cid, now()),
        ).fetchone()[0]
        require(taken < c["capacity"], "Alla belöningar är reserverade just nu.", 409)
        expires = min(now() + 3600, c["ends"])
        if existing:
            db.execute(
                "UPDATE hunts SET expires=? WHERE id=?", (expires, existing["id"])
            )
        else:
            db.execute(
                "INSERT INTO hunts(id,user_id,campaign_id,expires) VALUES(?,?,?,?)",
                (uid(), user, cid, expires),
            )
        self.audit(db, user, "hunt.started", cid)
        return self.hunt(db, user, cid)

    def collect(self, db, user, cid, data):
        h = self.hunt(db, user, cid)
        require(h, "Starta jakten först.", 409)
        c = self.campaign(db, cid)
        stop = next((s for s in c["stops"] if s["id"] == data.get("stop_id")), None)
        require(stop, "Platsen hittades inte.", 404)
        if stop["id"] in h["collected"]:
            return h
        require(
            not h["completed"] and h["expires"] > now(),
            "Reservationen har gått ut. Starta jakten igen.",
            409,
        )
        require(
            c["status"] == "active" and c["starts"] <= now() < c["ends"],
            "Insamlingen är pausad eller avslutad.",
            409,
        )
        lat = number(data.get("lat"), -90, 90)
        lon = number(data.get("lon"), -180, 180)
        accuracy = number(data.get("accuracy"), 0, 35)
        captured = number(data.get("captured_at"), now() - 45, now() + 10)
        require(
            distance(lat, lon, stop["lat"], stop["lon"]) <= stop["radius"],
            "Gå närmare platsen för att samla objektet.",
            409,
        )
        db.execute(
            "INSERT INTO collections VALUES(?,?,?)", (h["id"], stop["id"], now())
        )
        count = db.execute(
            "SELECT count(*) FROM collections WHERE hunt_id=?", (h["id"],)
        ).fetchone()[0]
        if count >= c["target"]:
            db.execute("UPDATE hunts SET completed=? WHERE id=?", (now(), h["id"]))
            db.execute(
                "INSERT INTO vouchers(id,hunt_id,code,expires) VALUES(?,?,?,?)",
                (
                    uid(),
                    h["id"],
                    secrets.token_urlsafe(24),
                    now() + c["voucher_days"] * 86400,
                ),
            )
            self.audit(db, user, "voucher.issued", h["id"])
        return self.hunt(db, user, cid)

    def redeem(self, db, user, code, commit):
        row = db.execute(
            "SELECT v.*,c.org_id,c.title,c.reward,c.venue FROM vouchers v JOIN hunts h ON h.id=v.hunt_id JOIN campaigns c ON c.id=h.campaign_id WHERE v.code=?",
            (code,),
        ).fetchone()
        require(row, "Vouchern hittades inte.", 404)
        self.member(db, user, row["org_id"])
        require(not row["redeemed"], "Vouchern är redan använd.", 409)
        require(row["expires"] > now(), "Vouchern har gått ut.", 409)
        if commit:
            db.execute(
                "UPDATE vouchers SET redeemed=?,redeemed_by=? WHERE id=? AND redeemed IS NULL",
                (now(), user, row["id"]),
            )
            self.audit(db, user, "voucher.redeemed", row["id"])
        return {
            "id": row["id"],
            "title": row["title"],
            "reward": row["reward"],
            "venue": row["venue"],
            "redeemed": commit,
        }


class App:
    def __init__(self, path=None):
        self.store = Store(
            path or os.environ.get("DATABASE_PATH", ROOT / "data/vouchhunter.sqlite3")
        )
        self.attempts = {}

    def __call__(self, e, start):
        headers = [
            ("Content-Type", "application/json; charset=utf-8"),
            ("Cache-Control", "no-store"),
            ("X-Content-Type-Options", "nosniff"),
            ("Referrer-Policy", "same-origin"),
        ]
        try:
            path = e.get("PATH_INFO", "/")
            method = e["REQUEST_METHOD"]
            if re.fullmatch("/api/assets/[a-f0-9]{24}", path) and method == "GET":
                return self.asset_response(path.rsplit("/", 1)[1], e, start)
            if not path.startswith("/api/"):
                return self.static(path, start)
            require(method in ("GET", "POST"), "Metoden stöds inte.", 405)
            if method == "POST" and path != "/api/payments/webhook":
                origin = e.get("HTTP_ORIGIN")
                expected = os.environ.get(
                    "PUBLIC_URL", f"http://{e.get('HTTP_HOST','localhost:8787')}"
                ).rstrip("/")
                require(not origin or origin == expected, "Otillåtet ursprung.", 403)
                require(
                    e.get("CONTENT_TYPE", "").split(";")[0] == "application/json",
                    "JSON krävs.",
                    415,
                )
            length = int(e.get("CONTENT_LENGTH") or 0)
            require(
                0
                <= length
                <= (17 * 1024 * 1024 if path == "/api/admin/assets" else 100000),
                "För stor förfrågan.",
                413,
            )
            raw = e["wsgi.input"].read(length)
            try:
                data = json.loads(raw) if raw else {}
            except ValueError:
                raise Problem(400, "Ogiltig JSON.")
            require(isinstance(data, dict), "JSON-objekt krävs.")
            result, cookie = self.route(path, method, data, e, raw)
            if cookie:
                headers.append(("Set-Cookie", cookie))
            body = json.dumps(result, ensure_ascii=False, allow_nan=False).encode()
            start("200 OK", headers)
            return [body]
        except Problem as ex:
            start(f"{ex.status} Error", headers)
            return [json.dumps({"error": ex.message}).encode()]
        except (ValueError, TypeError, KeyError):
            start("400 Bad Request", headers)
            return [b'{"error":"Ogiltig begaran."}']
        except Exception:
            import traceback

            traceback.print_exc()
            start("500 Internal Server Error", headers)
            return [b'{"error":"Ett serverfel uppstod. Forsok igen."}']

    def static(self, path, start):
        file = (ROOT / "web" / path.lstrip("/")).resolve()
        if path == "/" or not Path(path).suffix:
            file = ROOT / "web/index.html"
        if not file.is_relative_to(ROOT / "web") or not file.is_file():
            start("404 Not Found", [("Content-Type", "text/plain")])
            return [b"Not found"]
        mime = {
            ".html": "text/html; charset=utf-8",
            ".css": "text/css",
            ".js": "text/javascript",
            ".svg": "image/svg+xml",
        }.get(file.suffix, "application/octet-stream")
        start(
            "200 OK",
            [
                ("Content-Type", mime),
                ("X-Content-Type-Options", "nosniff"),
                (
                    "Content-Security-Policy",
                    "default-src 'self'; style-src 'self'; script-src 'self'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'",
                ),
                ("Cache-Control", "no-cache"),
            ],
        )
        return [file.read_bytes()]

    def asset_response(self, asset_id, e, start):
        with self.store.transaction() as db:
            asset = db.execute(
                "SELECT * FROM assets WHERE id=?", (asset_id,)
            ).fetchone()
            require(asset, "Filen hittades inte.", 404)
            public = db.execute(
                "SELECT 1 FROM campaigns c JOIN models m ON m.id=c.model_id WHERE (m.glb_asset_id=? OR m.usdz_asset_id=?) AND c.status='active' AND c.starts<=? AND c.ends>?",
                (asset_id, asset_id, now(), now()),
            ).fetchone()
            if not public:
                token = e.get("HTTP_AUTHORIZATION", "").removeprefix("Bearer ")
                if not token:
                    cookie = SimpleCookie()
                    cookie.load(e.get("HTTP_COOKIE", ""))
                    token = cookie["vh_session"].value if "vh_session" in cookie else ""
                self.store.admin(db, self.store.user(db, token)["id"])
            content = (
                Path(os.environ.get("ASSET_PATH", ROOT / "data/assets"))
                / asset["filename"]
            ).read_bytes()
        start(
            "200 OK",
            [
                (
                    "Content-Type",
                    (
                        "model/gltf-binary"
                        if asset["format"] == "glb"
                        else "model/vnd.usdz+zip"
                    ),
                ),
                ("Content-Length", str(len(content))),
                ("X-Content-Type-Options", "nosniff"),
                ("Cache-Control", "private, max-age=3600"),
            ],
        )
        return [content]

    def route(self, path, method, data, e, raw):
        if path == "/api/health":
            return {"status": "ok"}, None
        if path == "/api/payments/webhook":
            return self.webhook(e, raw, data), None
        token = e.get("HTTP_AUTHORIZATION", "").removeprefix("Bearer ")
        if not token:
            cookie = SimpleCookie()
            cookie.load(e.get("HTTP_COOKIE", ""))
            token = cookie["vh_session"].value if "vh_session" in cookie else ""
        with self.store.transaction() as db:
            if path in ("/api/register", "/api/login") and method == "POST":
                key = e.get("REMOTE_ADDR", "unknown")
                stamp = now()
                # In-process backstop; production reverse proxy must also rate limit.
                self.attempts = {
                    k: v for k, v in self.attempts.items() if v[0] > stamp - 900
                }
                prev = self.attempts.get(key, (stamp, 0))
                require(prev[1] < 30, "För många försök. Försök senare.", 429)
                self.attempts[key] = (prev[0], prev[1] + 1)
                email = text_field(data, "email", 3, 254).lower()
                pw = data.get("password")
                require(
                    isinstance(pw, str) and 10 <= len(pw) <= 256,
                    "Lösenordet måste innehålla 10–256 tecken.",
                )
                require(
                    re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", email),
                    "Ange en giltig e-postadress.",
                )
                row = db.execute(
                    "SELECT * FROM users WHERE email=?", (email,)
                ).fetchone()
                if path == "/api/register":
                    require(
                        not row, "Kontot kunde inte skapas med dessa uppgifter.", 409
                    )
                    user = uid()
                    db.execute(
                        "INSERT INTO users VALUES(?,?,?,?,?)",
                        (
                            user,
                            email,
                            password_hash(pw),
                            text_field(data, "name", 1, 100),
                            now(),
                        ),
                    )
                    company = data.get("company", "").strip()
                    if company:
                        require(len(company) <= 100, "Företagsnamnet är för långt.")
                        org = uid()
                        db.execute(
                            "INSERT INTO organizations VALUES(?,?,?)",
                            (org, company, now()),
                        )
                        db.execute(
                            "INSERT INTO memberships VALUES(?,?,?)",
                            (user, org, "owner"),
                        )
                else:
                    calculated = password_hash(
                        pw,
                        row["password"].split(":")[0] if row else "invalid-user-salt",
                    )
                    require(
                        row and hmac.compare_digest(calculated, row["password"]),
                        "Fel e-postadress eller lösenord.",
                        401,
                    )
                    user = row["id"]
                token = secrets.token_urlsafe(32)
                db.execute(
                    "INSERT INTO sessions(token,user_id,expires) VALUES(?,?,?)",
                    (hash_token(token), user, now() + 604800),
                )
                secure = (
                    "; Secure"
                    if os.environ.get("PUBLIC_URL", "").startswith("https:")
                    else ""
                )
                # Native clients request token explicitly; browser uses an HttpOnly cookie.
                result = {"ok": True}
                if data.get("native") is True:
                    result["token"] = token
                return (
                    result,
                    f"vh_session={token}; HttpOnly; SameSite=Lax; Path=/; Max-Age=604800{secure}",
                )
            if path == "/api/campaigns" and method == "GET":
                ids = db.execute(
                    "SELECT id FROM campaigns WHERE status='active' AND starts<=? AND ends>? ORDER BY created DESC",
                    (now(), now()),
                ).fetchall()
                return {"campaigns": [self.store.campaign(db, r[0]) for r in ids]}, None
            match = re.fullmatch("/api/campaigns/([a-f0-9]+)/?", path)
            if match and method == "GET":
                c = self.store.campaign(db, match[1])
                require(c["status"] == "active", "Kampanjen är inte publicerad.", 404)
                return c, None
            user = self.store.user(db, token)
            who = user["id"]
            if path == "/api/me":
                user["organizations"] = [
                    dict(r)
                    for r in db.execute(
                        "SELECT o.*,m.role FROM organizations o JOIN memberships m ON m.org_id=o.id WHERE m.user_id=?",
                        (who,),
                    )
                ]
                user["is_admin"] = bool(
                    db.execute(
                        "SELECT 1 FROM platform_admins WHERE user_id=?", (who,)
                    ).fetchone()
                )
                return user, None
            if path == "/api/logout" and method == "POST":
                db.execute(
                    "UPDATE sessions SET revoked=1 WHERE token=?", (hash_token(token),)
                )
                return {
                    "ok": True
                }, "vh_session=; Max-Age=0; HttpOnly; SameSite=Lax; Path=/"
            if (
                path in ("/api/manage/campaigns", "/api/admin/campaigns")
                and method == "GET"
            ):
                if path.startswith("/api/admin/"):
                    self.store.admin(db, who)
                    ids = db.execute(
                        "SELECT id FROM campaigns ORDER BY created DESC"
                    ).fetchall()
                else:
                    ids = db.execute(
                        "SELECT c.id FROM campaigns c JOIN memberships m ON m.org_id=c.org_id WHERE m.user_id=? ORDER BY c.created DESC",
                        (who,),
                    ).fetchall()
                campaigns = []
                for r in ids:
                    c = self.store.campaign(db, r[0])
                    c["started"] = db.execute(
                        "SELECT count(*) FROM hunts WHERE campaign_id=?", (r[0],)
                    ).fetchone()[0]
                    c["completed"] = db.execute(
                        "SELECT count(*) FROM hunts WHERE campaign_id=? AND completed IS NOT NULL",
                        (r[0],),
                    ).fetchone()[0]
                    c["redeemed"] = db.execute(
                        "SELECT count(*) FROM vouchers v JOIN hunts h ON h.id=v.hunt_id WHERE h.campaign_id=? AND v.redeemed IS NOT NULL",
                        (r[0],),
                    ).fetchone()[0]
                    c["editing_locked"] = bool(
                        c["paid"]
                        or c["status"] != "draft"
                        or db.execute(
                            "SELECT 1 FROM payment_orders WHERE campaign_id=?",
                            (c["id"],),
                        ).fetchone()
                    )
                    order = db.execute(
                        "SELECT paid,expires FROM payment_orders WHERE campaign_id=? ORDER BY paid DESC,expires DESC LIMIT 1",
                        (c["id"],),
                    ).fetchone()
                    c["payment_state"] = (
                        "paid"
                        if c["paid"]
                        else (
                            "pending"
                            if order and order["expires"] > now()
                            else (
                                "expired"
                                if order
                                else "ready" if c["model_id"] else "preparing"
                            )
                        )
                    )
                    campaigns.append(c)
                return {"campaigns": campaigns}, None
            appearance = re.fullmatch(
                "/api/(manage|admin)/campaigns/([a-f0-9]+)/branding", path
            )
            if appearance and method == "POST":
                scope, cid = appearance.groups()
                c = self.store.campaign(db, cid)
                if scope == "admin":
                    self.store.admin(db, who)
                else:
                    self.store.member(db, who, c["org_id"], owner=True)
                require(
                    c["status"] == "draft" and not c["paid"],
                    "Varumärket är låst efter betalning eller publicering.",
                    409,
                )
                require(
                    not db.execute(
                        "SELECT 1 FROM payment_orders WHERE campaign_id=?", (cid,)
                    ).fetchone(),
                    "Varumärket är låst eftersom betalning har påbörjats.",
                    409,
                )
                try:
                    branding = validate_branding(data)
                except ValueError as error:
                    raise Problem(400, str(error))
                db.execute(
                    "UPDATE campaigns SET branding_json=? WHERE id=?",
                    (json.dumps(branding), cid),
                )
                self.store.audit(db, who, "campaign.branded", cid)
                return self.store.campaign(db, cid), None
            edit = re.fullmatch("/api/admin/campaigns/([a-f0-9]+)/edit", path)
            if edit and method == "POST":
                self.store.admin(db, who)
                cid = edit.group(1)
                c = self.store.campaign(db, cid)
                require(
                    c["status"] == "draft" and not c["paid"],
                    "Endast obetalda utkast kan redigeras.",
                    409,
                )
                require(
                    not db.execute(
                        "SELECT 1 FROM payment_orders WHERE campaign_id=?", (cid,)
                    ).fetchone(),
                    "Upplägget är låst eftersom en betalning har påbörjats.",
                    409,
                )
                starts = integer(data.get("starts"), 0, 4102444800)
                ends = integer(data.get("ends"), starts + 60, 4102444800)
                target = integer(data.get("target"), 1, min(50, len(c["stops"])))
                values = (
                    text_field(data, "title", 3, 120),
                    text_field(data, "description", 10, 2000),
                    text_field(data, "reward", 3, 200),
                    text_field(data, "terms", 10, 2000),
                    text_field(data, "venue", 3, 200),
                    starts,
                    ends,
                    integer(data.get("voucher_days"), 1, 365),
                    target,
                    integer(data.get("capacity"), 1, 100000),
                    cid,
                )
                db.execute(
                    "UPDATE campaigns SET title=?,description=?,reward=?,terms=?,venue=?,starts=?,ends=?,voucher_days=?,target=?,capacity=? WHERE id=?",
                    values,
                )
                self.store.audit(db, who, "campaign.updated", cid)
                return self.store.campaign(db, cid), None
            if path == "/api/admin/campaigns" and method == "POST":
                self.store.admin(db, who)
                org = text_field(data, "org_id")
                require(
                    db.execute(
                        "SELECT 1 FROM organizations WHERE id=?", (org,)
                    ).fetchone(),
                    "Företaget hittades inte.",
                    404,
                )
                cid = uid()
                title = text_field(data, "title", 3, 120)
                desc = text_field(data, "description", 10, 2000)
                reward = text_field(data, "reward", 3, 200)
                terms = text_field(data, "terms", 10, 2000)
                venue = text_field(data, "venue", 3, 200)
                starts = integer(data.get("starts"), 0, 4102444800)
                ends = integer(data.get("ends"), starts + 60, 4102444800)
                target = integer(data.get("target"), 1, 50)
                capacity = integer(data.get("capacity"), 1, 100000)
                days = integer(data.get("voucher_days", 14), 1, 365)
                stops = data.get("stops")
                require(
                    isinstance(stops, list) and target <= len(stops) <= 100,
                    "Lägg till minst lika många platser som insamlingsmålet.",
                )
                locations = []
                for s in stops:
                    require(isinstance(s, dict), "Ogiltig plats.")
                    locations.append(
                        (
                            uid(),
                            cid,
                            text_field(s, "name", 2, 100),
                            number(s.get("lat"), -90, 90),
                            number(s.get("lon"), -180, 180),
                            integer(s.get("radius", 40), 10, 100),
                        )
                    )
                require(
                    len({(s[3], s[4]) for s in locations}) == len(locations),
                    "Varje plats behöver en unik position.",
                )
                db.execute(
                    "INSERT INTO campaigns(id,org_id,title,description,reward,terms,venue,starts,ends,voucher_days,target,capacity,created) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",
                    (
                        cid,
                        org,
                        title,
                        desc,
                        reward,
                        terms,
                        venue,
                        starts,
                        ends,
                        days,
                        target,
                        capacity,
                        now(),
                    ),
                )
                db.executemany("INSERT INTO stops VALUES(?,?,?,?,?,?)", locations)
                self.store.audit(db, who, "campaign.created", cid)
                return self.store.campaign(db, cid), None
            match = re.fullmatch(
                "/api/(?:manage|admin)/campaigns/([a-f0-9]+)/(publish|pause|checkout|model)",
                path,
            )
            if match and method == "POST":
                cid, action = match.groups()
                c = self.store.campaign(db, cid)
                if action == "checkout":
                    self.store.member(db, who, c["org_id"], True)
                    require(
                        c["model_id"],
                        "Kampanjen förbereds av VoucherHunt. Betalning öppnas när upplägget är klart.",
                        409,
                    )
                    return self.checkout(db, c), None
                self.store.admin(db, who)
                if action == "model":
                    require(
                        c["status"] == "draft" and not c["paid"],
                        "Objektet är låst efter betalning eller publicering.",
                        409,
                    )
                    require(
                        not db.execute(
                            "SELECT 1 FROM payment_orders WHERE campaign_id=?", (cid,)
                        ).fetchone(),
                        "Upplägget är låst eftersom en betalning har påbörjats.",
                        409,
                    )
                    model_id = text_field(data, "model_id")
                    require(
                        db.execute(
                            "SELECT 1 FROM models WHERE id=?", (model_id,)
                        ).fetchone(),
                        "3D-objektet hittades inte.",
                        404,
                    )
                    db.execute(
                        "UPDATE campaigns SET model_id=? WHERE id=?", (model_id, cid)
                    )
                    self.store.audit(db, who, "campaign.model", cid)
                    return self.store.campaign(db, cid), None
                if action == "publish":
                    require(c["paid"], "Betala kampanjen innan publicering.", 409)
                    require(
                        c["model_id"],
                        "Välj ett 3D-objekt med båda mobilformaten först.",
                        409,
                    )
                    require(
                        c["ends"] > now(), "Kampanjens slutdatum har passerat.", 409
                    )
                db.execute(
                    "UPDATE campaigns SET status=? WHERE id=?",
                    ("active" if action == "publish" else "paused", cid),
                )
                self.store.audit(db, who, "campaign." + action, cid)
                return self.store.campaign(db, cid), None
            if path in ("/api/manage/briefs", "/api/admin/briefs"):
                if path.startswith("/api/admin/"):
                    self.store.admin(db, who)
                    if method == "GET":
                        return {
                            "briefs": [
                                dict(r)
                                for r in db.execute(
                                    "SELECT b.*,o.name AS brand FROM briefs b JOIN organizations o ON o.id=b.org_id ORDER BY b.created DESC"
                                )
                            ]
                        }, None
                elif method == "GET":
                    return {
                        "briefs": [
                            dict(r)
                            for r in db.execute(
                                "SELECT b.* FROM briefs b JOIN memberships m ON m.org_id=b.org_id WHERE m.user_id=? ORDER BY b.created DESC",
                                (who,),
                            )
                        ]
                    }, None
                elif method == "POST":
                    org = text_field(data, "org_id")
                    self.store.member(db, who, org, True)
                    bid = uid()
                    db.execute(
                        "INSERT INTO briefs(id,org_id,title,description,reward,area,preferred_start,created) VALUES(?,?,?,?,?,?,?,?)",
                        (
                            bid,
                            org,
                            text_field(data, "title", 3, 120),
                            text_field(data, "description", 10, 2000),
                            text_field(data, "reward", 3, 200),
                            text_field(data, "area", 2, 200),
                            text_field(data, "preferred_start", 4, 100),
                            now(),
                        ),
                    )
                    self.store.audit(db, who, "brief.created", bid)
                    return {"id": bid}, None
            match = re.fullmatch("/api/admin/briefs/([a-f0-9]+)/link", path)
            if match and method == "POST":
                self.store.admin(db, who)
                c = self.store.campaign(db, text_field(data, "campaign_id"))
                brief = db.execute(
                    "SELECT * FROM briefs WHERE id=?", (match[1],)
                ).fetchone()
                require(
                    brief and brief["org_id"] == c["org_id"],
                    "Brief och kampanj måste tillhöra samma företag.",
                    409,
                )
                require(not brief["campaign_id"], "Briefen har redan en kampanj.", 409)
                db.execute(
                    "UPDATE briefs SET campaign_id=? WHERE id=?", (c["id"], match[1])
                )
                return {"ok": True}, None
            if path == "/api/admin/organizations" and method == "GET":
                self.store.admin(db, who)
                return {
                    "organizations": [
                        dict(r)
                        for r in db.execute("SELECT * FROM organizations ORDER BY name")
                    ]
                }, None
            if path == "/api/admin/assets":
                self.store.admin(db, who)
                if method == "GET":
                    return {
                        "assets": [
                            dict(r)
                            for r in db.execute(
                                "SELECT * FROM assets ORDER BY created DESC"
                            )
                        ],
                        "models": [
                            dict(r)
                            for r in db.execute(
                                "SELECT * FROM models ORDER BY created DESC"
                            )
                        ],
                    }, None
                name = text_field(data, "name", 2, 120)
                kind = text_field(data, "format")
                try:
                    content = base64.b64decode(
                        text_field(data, "content", 1, 17 * 1024 * 1024), validate=True
                    )
                    validate_model(content, kind)
                except (ValueError, TypeError):
                    raise Problem(
                        400,
                        "Modellen kunde inte godkännas. Använd en fristående GLB 2.0 eller ett okomprimerat USDZ-arkiv, högst 12 MB.",
                    )
                asset_id = uid()
                filename = asset_id + "." + kind
                directory = Path(os.environ.get("ASSET_PATH", ROOT / "data/assets"))
                directory.mkdir(parents=True, exist_ok=True)
                with (directory / filename).open("xb") as output:
                    output.write(content)
                db.execute(
                    "INSERT INTO assets VALUES(?,?,?,?,?,?,?)",
                    (
                        asset_id,
                        name,
                        kind,
                        filename,
                        len(content),
                        hashlib.sha256(content).hexdigest(),
                        now(),
                    ),
                )
                self.store.audit(db, who, "asset.uploaded", asset_id)
                return {"id": asset_id}, None
            if path == "/api/admin/models" and method == "POST":
                self.store.admin(db, who)
                mid = uid()
                name = text_field(data, "name", 2, 120)
                glb = text_field(data, "glb_asset_id")
                usdz = text_field(data, "usdz_asset_id")
                for aid, kind in [(glb, "glb"), (usdz, "usdz")]:
                    require(
                        db.execute(
                            "SELECT 1 FROM assets WHERE id=? AND format=?", (aid, kind)
                        ).fetchone(),
                        "Välj rätt format för varje plattform.",
                    )
                db.execute(
                    "INSERT INTO models VALUES(?,?,?,?,?)",
                    (mid, name, glb, usdz, now()),
                )
                return {"id": mid}, None
            match = re.fullmatch("/api/hunts/([a-f0-9]+)(?:/(start|collect))?", path)
            if match:
                cid, action = match.groups()
                if method == "GET" and not action:
                    return {"hunt": self.store.hunt(db, who, cid)}, None
                if method == "POST" and action == "start":
                    return self.store.start(db, who, cid), None
                if method == "POST" and action == "collect":
                    return self.store.collect(db, who, cid, data), None
            if path == "/api/vouchers" and method == "GET":
                return {"vouchers": self.store.vouchers(db, who)}, None

            if (
                path in ("/api/vouchers/check", "/api/vouchers/redeem")
                and method == "POST"
            ):
                return (
                    self.store.redeem(
                        db,
                        who,
                        text_field(data, "code", 10, 100),
                        path.endswith("/redeem"),
                    ),
                    None,
                )
            raise Problem(404, "Sidan hittades inte.")

    def checkout(self, db, c):
        require(
            c["status"] == "draft" and c["ends"] > now(),
            "Kampanjperioden behöver uppdateras innan betalning.",
            409,
        )
        secret = os.environ.get("STRIPE_SECRET_KEY")
        price = os.environ.get("STRIPE_PRICE_ID")
        base = os.environ.get("PUBLIC_URL", "")
        require(
            secret and price and base.startswith("https://"),
            "Betalning är inte konfigurerad ännu. Utkastet är sparat.",
            503,
        )
        require(not c["paid"], "Kampanjen är redan betald.", 409)
        existing = db.execute(
            "SELECT url FROM payment_orders WHERE campaign_id=? AND expires>? AND paid=0 ORDER BY expires DESC LIMIT 1",
            (c["id"], now() + 60),
        ).fetchone()
        if existing:
            return {"url": existing["url"]}
        fields = {
            "mode": "payment",
            "line_items[0][price]": price,
            "line_items[0][quantity]": "1",
            "success_url": base + "/?payment=received&campaign=" + c["id"],
            "cancel_url": base + "/?payment=cancelled&campaign=" + c["id"],
            "client_reference_id": c["id"],
            "metadata[campaign_id]": c["id"],
        }
        req = Request(
            "https://api.stripe.com/v1/checkout/sessions",
            data=urlencode(fields).encode(),
            headers={
                "Authorization": "Bearer " + secret,
                "Idempotency-Key": "campaign-" + c["id"] + "-" + str(now() // 3600),
            },
        )
        try:
            with urlopen(req, timeout=15) as response:
                session = json.load(response)
        except Exception:
            raise Problem(502, "Betaltjänsten svarar inte. Försök igen senare.")
        require(
            isinstance(session.get("amount_total"), int)
            and session["amount_total"] > 0,
            "Kampanjpriset är inte giltigt.",
            502,
        )
        db.execute(
            "INSERT OR IGNORE INTO payment_orders(session_id,campaign_id,amount,currency,url,expires) VALUES(?,?,?,?,?,?)",
            (
                session["id"],
                c["id"],
                session["amount_total"],
                session["currency"],
                session["url"],
                session["expires_at"],
            ),
        )
        return {"url": session["url"]}

    def webhook(self, e, raw, event):
        secret = os.environ.get("STRIPE_WEBHOOK_SECRET")
        require(secret, "Betalning är inte konfigurerad.", 503)
        parts = e.get("HTTP_STRIPE_SIGNATURE", "").split(",")
        values = {}
        for part in parts:
            key, _, value = part.partition("=")
            values.setdefault(key, []).append(value)
        stamp = values.get("t", ["0"])[0]
        require(
            stamp.isdigit() and abs(now() - int(stamp)) < 300, "Ogiltig signatur.", 400
        )
        expected = hmac.new(
            secret.encode(), stamp.encode() + b"." + raw, hashlib.sha256
        ).hexdigest()
        require(
            any(hmac.compare_digest(expected, v) for v in values.get("v1", [])),
            "Ogiltig signatur.",
            400,
        )
        with self.store.transaction() as db:
            eid = text_field(event, "id")
            if db.execute("SELECT 1 FROM webhook_events WHERE id=?", (eid,)).fetchone():
                return {"ok": True}
            if event.get("type") in (
                "checkout.session.completed",
                "checkout.session.async_payment_succeeded",
            ):
                session = event["data"]["object"]
                cid = session.get("metadata", {}).get("campaign_id")
                if session.get("payment_status") == "paid" and cid:
                    order = db.execute(
                        "SELECT * FROM payment_orders WHERE session_id=?",
                        (session.get("id"),),
                    ).fetchone()
                    require(
                        order
                        and order["campaign_id"] == cid
                        and order["amount"] == session.get("amount_total")
                        and order["currency"] == session.get("currency")
                        and session.get("mode") == "payment",
                        "Betalningen matchar inte beställningen.",
                        409,
                    )
                    self.store.campaign(db, cid)
                    db.execute(
                        "UPDATE payment_orders SET paid=1 WHERE session_id=?",
                        (session["id"],),
                    )
                    db.execute("UPDATE campaigns SET paid=1 WHERE id=?", (cid,))
                    self.store.audit(db, None, "payment.confirmed", cid)
            db.execute("INSERT INTO webhook_events VALUES(?,?)", (eid, now()))
        return {"ok": True}


def create_app():
    return App()


if __name__ == "__main__":
    from wsgiref.simple_server import make_server

    port = int(os.environ.get("PORT", 8787))
    app = create_app()
    print(f"VoucherHunt: http://127.0.0.1:{port}", flush=True)
    with make_server("127.0.0.1", port, app) as server:
        server.serve_forever()
