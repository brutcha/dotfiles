"""Update managed .env.local keys from the current environment.

Keys are supplied on the command line; paths are optional. Symlinks, missing
files, empty values, and values containing newlines are preserved unchanged.
"""

import argparse
import os
import pathlib
import re


parser = argparse.ArgumentParser()
parser.add_argument("--keys", nargs="+", required=True)
parser.add_argument("paths", nargs="*")
args = parser.parse_args()

keys = set(args.keys)
for raw_path in args.paths:
    path = pathlib.Path(raw_path)
    if not path.is_file() or path.is_symlink():
        continue
    path.chmod(0o600)
    output = []
    seen = set()
    changed = False
    for line in path.read_text().splitlines(keepends=True):
        match = re.match(r"([^=]+)=(.*)", line.rstrip("\n"))
        if match is None or match.group(1) not in keys:
            output.append(line)
            continue
        key, old = match.groups()
        seen.add(key)
        value = os.environ.get(key)
        if not value or "\n" in value or "\r" in value:
            output.append(line)
            continue
        rendered = f"{key}={value}\n"
        output.append(rendered)
        changed |= rendered != line
    for key in sorted(keys - seen):
        value = os.environ.get(key)
        if value and "\n" not in value and "\r" not in value:
            output.append(f"{key}={value}\n")
            changed = True
    if changed:
        temporary = path.with_suffix(path.suffix + ".tmp")
        temporary.write_text("".join(output))
        temporary.chmod(0o600)
        temporary.replace(path)
