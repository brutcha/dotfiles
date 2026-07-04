{ config, lib, pkgs, ... }:
#
# macOS media applications
#
# Available options:
# - darwin.apps.media.affinity.enable   - chat, video calling, and collaboration platform
#
let
  cfg = config.darwin.apps.media;
in
{
  options.darwin.apps.media = {
    affinity.enable = lib.mkEnableOption "Affinity - Image editing and design software";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.affinity.enable {
      environment.systemPackages = [ pkgs.affinity ];
    })
  ];
}
