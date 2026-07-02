{ utils }:
#
# Zed editor for macOS
#
# Installed via Homebrew cask — nixpkgs builds from Rust source and is
# never cached on aarch64-darwin (Hydra doesn't publish a binary). Brew
# delivers the official prebuilt with auto-updates.
#
# Linux uses the nixpkgs version (handled by overlay in pkgs/default.nix).
#
# Periodically check whether nixpkgs starts shipping a cached darwin
# binary; when it does, drop this override and rely on `prev.zed-editor`.
#   nixpkgs source : https://github.com/NixOS/nixpkgs/tree/master/pkgs/by-name/ze/zed-editor
#   upstream cache tracking issue: https://github.com/zed-industries/zed/issues/26277
#
utils.darwin.mkBrewCask { caskName = "zed"; }
