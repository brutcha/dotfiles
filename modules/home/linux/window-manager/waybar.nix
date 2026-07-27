{ config, lib, pkgs, ... }:
#
# Waybar (https://github.com/Alexays/Waybar) — Sway status bar.
#
# Available options:
# - home.apps.windowManager.waybar.enable
#
# The `tray` module is required for blueman-applet (StatusNotifierItem);
# without it the applet runs invisibly.
#
let
  cfg = config.home.apps.windowManager.waybar;
  c = config.theme.dark;
in
{
  options.home.apps.windowManager.waybar.enable =
    lib.mkEnableOption "Waybar status bar for Sway";

  config = lib.mkIf cfg.enable {
    programs.waybar = {
      enable = true;
      systemd.enable = true;

      settings.mainBar = {
        layer = "top";
        position = "top";
        height = 28;
        spacing = 6;
        modules-left = [ "sway/workspaces" "sway/mode" ];
        modules-center = [ "sway/window" ];
        modules-right = [ "tray" "pulseaudio" "network" "battery" "clock" ];

        "sway/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
        };

        tray = { spacing = 10; };

        clock = {
          format = "{:%a %d %b  %H:%M}";
          tooltip-format = "<big>{:%Y-%m-%d}</big>\n<tt>{calendar}</tt>";
        };

        battery = {
          format = "{capacity}% {icon}";
          format-icons = [ "" "" "" "" "" ];
          format-charging = "{capacity}% ";
          states = { warning = 30; critical = 15; };
        };

        network = {
          format-wifi = "{essid} ({signalStrength}%) ";
          format-ethernet = "{ifname} ";
          format-disconnected = "disconnected ⚠";
          tooltip-format = "{ifname}: {ipaddr}/{cidr}";
        };

        pulseaudio = {
          format = "{volume}% {icon}";
          format-muted = "muted ";
          format-icons = { default = [ "" "" "" ]; };
          on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
        };
      };

      style = ''
        * {
          font-family: "JetBrainsMonoNL Nerd Font", monospace;
          font-size: 12px;
          border: none;
          border-radius: 0;
          min-height: 0;
        }

        window#waybar {
          background: ${c.bg};
          color: ${c.fg};
        }

        #workspaces button {
          padding: 0 8px;
          color: ${c.fg_dark};
          background: transparent;
          border-bottom: 2px solid transparent;
        }
        #workspaces button.focused {
          color: ${c.fg};
          border-bottom: 2px solid ${c.blue};
        }
        #workspaces button.urgent {
          color: ${c.red};
          border-bottom: 2px solid ${c.red};
        }

        #clock, #battery, #network, #pulseaudio, #tray, #mode {
          padding: 0 10px;
          color: ${c.fg};
        }

        #battery.warning  { color: ${c.orange}; }
        #battery.critical { color: ${c.red}; }
      '';
    };
  };
}
