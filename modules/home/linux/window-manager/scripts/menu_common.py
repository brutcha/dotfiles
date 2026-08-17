import atexit
import json
import os
import subprocess
import sys
import time
from collections.abc import Callable
from pathlib import Path
from typing import Any, NamedTuple

STATE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "waybar-menu"


class Sink(NamedTuple):
    id: int
    is_default: bool
    name: str


def read_file(path: str | Path) -> str:
    try:
        return Path(path).read_text().strip()
    except OSError:
        return ""


def run_json(cmd: list[str]) -> Any:
    out = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def process_gone(name: str) -> bool:
    check = subprocess.run(["pgrep", "-x", name], capture_output=True, check=False)
    return check.returncode != 0


def wait_until(
    condition: Callable[[], bool], attempts: int = 10, delay: float = 0.05
) -> bool:
    """Polls until condition() holds; False when attempts run out."""
    for _ in range(attempts):
        if condition():
            return True
        time.sleep(delay)
    return False


def menu_guard(name: str) -> None:
    """One menu at a time; re-clicking the open menu's module closes it."""
    kill = subprocess.run(["pkill", "-x", "fuzzel"], check=False)
    fuzzel_was_running = kill.returncode == 0
    if fuzzel_was_running:
        prev = read_file(STATE)
        STATE.unlink(missing_ok=True)
        if prev == name:
            sys.exit(0)
        # Let the killed fuzzel disappear before spawning ours.
        wait_until(lambda: process_gone("fuzzel"))
    STATE.write_text(name)

    # Only remove own state — a successor menu may own the file by now.
    def cleanup() -> None:
        if read_file(STATE) == name:
            STATE.unlink(missing_ok=True)

    atexit.register(cleanup)


def fuzzel_choose(labels: list[str], prompt: str) -> int | None:
    """Index of the picked entry, or None when dismissed or nothing matched."""
    if not labels:
        return None
    proc = subprocess.run(
        ["fuzzel", "--dmenu", "--index", "--anchor=top-right", "-p", prompt],
        input="\n".join(labels),
        capture_output=True,
        text=True,
        check=False,
    )
    try:
        idx = int(proc.stdout)  # fuzzel prints -1 for input matching no entry
    except ValueError:
        return None
    if proc.returncode != 0 or not 0 <= idx < len(labels):
        return None
    return idx


def default_sink_name(objects: list[Any]) -> str:
    """Name of the default sink, from pipewire's "default" metadata table."""
    for obj in objects:
        if obj.get("type") != "PipeWire:Interface:Metadata":
            continue
        if obj.get("props", {}).get("metadata.name") != "default":
            continue
        for entry in obj.get("metadata", []):
            if entry.get("key") == "default.audio.sink":
                return entry["value"].get("name", "")
    return ""


def audio_sinks() -> list[Sink]:
    objects = run_json(["pw-dump"])
    default = default_sink_name(objects)

    sinks: list[Sink] = []
    for obj in objects:
        if obj.get("type") != "PipeWire:Interface:Node":
            continue
        props = obj.get("info", {}).get("props", {})
        if props.get("media.class") != "Audio/Sink":
            continue
        name = props.get("node.description") or props.get("node.name", "?")
        sinks.append(Sink(obj["id"], props.get("node.name") == default, name))
    return sinks


def tlp_tier(key: str) -> str:
    for line in read_file("/etc/tlp.conf").splitlines():
        if line.startswith(key + "="):
            return line.split("=", 1)[1].strip('"')
    return ""
