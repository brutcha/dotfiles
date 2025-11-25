{ config, lib, pkgs, ... }:
#
# Cross-platform internet applications
#
# Available options:
# - shared.apps.internet.telegram.enable         - Messaging app
# - shared.apps.internet.slack.enable            - Team communication (unfree)
# - shared.apps.internet.discord.enable          - Voice/video/text chat (unfree)
# - shared.apps.internet.protonmail-bridge.enable - Email bridge for Proton Mail
#
let
  cfg = config.shared.apps.internet;
in
{
  options.shared.apps.internet = {
    telegram.enable = lib.mkEnableOption "Telegram Desktop - messaging app";
    slack.enable = lib.mkEnableOption "Slack - team communication";
    discord.enable = lib.mkEnableOption "Discord - voice, video and text chat";
    protonmail-bridge.enable = lib.mkEnableOption "Proton Mail Bridge - email bridge";
    ungoogled-chromium.enable = lib.mkEnableOption "Open source web browser from Google, with dependencies on Google web services removed";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.telegram.enable {
      environment.systemPackages = [ pkgs.telegram-desktop ];
    })

    (lib.mkIf cfg.slack.enable {
      nixpkgs.config.allowUnfreePredicate = pkg: (lib.getName pkg) == "slack";
      environment.systemPackages = [ pkgs.slack ];
    })

    (lib.mkIf cfg.discord.enable {
      nixpkgs.config.allowUnfreePredicate = pkg: (lib.getName pkg) == "discord";
      environment.systemPackages = [ pkgs.discord ];
    })

    (lib.mkIf cfg.protonmail-bridge.enable {
      environment.systemPackages = [ pkgs.protonmail-bridge ];
    })

    (lib.mkIf cfg.ungoogled-chromium.enable {
        environment.systemPackages = [ pkgs.ungoogled-chromium ];
      })
  ];
}
