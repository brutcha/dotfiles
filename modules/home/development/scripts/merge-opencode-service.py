"""Merge Home Manager-owned environment values into OpenCode's service.json.

The activation passes the target path and JSON environment object through
OPENCODE_SERVICE_PATH and OPENCODE_SERVICE_ENV. Existing non-environment
settings remain untouched.
"""

import json
import os
import pathlib
import tempfile


path = pathlib.Path(os.environ["OPENCODE_SERVICE_PATH"])
owned = json.loads(os.environ["OPENCODE_SERVICE_ENV"])

try:
    existing = json.loads(path.read_text()) if path.exists() else {}
except json.JSONDecodeError:
    existing = {}

environment = (
    existing.get("env") if isinstance(existing.get("env"), dict) else {}
)
environment.update(owned)
existing["env"] = environment

path.parent.mkdir(parents=True, exist_ok=True)
fd, temporary_path = tempfile.mkstemp(prefix="service.json.", dir=path.parent)
with os.fdopen(fd, "w") as output:
    json.dump(existing, output, indent=2)
    output.write("\n")
os.chmod(temporary_path, 0o600)
os.replace(temporary_path, path)
