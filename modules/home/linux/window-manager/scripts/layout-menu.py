import subprocess
import sys

from menu_common import fuzzel_choose, menu_guard, run_json

menu_guard("layout")

# Sway configures layouts on type:keyboard, i.e. every keyboard shares the same
# layout list — reading the first one and switching them all together is fine.
keyboard = None
for device in run_json(["swaymsg", "-t", "get_inputs", "--raw"]):
    if device["type"] == "keyboard" and device.get("xkb_layout_names"):
        keyboard = device
        break
if keyboard is None:
    sys.exit(0)

# Labels keep sway's own order, so the fuzzel index maps 1:1 to xkb_switch_layout.
active = keyboard["xkb_active_layout_index"]
labels = []
for index, name in enumerate(keyboard["xkb_layout_names"]):
    marker = "●" if index == active else "○"
    labels.append(f"{marker} {name}")

idx = fuzzel_choose(labels, "Layout: ")
if idx is not None:
    subprocess.run(
        ["swaymsg", "input", "type:keyboard", "xkb_switch_layout", str(idx)], check=True
    )
