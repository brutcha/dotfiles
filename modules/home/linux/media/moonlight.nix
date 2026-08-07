{ config, lib, pkgs, ... }:
#
# Moonlight (https://moonlight-stream.org) — GameStream/Sunshine client.
#
# Available options:
# - home.apps.media.moonlight.enable
#
let
  cfg = config.home.apps.media.moonlight;
in
{
  options.home.apps.media.moonlight.enable =
    lib.mkEnableOption "Moonlight streaming client (moonlight-qt)";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.moonlight-qt ];
  };
}
