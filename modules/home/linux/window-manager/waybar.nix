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
          format = "<span weight='bold'></span> {:%a %d %b  %H:%M}";
          tooltip-format = "<big>{:%Y-%m-%d}</big>\n<tt>{calendar}</tt>";
        };

        battery = {
          format = "<span weight='bold'>{icon}</span> {capacity}%";
          format-icons = [ "󰂎" "󰁻" "󰁾" "󰂀" "󰂂" ];
          format-charging = "<span weight='bold'>󰂄</span> {capacity}%";
          states = { warning = 30; critical = 15; };
        };

        network = {
          format-wifi = "<span weight='bold'>󰤨</span> {essid} ({signalStrength}%)";
          format-ethernet = "<span weight='bold'>󰈀</span> {ifname}";
          format-disconnected = "<span weight='bold'>󰌙</span> disconnected";
          tooltip-format = "{ifname}: {ipaddr}/{cidr}";
          on-click = "${pkgs.ghostty}/bin/ghostty --command=nmtui";
        };

        pulseaudio = {
          format = "<span weight='bold'>{icon}</span> {volume}%";
          format-muted = "<span weight='bold'>󰖁</span> muted";
          format-icons = { default = [ "󰕿" "󰖀" "󰕾" ]; };
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

        #workspaces {
          margin: 4px 6px;
        }
        #workspaces button {
          padding: 0;
          margin: 2px 4px;
          font-weight: bold;
          color: alpha(${c.fg}, 0.53);
          background: alpha(${c.blue}, 0.2);
          border-radius: 6px;
        }
        #workspaces button.focused {
          color: ${c.black};
          background: ${c.purple};
        }
        #workspaces button.urgent {
          color: ${c.fg};
          background: ${c.red};
        }

        #clock, #battery, #network, #pulseaudio, #tray, #mode {
          padding: 0 10px;
          color: ${c.fg};
        }

        #network:hover, #pulseaudio:hover {
          background: ${c.bg_highlight};
          border-radius: 6px;
        }

        #battery.warning  { color: ${c.orange}; }
        #battery.critical { color: ${c.red}; }
      '';
    };
  };
}
