"""Materialize one project's development sidecar and CLI-specific state.

The generated JSON specification names immutable rendered inputs and mutable
destinations. Runtime `$CORP_*` references are resolved from the activation
environment; missing values are reported and omitted rather than written.
"""

import argparse
import json
import os
import pathlib
import re
import shutil
import stat
from dev_shell_scripts import copy_if_changed, is_corp_reference, write_text_if_changed


def materialize_env(path: pathlib.Path, values: dict[str, str]) -> None:
    lines = []
    for name, value in values.items():
        if is_corp_reference(value):
            variable = value[1:]
            if variable not in os.environ:
                print(f"warn: env var {variable} unset — skipping env.sh key {name}", file=os.sys.stderr)
                continue
            value = os.environ[variable]
        if "\n" in value or "\r" in value:
            print(f"warn: env {name} contains a newline — skipping env.sh emit", file=os.sys.stderr)
            continue
        escaped = value.replace("'", "'\"'\"'")
        lines.append(f"export {name}='{escaped}'\n")
    write_text_if_changed(path, "".join(lines), 0o600)


def replace_json(path: pathlib.Path, document: object, mode: int) -> None:
    write_text_if_changed(path, json.dumps(document, separators=(",", ":")) + "\n", mode)


def resolve_mcps(servers: object) -> object:
    if not isinstance(servers, dict):
        return servers
    resolved = json.loads(json.dumps(servers))
    for name, server in resolved.items():
        if not isinstance(server, dict):
            continue
        environment = server.get("env")
        if isinstance(environment, dict):
            for key, value in environment.items():
                if isinstance(value, str) and value.startswith("$"):
                    variable = value[1:]
                    if variable not in os.environ:
                        raise ValueError(f"MCP {name}: env ref ${variable} unset")
                    environment[key] = os.environ[variable]
        if isinstance(server.get("authorization_env_var"), str):
            variable = server["authorization_env_var"]
            if variable not in os.environ:
                raise ValueError(f"MCP {name}: authorization env ${variable} unset")
            headers = server.setdefault("headers", {})
            if not isinstance(headers, dict):
                headers = server["headers"] = {}
            headers["Authorization"] = os.environ[variable]
            del server["authorization_env_var"]
    return resolved


parser = argparse.ArgumentParser()
parser.add_argument("--spec", required=True)
args = parser.parse_args()
spec = json.loads(pathlib.Path(args.spec).read_text())

sidecar = pathlib.Path(spec["sidecarDirectory"])
sidecar.mkdir(mode=0o755, parents=True, exist_ok=True)
for name, source in spec["sidecarFiles"].items():
    copy_if_changed(pathlib.Path(source), sidecar / name, 0o755 if name == "workmux-post-create" else 0o644)
materialize_env(sidecar / "env.sh", spec["environment"])

repository = pathlib.Path(spec["repositoryDirectory"])
if repository.is_dir():
    for name in (".emdash.json", ".envrc"):
        destination = repository / name
        if destination.is_symlink():
            destination.unlink()
        copy_if_changed(sidecar / name, destination, 0o644)

    workmux = repository / ".workmux.yaml"
    old_hook = ".local/share/workmux-trial/npa-worktree-bootstrap.sh"
    if not workmux.exists() and not workmux.is_symlink():
        copy_if_changed(pathlib.Path(spec["workmuxConfig"]), workmux, 0o644)
    elif workmux.is_file() and old_hook in workmux.read_text():
        write_text_if_changed(workmux, workmux.read_text().replace(old_hook, str(sidecar / "workmux-post-create")), 0o644)

marketplace_source = spec.get("marketplaceSource")
marketplace_destination = spec.get("marketplaceDestination")
if marketplace_source and marketplace_destination:
    source = pathlib.Path(marketplace_source)
    destination = pathlib.Path(marketplace_destination)
    if source.is_dir():
        shutil.copytree(source, destination, dirs_exist_ok=True)
        for root, directories, files in os.walk(destination):
            for name in [*directories, *files]:
                path = pathlib.Path(root) / name
                path.chmod(path.stat().st_mode | stat.S_IWUSR)

codex = spec.get("codex")
if isinstance(codex, dict):
    destination = pathlib.Path(codex["home"])
    destination.mkdir(mode=0o700, parents=True, exist_ok=True)
    rendered = pathlib.Path(codex["config"]).read_text()
    rendered = re.sub(r"\$CORP_[A-Z_]+", lambda match: os.environ.get(match.group()[1:], match.group()), rendered)
    write_text_if_changed(destination / "config.toml", rendered, 0o600)
    auth = pathlib.Path.home() / ".codex" / "auth.json"
    target = destination / "auth.json"
    if target.is_symlink() or target.exists():
        target.unlink()
    target.symlink_to(auth)

claude = spec.get("claude")
if isinstance(claude, dict):
    destination = pathlib.Path(claude["home"])
    destination.mkdir(mode=0o700, parents=True, exist_ok=True)
    global_claude = pathlib.Path.home() / ".claude"
    settings = global_claude / "settings.json"
    if settings.is_file():
        copy_if_changed(settings, destination / "settings.json", 0o600)
    else:
        print(f"warn: ~/.claude/settings.json missing — skipping {spec['projectId']} Claude snapshot", file=os.sys.stderr)
    try:
        mcps = resolve_mcps(json.loads(pathlib.Path(claude["mcpServers"]).read_text()))
    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"warn: {spec['projectId']} MCP snapshot skipped — {error}; prior value left in place", file=os.sys.stderr)
    else:
        claude_json = destination / ".claude.json"
        try:
            document = json.loads(claude_json.read_text()) if claude_json.is_file() else {}
        except json.JSONDecodeError:
            document = {}
        if isinstance(document, dict):
            document["mcpServers"] = mcps
            replace_json(claude_json, document, 0o600)
    for name in ("CLAUDE.md", "RTK.md", "plugins"):
        source = global_claude / name
        target = destination / name
        if source.exists() or source.is_symlink():
            if target.is_symlink() or target.exists():
                target.unlink() if target.is_symlink() or target.is_file() else shutil.rmtree(target)
            target.symlink_to(source)
    skills = destination / "skills"
    if skills.is_symlink():
        skills.unlink()
    skills.mkdir(mode=0o755, exist_ok=True)
    for child in skills.iterdir():
        if child.is_symlink() and os.readlink(child).startswith("/nix/store/"):
            child.unlink()
        elif child.is_dir() and (child / ".nix-source").is_file():
            shutil.rmtree(child)
