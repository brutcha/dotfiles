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
# The file may exist and be readable but empty on SKUs that expose the ACPI
# node without any profiles — treat empty as unsupported (silent no-op for TLP).
pp_choices=$(cat /sys/firmware/acpi/platform_profile_choices 2>/dev/null)
if [ -n "$pp_choices" ]; then
  printf '  choices: %s\n' "$pp_choices"
  printf '  active:  %s\n' "$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo unknown)"
else
  echo '  not supported on this SKU — PLATFORM_PROFILE_ON_BAT will be a silent no-op'
  echo '  -> OK to remove that TLP setting from hardware.nix (tidy)'
fi
unset pp_choices

section "Fingerprint reader"
# grep's exit status must drive the fallback, not sed's (sed returns 0 on
# empty input). Buffer the grep output first so we can test it directly.
if goodix=$(lsusb 2>/dev/null | grep -i '27c6') && [ -n "$goodix" ]; then
  printf '%s\n' "$goodix" | sed 's/^/  /'
else
  echo '  no Goodix device found'
fi
unset goodix

section "BIOS version"
if command -v fwupdmgr >/dev/null 2>&1; then
  fwupdmgr get-devices 2>/dev/null | awk '/System Firmware/,/^$/' | head -20 | sed 's/^/  /'
else
  echo '  fwupdmgr not available'
fi

section "GPU / VA-API"
lspci -nnk 2>/dev/null | grep -A2 VGA | sed 's/^/  /'

section "Battery health (approximate)"
# Guard the divisions: sysfs can return 0 or blank on uncalibrated / hot-swap /
# corrupt states, and `$((… / 0))` aborts the script under `set -u`. Read both
# counters, verify they're positive integers, then compute.
report_health() {
  # $1 = human label ("charge_full" | "energy_full")
  # $2 = current, $3 = design.
  # `[ "$X" -ge 0 ]` errors (silently, via stderr redirect) on non-numeric or
  # empty input → `if` branch not taken → we fall to the "skipped" printf.
  # Both operands need this guard: `$((… / 0))` and `$(( / … ))` both abort
  # the arithmetic under `set -u`.
  if [ "$2" -ge 0 ] 2>/dev/null && [ "$3" -gt 0 ] 2>/dev/null; then
    printf '  BAT0 %s=%s design=%s (health ~%d%%)\n' "$1" "$2" "$3" "$((100 * $2 / $3))"
  else
    printf '  BAT0 %s=%s design=%s (health: skipped — counter invalid or design zero)\n' "$1" "$2" "$3"
  fi
}
if [ -r /sys/class/power_supply/BAT0/charge_full ] && [ -r /sys/class/power_supply/BAT0/charge_full_design ]; then
  report_health charge_full \
    "$(cat /sys/class/power_supply/BAT0/charge_full)" \
    "$(cat /sys/class/power_supply/BAT0/charge_full_design)"
elif [ -r /sys/class/power_supply/BAT0/energy_full ] && [ -r /sys/class/power_supply/BAT0/energy_full_design ]; then
  report_health energy_full \
    "$(cat /sys/class/power_supply/BAT0/energy_full)" \
    "$(cat /sys/class/power_supply/BAT0/energy_full_design)"
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
