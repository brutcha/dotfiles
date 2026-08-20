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

  menuLib = pkgs.python3Packages.buildPythonPackage {
    pname = "menu-common";
    version = "0";
    format = "other";
    dontUnpack = true;
    installPhase = ''
      install -Dm644 ${./scripts/menu_common.py} $out/${pkgs.python3.sitePackages}/menu_common.py
    '';
  };
  # flake8 runs at build time; waive line length + a style rule flake8 itself defaults off.
  menuScript = name: pkgs.writers.writePython3Bin "${name}-menu" {
    libraries = [ menuLib ];
    flakeIgnore = [ "E501" "W503" ];
  } (builtins.readFile ./scripts/${name}-menu.py);
in
{
  options.home.apps.windowManager.waybar.enable =
    lib.mkEnableOption "Waybar status bar for Sway";

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.networkmanager_dmenu
      (menuScript "audio")
      (menuScript "layout")
      (menuScript "network")
      (menuScript "power")
    ];

    home.file.".config/networkmanager-dmenu/config.ini".text = ''
      [dmenu]
      dmenu_command = fuzzel --dmenu --anchor=top-right -p "Network: "
      wifi_icons = 󰤯󰤟󰤢󰤥󰤨
      format = {name} {icon}
      [dmenu_passphrase]
      obscure = True
    '';

    programs.waybar = {
      enable = true;
      systemd.enable = true;

      settings.mainBar = {
        layer = "top";
        position = "top";
        height = 28;
        spacing = 6;
        modules-left = [ "sway/workspaces" "sway/mode" ];
        modules-center = [ "clock" ];
        modules-right = [ "tray" "sway/language" "pulseaudio" "network" "battery" ];

        "sway/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          persistent-workspaces = {
            "1" = [ ];
            "2" = [ ];
            "3" = [ ];
            "4" = [ ];
            "5" = [ ];
          };
        };

        "sway/language" = {
          format = "<span weight='bold'>󰌌</span> {short}";
          on-click = "layout-menu";
        };

        tray = { spacing = 10; };

        clock = {
          format = "<span weight='bold'></span> {:%a %d %b  %H:%M}";
          tooltip-format = "<tt>{calendar}</tt>";
          calendar = {
            mode = "month";
            on-scroll = 1;
            format = {
              months = "<span color='${c.blue}'><b>{}</b></span>";
              days = "<span color='${c.fg}'>{}</span>";
              weekdays = "<span color='${c.blue}'><b>{}</b></span>";
              today = "<span color='${c.purple}'><b>{}</b></span>";
            };
          };
          actions = {
            on-click-right = "mode";
            on-scroll-up = "shift_up";
            on-scroll-down = "shift_down";
          };
        };

        battery = {
          format = "<span weight='bold'>{icon}</span> {capacity}%";
          format-icons = [ "󰂎" "󰁻" "󰁾" "󰂀" "󰂂" ];
          format-charging = "<span weight='bold'>󰂄</span> {capacity}%";
          states = { warning = 30; critical = 15; };
          on-click = "power-menu";
        };

        network = {
          format-wifi = "<span weight='bold'>{icon}</span> {essid} ({signalStrength}%)";
          format-icons = [ "󰤯" "󰤟" "󰤢" "󰤥" "󰤨" ];
          format-ethernet = "<span weight='bold'>󰈀</span> {ifname}";
          format-disconnected = "<span weight='bold'>󰌙</span> disconnected";
          tooltip-format = "{ifname}: {ipaddr}/{cidr}";
          tooltip-format-wifi = "{essid} ({frequency} GHz) — {ipaddr}";
          on-click = "network-menu";
        };

        pulseaudio = {
          format = "<span weight='bold'>{icon}</span> {volume}%";
          format-muted = "<span weight='bold'>󰖁</span> muted";
          format-icons = { default = [ "󰕿" "󰖀" "󰕾" ]; };
          scroll-step = 5;
          on-click = "audio-menu";
          # pavucontrol is plain GTK4; pwvucontrol pulls in libadwaita, which
          # ignores the Tokyonight theme.
          on-click-right = "${pkgs.pavucontrol}/bin/pavucontrol";
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
        #workspaces button.empty {
          color: alpha(${c.fg}, 0.3);
          background: ${c.bg_dark};
        }
        #workspaces button.focused {
          color: ${c.black};
          background: ${c.purple};
        }
        #workspaces button.urgent {
          color: ${c.fg};
          background: ${c.red};
        }

        #clock, #battery, #network, #pulseaudio, #tray, #mode, #language {
          padding: 0 6px;
          color: ${c.fg};
        }
        #battery {
          margin-right: 6px;
        }

        #network:hover, #pulseaudio:hover, #language:hover, #battery:hover {
          background: ${c.bg_highlight};
          border-radius: 6px;
        }

        #battery.warning  { color: ${c.orange}; }
        #battery.critical { color: ${c.red}; }

      '';
    };

    # sway/language builds its layout map at startup, starting before
    # sway has applied xkb_layout.
    systemd.user.services.waybar.Service.ExecStartPre =
      "${pkgs.writeShellScript "wait-xkb-layouts" ''
        for _ in {1..50}; do
          swaymsg -t get_inputs -r 2>/dev/null \
            | ${pkgs.jq}/bin/jq -e '[.[]|select(.type=="keyboard")|(.xkb_layout_names|length)]|max >= 2' >/dev/null \
            && exit 0
          sleep 0.1
        done
        exit 0 # never block the bar on a failed probe
      ''}";
  };
}
