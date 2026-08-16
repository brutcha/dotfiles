#
# Custom package overlay
#
# Provides platform-specific custom packages that extend nixpkgs.
#
# Darwin packages:
# - insync: Custom DMG-based package (Linux uses nixpkgs x86_64 version)
# - blurred: Window dimming utility (macOS only)
# - docker-desktop: Docker Desktop with daemon and GUI (macOS only)
# - orbstack: Docker Desktop alternative with better performance (macOS only)
# - better-touch-tool: Gesture and touchpad configuration (macOS only)
# - raycast: Spotlight replacement (macOS only — nixpkgs not cached for darwin)
# - android-studio: IDE + AVD manager (macOS only — nixpkgs is Linux-only)
# - ungoogled-chromium: Chromium without Google dependencies (macOS custom, Linux uses nixpkgs)
#
# Cross-platform packages:
# - emdash: Multi-agent dev environment (brew cask on macOS, AppImage on Linux)
# - zed-editor: Editor (brew cask on macOS — nixpkgs not cached for darwin;
#   Linux uses nixpkgs version)
# - obs-studio: Screen recorder/streamer (brew cask on macOS — nixpkgs is Linux-only)
# - keepassxc: Password manager (brew cask on macOS — sidesteps qtmacextras
#   linker crash; Linux uses nixpkgs)
# - tokyonight-gtk-theme: GTK theme (nixpkgs dropped it over a dead GTK2
#   dependency the theme doesn't need — see pkgs/tokyonight-gtk-theme)
# - spotify-tray-wayland: Native Wayland/SNI Spotify tray icon, not in
#   nixpkgs (Linux-only — see pkgs/spotify-tray-wayland)
#
# This overlay is applied in flake.nix when creating the pkgs instance.
#
{ helpers }:
final: prev: {
  keepassxc =
    if prev.stdenv.hostPlatform.isDarwin
    then prev.callPackage ./keepassxc { inherit helpers; }
    else prev.keepassxc;

  insync =
    if prev.stdenv.hostPlatform.isDarwin
    then prev.callPackage ./insync { inherit helpers; }
    else prev.insync;
    
  blurred = prev.callPackage ./blurred { inherit helpers; };
  
  docker-desktop = prev.callPackage ./docker-desktop { inherit helpers; };
  
  orbstack = prev.callPackage ./orbstack { inherit helpers; };

  ungoogled-chromium =
    if prev.stdenv.hostPlatform.isDarwin
    then prev.callPackage ./ungoogled-chromium { inherit helpers; }
    else prev.ungoogled-chromium;

  better-touch-tool = prev.callPackage ./better-touch-tool { inherit helpers; };

  raycast =
    if prev.stdenv.hostPlatform.isDarwin
    then prev.callPackage ./raycast { inherit helpers; }
    else prev.raycast;

  android-studio =
    if prev.stdenv.hostPlatform.isDarwin
    then prev.callPackage ./android-studio { inherit helpers; }
    else prev.android-studio;

  emdash = prev.callPackage ./emdash { inherit helpers; };

  zed-editor =
    if prev.stdenv.hostPlatform.isDarwin
    then prev.callPackage ./zed-editor { inherit helpers; }
    else prev.zed-editor;
  
  microsoft-teams = prev.callPackage ./microsoft-teams { inherit helpers; };
  
  microsoft-outlook = prev.callPackage ./microsoft-outlook { inherit helpers; };
  
  affinity = prev.callPackage ./affinity { inherit helpers; };

  obs-studio = prev.callPackage ./obs-studio { inherit helpers; };

  tokyonight-gtk-theme = prev.callPackage ./tokyonight-gtk-theme { };

  spotify-tray-wayland = prev.callPackage ./spotify-tray-wayland { };
}
