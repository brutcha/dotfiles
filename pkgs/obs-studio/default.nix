{ helpers, stdenv, obs-studio }:
#
# OBS Studio — https://obsproject.com
#
# nixpkgs obs-studio is Linux-only; macOS uses the Homebrew cask (official
# signed build). Virtual camera (OBS 28+) needs one-time approval in
# System Settings → Privacy & Security after first "Start Virtual Camera".
#
if stdenv.hostPlatform.isDarwin then
  helpers.darwin.mkBrewCask { caskName = "obs"; }
else
  obs-studio
