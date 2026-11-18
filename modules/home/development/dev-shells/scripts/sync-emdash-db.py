"""Synchronize one project's Emdash database record.

The activation supplies the repository path, desired preserve patterns, setup
script, and SQLite database path. Missing or malformed records are left alone.
"""

import argparse
import json
import pathlib
import sqlite3
import time


parser = argparse.ArgumentParser()
parser.add_argument("--project-directory", required=True)
parser.add_argument("--preserve-patterns", required=True)
parser.add_argument("--setup-script", required=True)
parser.add_argument("--database", required=True)
args = parser.parse_args()

database = pathlib.Path(args.database)
if not database.is_file():
    raise SystemExit(0)

connection = sqlite3.connect(database)
try:
    row = connection.execute(
        "SELECT id, personal_config FROM workspace_records "
        "WHERE path = ? AND kind = 'repository'",
        (args.project_directory,),
    ).fetchone()
    if row is None:
        raise SystemExit(0)

    try:
        current = json.loads(row[1] or "{}")
    except json.JSONDecodeError:
        print(
            "warn: emdash DB sync could not parse personal_config — skipping"
        )
        raise SystemExit(0)

    value = current.setdefault("value", {})
    value["preservePatterns"] = json.loads(args.preserve_patterns)
    value.setdefault("scripts", {})["setup"] = args.setup_script
    current["version"] = "2"
    rendered = json.dumps(current, separators=(",", ":"))
    if rendered == (row[1] or "{}"):
        raise SystemExit(0)

    connection.execute(
        "UPDATE workspace_records SET personal_config = ?, updated_at = ? "
        "WHERE id = ?",
        (rendered, int(time.time() * 1000), row[0]),
    )
    connection.commit()
finally:
    connection.close()
