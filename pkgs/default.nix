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
# - karabiner-elements: Keyboard customizer (macOS only)
# - alt-tab-macos: Windows-style alt-tab (macOS only)
# - better-touch-tool: Gesture and touchpad configuration (macOS only)
# - ungoogled-chromium: Chromium without Google dependencies (macOS custom, Linux uses nixpkgs)
#
# This overlay is applied in flake.nix when creating the pkgs instance.
#
{ utils }:
final: prev: {
  insync = 
    if prev.stdenv.isDarwin
    then prev.callPackage ./insync { inherit utils; }
    else prev.insync;
    
  blurred = prev.callPackage ./blurred { inherit utils; };
  
  docker-desktop = prev.callPackage ./docker-desktop { inherit utils; };
  
  orbstack = prev.callPackage ./orbstack { inherit utils; };

  ungoogled-chromium =
    if prev.stdenv.isDarwin
    then prev.callPackage ./ungoogled-chromium { inherit utils; }
    else prev.ungoogled-chromium;

  better-touch-tool = prev.callPackage ./better-touch-tool { inherit utils; };
  
  karabiner-elements = prev.callPackage ./karabiner-elements { inherit utils; };
  
  alt-tab-macos = prev.callPackage ./alt-tab-macos { inherit utils; };
}
