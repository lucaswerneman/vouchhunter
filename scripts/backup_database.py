"""Create a timestamped SQLite snapshot without removing or replacing any file."""

import argparse
import datetime
from pathlib import Path
import sqlite3

parser = argparse.ArgumentParser()
parser.add_argument("--database", type=Path, required=True)
parser.add_argument("--destination", type=Path, required=True)
args = parser.parse_args()
if not args.database.is_file():
    raise SystemExit("Database does not exist.")
args.destination.mkdir(parents=True, exist_ok=True)
stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
output = args.destination / f"vouchhunter-{stamp}.sqlite3"
with output.open("xb"):
    pass
output.chmod(0o600)
with sqlite3.connect(
    f"file:{args.database.resolve()}?mode=ro", uri=True
) as source, sqlite3.connect(output) as target:
    source.backup(target)
    if target.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
        raise SystemExit(
            "Backup integrity check failed; file retained for investigation."
        )
print(output)
