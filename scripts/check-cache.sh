#!/usr/bin/env bash
#
# Probe cache.nixos.org for aarch64-darwin binaries of heavy packages.
#
# When to run:
#   - After `nix flake update` (or `nix flake update nixpkgs`)
#   - Before a `darwin-rebuild switch` if you've otherwise changed pkgs/
#
# Why:
#   nixpkgs' `nixpkgs-unstable` branch only promotes after Hydra's
#   channel-tested job set passes, but heavy darwin builds (mono,
#   dotnet-sdk, electron, …) are often NOT in that set. They may still
#   be missing from cache.nixos.org and force a hours-long source build.
#
# Output:
#   ✓ pkg: cached on nixpkgs           # safe to use pkgs.<pkg>
#   ✗ pkg: NOT cached (HTTP 404)       # would source-build
#
# When a watched package is missing:
#   a) Roll back the bump: `git restore flake.lock` (if just bumped)
#   b) Add an override in pkgs/ (brew via utils.darwin.mkBrewCask, or a
#      custom .dmg fetcher — see pkgs/zed-editor or pkgs/git-credential-manager)
#   c) Accept the source build (cached locally after, fast next time)
#
set -euo pipefail
cd "$(dirname "$0")/.."

# Heavy darwin builds that have bitten us. Add when fresh pain surfaces.
watchlist=(
  git-credential-manager
  zed-editor
  mono
  dotnet-sdk
  electron
)

system="aarch64-darwin"

echo "Probing cache.nixos.org for $system binaries..."
echo "  (current nixpkgs rev: $(nix flake metadata --json 2>/dev/null | jq -r '.locks.nodes.nixpkgs.locked.rev' | cut -c1-12))"
echo

missing=()
for pkg in "${watchlist[@]}"; do
  out=$(nix eval --impure --raw --expr "
    (import (builtins.getFlake (toString ./.)).inputs.nixpkgs {
      system = \"$system\"; config.allowUnfree = true;
    }).\"$pkg\".outPath" 2>/dev/null || echo "")

  if [[ -z "$out" ]]; then
    printf "  ⚠ %-28s eval failed (option, broken meta, or wrong name)\n" "$pkg:"
    continue
  fi

  hash=$(basename "$out" | cut -d- -f1)
  code=$(curl -sSI -m 5 "https://cache.nixos.org/$hash.narinfo" | head -1 | awk '{print $2}' || echo "??")

  if [[ "$code" == "200" ]]; then
    printf "  ✓ %-28s cached on nixpkgs\n" "$pkg:"
  else
    printf "  ✗ %-28s NOT cached (HTTP %s)\n" "$pkg:" "$code"
    missing+=("$pkg")
  fi
done

echo
if (( ${#missing[@]} > 0 )); then
  echo "${#missing[@]} package(s) would source-build: ${missing[*]}"
  echo
  echo "Mitigations:"
  echo "  - Roll back the flake.lock bump (git restore flake.lock)"
  echo "  - Override the package in pkgs/<name>/default.nix (brew or custom .dmg)"
  echo "  - Accept the source build (it caches locally after one run)"
  exit 1
fi

echo "✅ All watched packages are cached. Safe to rebuild."
