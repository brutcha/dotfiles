{ config, lib, pkgs, ... }:
#
# Thunar (https://docs.xfce.org/xfce/thunar/start) — GTK file manager.
#
# Available options:
# - home.apps.filemanager.thunar.enable
#
# No upstream HM module; install packages only. GTK theming inherits from
# the host's gtk = { ... }; block.
#
let
  cfg = config.home.apps.filemanager.thunar;
in
{
  options.home.apps.filemanager.thunar.enable =
    lib.mkEnableOption "Thunar file manager with volume automount";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      xfce.thunar
      xfce.thunar-volman
      xfce.thunar-archive-plugin
    ];
  };
}
