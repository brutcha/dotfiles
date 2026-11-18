"""Synchronize Claude's project marketplace and plugin state.

Inputs identify Claude's project config, marketplace mirror, global settings,
and a rendered plugin specification. Configuration values beginning with `$`
are resolved from the caller's environment; a plugin is skipped if one is unset.
"""

import argparse
import datetime
import json
import os
import pathlib
import subprocess
import sys

from dev_shell_scripts import is_corp_reference, write_text_if_changed


def read_json(path: pathlib.Path) -> object | None:
    try:
        return json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        print(f"warn: could not read {path}: {error}", file=sys.stderr)
        return None


parser = argparse.ArgumentParser()
parser.add_argument("--claude", required=True)
parser.add_argument("--config-directory", required=True)
parser.add_argument("--marketplace", required=True)
parser.add_argument("--marketplace-directory", required=True)
parser.add_argument("--settings-file", required=True)
parser.add_argument("--spec", required=True)
parser.add_argument("--repository-directory", required=True)
args = parser.parse_args()

claude = pathlib.Path(args.claude)
config_directory = pathlib.Path(args.config_directory)
marketplace_directory = pathlib.Path(args.marketplace_directory)
settings_file = pathlib.Path(args.settings_file)
repository_directory = pathlib.Path(args.repository_directory)
spec = read_json(pathlib.Path(args.spec))
if not claude.is_file() or not os.access(claude, os.X_OK) or not isinstance(spec, list):
    raise SystemExit(0)

environment = os.environ | {"CLAUDE_CONFIG_DIR": str(config_directory)}
known_marketplaces = config_directory / "plugins" / "known_marketplaces.json"
if known_marketplaces.is_file():
    document = read_json(known_marketplaces)
    if isinstance(document, dict):
        entry = document.setdefault(args.marketplace, {})
        if isinstance(entry, dict):
            source = entry.setdefault("source", {})
            if isinstance(source, dict):
                source["path"] = str(marketplace_directory)
            entry["installLocation"] = str(marketplace_directory)
            write_text_if_changed(known_marketplaces, json.dumps(document, separators=(",", ":")) + "\n", 0o644)

if settings_file.is_file():
    document = read_json(settings_file)
    if isinstance(document, dict) and isinstance(document.get("extraKnownMarketplaces"), dict):
        marketplaces = document["extraKnownMarketplaces"]
        retained = {
            name: value for name, value in marketplaces.items()
            if not (
                isinstance(value, dict)
                and isinstance(value.get("source"), dict)
                and value["source"].get("source") == "directory"
                and str(value["source"].get("path", "")).startswith("/nix/store/")
            )
        }
        if retained:
            document["extraKnownMarketplaces"] = retained
        else:
            document.pop("extraKnownMarketplaces", None)
        write_text_if_changed(settings_file, json.dumps(document, separators=(",", ":")) + "\n", 0o600)

subprocess.run([str(claude), "plugin", "marketplace", "update", args.marketplace], env=environment, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)

for plugin in spec:
    if not isinstance(plugin, dict):
        continue
    plugin_id = plugin.get("id")
    name = plugin.get("name")
    marketplace = plugin.get("marketplace")
    if not all(isinstance(value, str) and value for value in (plugin_id, name, marketplace)):
        continue
    assert isinstance(plugin_id, str)
    assert isinstance(name, str)
    assert isinstance(marketplace, str)
    plugin_config = plugin.get("config", {})
    if not isinstance(plugin_config, dict):
        continue
    settings: list[str] = []
    for key, value in plugin_config.items():
        if not isinstance(key, str) or not isinstance(value, str):
            continue
        if is_corp_reference(value):
            resolved = environment.get(value[1:])
            if resolved is None:
                print(f"warn: env var {value[1:]} unset — skipping {plugin_id}.{key} sync", file=sys.stderr)
                break
            value = resolved
        settings.extend(["--config", f"{key}={value}"])
    else:
        subprocess.run([str(claude), "plugin", "update", plugin_id, "-s", "user", "-y"], env=environment, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        installed = subprocess.run([str(claude), "plugin", "install", plugin_id, "-s", "user", "-y", *settings, "--json"], env=environment, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        if installed.returncode:
            print(f"warn: claude plugin install {plugin_id} failed", file=sys.stderr)

        version = plugin.get("version")
        cache_prefix = config_directory / "plugins" / "cache" / marketplace / name
        install_path = cache_prefix / version if isinstance(version, str) and version else None
        installed_plugins = config_directory / "plugins" / "installed_plugins.json"
        document = read_json(installed_plugins) if install_path and install_path.is_dir() else None
        if isinstance(document, dict) and isinstance(document.get("plugins"), dict):
            entries = document["plugins"].get(plugin_id)
            if isinstance(entries, list):
                changed = False
                for entry in entries:
                    if (
                        isinstance(entry, dict)
                        and entry.get("scope") in {"local", "project"}
                        and entry.get("projectPath") == str(repository_directory)
                        and entry.get("version") != version
                        and str(entry.get("installPath", "")).startswith(f"{cache_prefix}/")
                    ):
                        entry.update({"version": version, "installPath": str(install_path), "lastUpdated": datetime.datetime.now(datetime.UTC).isoformat().replace("+00:00", "Z")})
                        changed = True
                if changed:
                    write_text_if_changed(installed_plugins, json.dumps(document, separators=(",", ":")) + "\n", 0o644)
