"""Populate Codex's per-project plugin cache from the configured marketplace.

The project home and plugin identifiers come from corp-project.nix. Failed
installs are reported but do not prevent other plugins from being refreshed.
"""

import argparse
import os
import subprocess


parser = argparse.ArgumentParser()
parser.add_argument("--codex", required=True)
parser.add_argument("--home", required=True)
parser.add_argument("plugins", nargs="+")
args = parser.parse_args()

environment = os.environ | {"CODEX_HOME": args.home}
for plugin in args.plugins:
    try:
        result = subprocess.run(
            [args.codex, "plugin", "add", plugin, "--json"],
            env=environment,
            stdout=subprocess.DEVNULL,
            check=False,
        )
    except OSError as error:
        print(f"warn: codex plugin add {plugin} could not start: {error}", file=os.sys.stderr)
        continue
    if result.returncode:
        print(f"warn: codex plugin add {plugin} failed", file=os.sys.stderr)
