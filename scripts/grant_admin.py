"""Explicit local bootstrap. Does not create accounts or accept passwords."""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from backend.app import Store, ROOT, now

parser = argparse.ArgumentParser()
parser.add_argument("--email", required=True)
parser.add_argument("--database", type=Path, default=ROOT / "data/vouchhunter.sqlite3")
args = parser.parse_args()
if not args.database.is_file():
    raise SystemExit(
        "Create the account in Vouchhunter first. Database does not exist."
    )
store = Store(args.database)
with store.transaction() as db:
    user = db.execute(
        "SELECT id FROM users WHERE email=?", (args.email.strip().lower(),)
    ).fetchone()
    if not user:
        raise SystemExit("No matching account. Nothing changed.")
    db.execute("INSERT OR IGNORE INTO platform_admins VALUES(?)", (user["id"],))
    store.audit(db, None, "admin.granted", user["id"])
print("Platform administrator access granted to the specified existing account.")
