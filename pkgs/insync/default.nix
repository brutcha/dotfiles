{ helpers }:
#
# Insync for macOS
#
# Google Drive/OneDrive sync client with multiple account support.
# Installed via Homebrew cask on macOS for easier updates.
# Linux uses the nixpkgs version (handled by overlay in pkgs/default.nix).
#
helpers.darwin.mkBrewCask { caskName = "insync"; }
