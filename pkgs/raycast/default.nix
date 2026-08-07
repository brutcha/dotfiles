{ helpers }:
#
# Raycast for macOS
#
# Installed via Homebrew cask — nixpkgs builds it but doesn't publish a
# cached binary for aarch64-darwin (Hydra coverage gap), so the nixpkgs
# path would source-build. Brew uses Raycast's official signed installer.
#
# Periodically check whether nixpkgs starts shipping a cached darwin
# binary; when it does, drop this override and rely on `prev.raycast`.
#   nixpkgs source : https://github.com/NixOS/nixpkgs/tree/master/pkgs/by-name/ra/raycast
#
# Raycast is darwin-only (no Linux build); the overlay leaves Linux alone.
#
helpers.darwin.mkBrewCask { caskName = "raycast"; }
