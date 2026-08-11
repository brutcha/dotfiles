{ config, lib, pkgs, inputs, ... }:
#
# Spotify (official Electron client) themed via spicetify-nix, plus a
# native-Wayland tray icon.
#
# Available options:
# - home.apps.media.spotify.enable
#
# spotify-tray-wayland gives a StatusNotifierItem tray icon for waybar.
# Upstream's click-to-hide/show is Hyprland-only; built here via
# `.override { windowManager = "sway"; }` for a swaymsg backend instead.
#
# spotify-tray-watch starts/stops the tray with the Spotify window's Sway
# lifecycle (not any particular launch path) so it survives Quit-then-
# relaunch regardless of how Spotify comes back. Moving to the scratchpad
# doesn't fire a close event, only an actual quit/crash does.
#
# Sway-only bits (toggle/tray/watcher) need Sway; the tray additionally
# needs somewhere to render (waybar, gated separately).
#
let
  cfg = config.home.apps.media.spotify;
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  swayEnabled = config.wayland.windowManager.sway.enable;
  hasTrayHost = config.home.apps.windowManager.waybar.enable;
  swayTray = pkgs.spotify-tray-wayland.override { windowManager = "sway"; };
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.spicetify ];

  options.home.apps.media.spotify.enable =
    lib.mkEnableOption "Spotify (spicetify-themed) with Wayland tray";

  config = lib.mkIf cfg.enable {
    programs.spicetify = {
      enable = true;
      theme = spicePkgs.themes.tokyoNight;
      colorScheme = "Night";
      wayland = true;
    };

    home.packages = lib.optionals swayEnabled (
      [
        (pkgs.writeShellScriptBin "spotify-toggle" ''
          has_spotify() {
            swaymsg -t get_tree | grep -q '"app_id": "spotify"'
          }
          if has_spotify; then
            swaymsg '[app_id="spotify"] scratchpad show'
          else
            spotify &
            for _ in $(seq 1 50); do
              has_spotify && break
              sleep 0.2
            done
            sleep 0.5
            swaymsg '[app_id="spotify"] scratchpad show'
          fi
        '')
      ]
      ++ lib.optionals hasTrayHost [ swayTray ]
    );

    wayland.windowManager.sway.config = lib.mkIf swayEnabled {
      window.commands = [
        { command = "move to scratchpad, floating enable"; criteria = { app_id = "spotify"; }; }
      ];
      keybindings = {
        "${config.wayland.windowManager.sway.config.modifier}+s" = "exec spotify-toggle";
      };
    };

    systemd.user.services = lib.mkIf (swayEnabled && hasTrayHost) {
      spotify-tray-wayland = {
        Unit.Description = "Spotify Wayland tray icon";
        Service = {
          Type = "simple";
          ExecStart = "${swayTray}/bin/spotify-tray-wayland";
          Restart = "on-failure";
        };
        # No Install/WantedBy — spotify-tray-watch owns its lifecycle.
      };

      # Note the space in "change": "new" — matches swaymsg's actual output.
      spotify-tray-watch = {
        Unit.Description = "Start/stop the Spotify tray icon with the Spotify window's lifecycle";
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.writeShellScript "spotify-tray-watch" ''
            ${config.wayland.windowManager.sway.package}/bin/swaymsg --raw -t subscribe -m '["window"]' |
            while IFS= read -r event; do
              case "$event" in
                *'"change": "new"'*)
                  printf '%s' "$event" | grep -q '"app_id": "spotify"' &&
                    systemctl --user start spotify-tray-wayland.service
                  ;;
                *'"change": "close"'*)
                  printf '%s' "$event" | grep -q '"app_id": "spotify"' &&
                    systemctl --user stop spotify-tray-wayland.service
                  ;;
              esac
            done
          ''}";
          Restart = "always";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
