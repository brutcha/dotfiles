{ utils }:
#
# Insync for macOS
#
# Google Drive/OneDrive sync client with multiple account support.
# Installed via Homebrew cask on macOS for easier updates.
# Linux uses the nixpkgs version (handled by overlay in pkgs/default.nix).
#
utils.darwin.mkBrewCask { caskName = "insync"; }
