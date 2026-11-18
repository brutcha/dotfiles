"""Merge Home Manager-owned environment values into OpenCode's service.json.

The activation passes the target path and JSON environment object through
OPENCODE_SERVICE_PATH and OPENCODE_SERVICE_ENV. Existing non-environment
settings remain untouched.
"""

import json
import os
import pathlib
import sys
import tempfile

path = pathlib.Path(os.environ["OPENCODE_SERVICE_PATH"])
owned = json.loads(os.environ["OPENCODE_SERVICE_ENV"])
if not isinstance(owned, dict):
    raise TypeError("OPENCODE_SERVICE_ENV must be a JSON object")

if path.exists():
    try:
        existing = json.loads(path.read_text(encoding="utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        print(
            f"warn: {path} is malformed — preserving it; the OpenCode service "
            "will start without the managed environment. Repair service.json "
            "before the next activation can merge it.",
            file=sys.stderr,
        )
        raise SystemExit(0)
    if not isinstance(existing, dict):
        print(
            f"warn: {path} is not a JSON object — preserving it; the OpenCode "
            "service will start without the managed environment. Repair "
            "service.json before the next activation can merge it.",
            file=sys.stderr,
        )
        raise SystemExit(0)
else:
    existing = {}

environment = existing.get("env")
if not isinstance(environment, dict):
    environment = {}
environment.update(owned)
existing["env"] = environment

path.parent.mkdir(parents=True, exist_ok=True)
fd, temporary_path = tempfile.mkstemp(prefix="service.json.", dir=path.parent)
try:
    with os.fdopen(fd, "w") as output:
        json.dump(existing, output, indent=2)
        output.write("\n")
    os.chmod(temporary_path, 0o600)
    os.replace(temporary_path, path)
finally:
    pathlib.Path(temporary_path).unlink(missing_ok=True)
