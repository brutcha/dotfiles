import subprocess

from menu_common import audio_sinks, fuzzel_choose, menu_guard

menu_guard("audio")

sinks = audio_sinks()
labels = []
for sink in sinks:
    marker = "●" if sink.is_default else "○"
    labels.append(f"{marker} {sink.name}")

idx = fuzzel_choose(labels, "Audio: ")
if idx is not None:
    subprocess.run(["wpctl", "set-default", str(sinks[idx].id)], check=True)
