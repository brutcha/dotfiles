{ utils }:
#
# Ungoogled Chromium for macOS
#
# Chromium browser with Google dependencies removed.
# Installed via Homebrew cask on macOS for easier updates.
# Linux uses the nixpkgs version (handled by overlay in pkgs/default.nix).
#
utils.darwin.mkBrewCask { caskName = "ungoogled-chromium"; }
