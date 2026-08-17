import subprocess

from menu_common import fuzzel_choose, menu_guard, read_file, tlp_tier

menu_guard("power")

profiles = [
    # AC tier is unset in hardware.nix; "performance" is TLP's default for it.
    ("Performance", tlp_tier("PLATFORM_PROFILE_ON_AC") or "performance"),
    ("Balanced", tlp_tier("PLATFORM_PROFILE_ON_BAT")),
    ("Power-saver", tlp_tier("PLATFORM_PROFILE_ON_SAV")),
]
current = read_file("/sys/firmware/acpi/platform_profile")

labels = []
for name, tier in profiles:
    marker = "●" if current and current == tier else "○"
    labels.append(f"{marker} {name}")

idx = fuzzel_choose(labels, "Power: ")
if idx is not None:
    chosen = profiles[idx][0]
    subprocess.run(["sudo", "tlp-profile-switch", chosen.lower()], check=True)
