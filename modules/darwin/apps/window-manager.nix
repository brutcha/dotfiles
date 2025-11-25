{ config, lib, pkgs, ... }:
#
# macOS window management applications
#
# Available options:
# - darwin.apps.windowManager.raycast.enable  - Spotlight replacement
# - darwin.apps.windowManager.altTab.enable   - Window switcher
# - darwin.apps.windowManager.blurred.enable  - Dim inactive windows
#
let
  cfg = config.darwin.apps.windowManager;
in
{
  options.darwin.apps.windowManager = {
    raycast.enable = lib.mkEnableOption "Raycast - spotlight replacement";
    altTab.enable = lib.mkEnableOption "Alt-Tab - window switcher";
    blurred.enable = lib.mkEnableOption "Blurred - utility to dim background/inactive content";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.raycast.enable {
      nixpkgs.config.allowUnfreePredicate = pkg: (lib.getName pkg) == "raycast";
      environment.systemPackages = [ pkgs.raycast ];
    })

    (lib.mkIf cfg.altTab.enable {
      environment.systemPackages = [ pkgs.alt-tab-macos ];
    })

    (lib.mkIf cfg.blurred.enable {
      environment.systemPackages = [ pkgs.blurred ];
    })
  ];
}
