{ helpers }:
#
# Android Studio for macOS
#
# Installed via Homebrew cask — nixpkgs android-studio is x86_64-linux only
# (no darwin build), so brew is the only real option on aarch64-darwin.
#   nixpkgs source : https://github.com/NixOS/nixpkgs/tree/master/pkgs/applications/editors/android-studio
#
# Android Studio is darwin-only in this overlay; the SDK Manager still runs
# inside the app to fetch platform-tools/emulator/system-images at first run.
#
helpers.darwin.mkBrewCask { caskName = "android-studio"; }
