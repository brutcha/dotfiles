{ config, lib, pkgs, ... }:
#
# macOS internet applications
#
# Available options:
# - darwin.apps.internet.microsoft-teams.enable-    - chat, video calling, and collaboration platform
# - darwin.apps.internet.microsoft-outlook.enable   - email, calendar, and contacts client 
#
let
  cfg = config.darwin.apps.internet;
in
{
  options.darwin.apps.internet = {
    microsoft-teams.enable = lib.mkEnableOption "Microsoft Teams - chat, video calling, and collaboration platform";
    microsoft-outlook.enable = lib.mkEnableOption "Microsoft Outlook - email, calendar, and contacts client";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.microsoft-teams.enable {
      environment.systemPackages = [ pkgs.microsoft-teams ];
    })

    (lib.mkIf cfg.microsoft-outlook.enable {
      environment.systemPackages = [ pkgs.microsoft-outlook ];
    })
  ];
}
