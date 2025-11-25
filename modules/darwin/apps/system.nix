{ config, lib, pkgs, ... }:
#
# macOS system-level applications
#
# Available options:
# - darwin.apps.system.aldente.enable          - Battery charge limiter
# - darwin.apps.system.karabiner.enable        - Keyboard customizer
# - darwin.apps.system.better-touch-tool.enable - Custom gesture and touchpad configuration
#
let
  cfg = config.darwin.apps.system;
in
{
  options.darwin.apps.system = {
    aldente.enable = lib.mkEnableOption "AlDente - battery charge limiter";
    karabiner.enable = lib.mkEnableOption "Karabiner-Elements - keyboard customizer";
    better-touch-tool.enable = lib.mkEnableOption "BetterTouchTool - gesture and touchpad configuration";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.aldente.enable {
      nixpkgs.config.allowUnfreePredicate = pkg: (lib.getName pkg) == "aldente";
      environment.systemPackages = [ pkgs.aldente ];
    })

    (lib.mkIf cfg.karabiner.enable {
      environment.systemPackages = [ pkgs.karabiner-elements ];
    })

    (lib.mkIf cfg.better-touch-tool.enable {
      nixpkgs.config.allowUnfreePredicate = pkg: (lib.getName pkg) == "better-touch-tool";
      environment.systemPackages = [ pkgs.better-touch-tool ];
    })
  ];
}
