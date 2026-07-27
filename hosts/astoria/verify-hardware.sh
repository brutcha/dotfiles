#!/usr/bin/env sh
# hosts/astoria/verify-hardware.sh — read-only hardware inventory for astoria.
# Prints values that hardware.nix currently assumes. Run during install
# (README Phase 2 step 5). If output contradicts hardware.nix, edit
# hardware.nix before / after nixos-install.

set -u

section() { printf '\n=== %s ===\n' "$1"; }

section "Machine identity"
if [ -r /sys/class/dmi/id/product_name ]; then
  printf 'DMI product: %s\n' "$(cat /sys/class/dmi/id/product_name)"
fi
printf 'CPU: %s\n' "$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')"
printf 'RAM: %s\n' "$(grep MemTotal /proc/meminfo | awk '{ printf "%.1f GiB\n", $2/1024/1024 }')"

section "Wi-Fi chip"
# hardware.nix assumes Intel AX201 (iwlwifi). Alternative SKU: Qualcomm QCA6390 (ath11k).
lspci -k 2>/dev/null | grep -A3 -i 'network controller' | sed 's/^/  /'
echo "  -> hardware.nix comment shows the alternate values if this is QCA6390."

section "Sleep modes supported by firmware"
# hardware.nix expects s2idle only. If 'deep' appears bracketed, kernel may pick it.
if [ -r /sys/power/mem_sleep ]; then
  printf '  /sys/power/mem_sleep: %s\n' "$(cat /sys/power/mem_sleep)"
else
  echo '  /sys/power/mem_sleep: not present (kernel may be too old)'
fi

section "Platform profile (TLP PLATFORM_PROFILE_ON_BAT)"
# If choices is empty/missing, PLATFORM_PROFILE_ON_BAT in TLP is a silent no-op.
if [ -r /sys/firmware/acpi/platform_profile_choices ]; then
  printf '  choices: %s\n' "$(cat /sys/firmware/acpi/platform_profile_choices)"
  printf '  active:  %s\n' "$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo unknown)"
else
  echo '  not supported on this SKU — PLATFORM_PROFILE_ON_BAT will be a silent no-op'
  echo '  -> OK to remove that TLP setting from hardware.nix (tidy)'
fi

section "Fingerprint reader"
lsusb 2>/dev/null | grep -i '27c6' | sed 's/^/  /' || echo '  no Goodix device found'

section "BIOS version"
if command -v fwupdmgr >/dev/null 2>&1; then
  fwupdmgr get-devices 2>/dev/null | awk '/System Firmware/,/^$/' | head -20 | sed 's/^/  /'
else
  echo '  fwupdmgr not available'
fi

section "GPU / VA-API"
lspci -nnk 2>/dev/null | grep -A2 VGA | sed 's/^/  /'

section "Battery health (approximate)"
if [ -r /sys/class/power_supply/BAT0/charge_full ] && [ -r /sys/class/power_supply/BAT0/charge_full_design ]; then
  now=$(cat /sys/class/power_supply/BAT0/charge_full)
  design=$(cat /sys/class/power_supply/BAT0/charge_full_design)
  printf '  BAT0 charge_full=%s design=%s (health ~%d%%)\n' "$now" "$design" "$((100 * now / design))"
elif [ -r /sys/class/power_supply/BAT0/energy_full ] && [ -r /sys/class/power_supply/BAT0/energy_full_design ]; then
  now=$(cat /sys/class/power_supply/BAT0/energy_full)
  design=$(cat /sys/class/power_supply/BAT0/energy_full_design)
  printf '  BAT0 energy_full=%s design=%s (health ~%d%%)\n' "$now" "$design" "$((100 * now / design))"
else
  echo '  BAT0 counters not readable'
fi

section "Notes"
cat <<'EOF'
  - Thermal / throttled verification (CPU pinned at ~2.4 GHz under load) needs
    stress-ng which isn't in the minimal ISO. Run post-install:
      nix-shell -p stress-ng s-tui
      stress-ng --cpu $(nproc) --timeout 5m &  s-tui
  - Any value above that contradicts hardware.nix -> edit hardware.nix before
    nixos-install (README Phase 3 step 6), or in a post-install rebuild.
EOF
