{ config, lib, pkgs, inputs, ... }:
#
# Spotify (official Electron client) themed via spicetify-nix, plus a
# native-Wayland tray icon.
#
# Available options:
# - home.apps.media.spotify.enable
#
# spotify-tray-wayland (pkgs/spotify-tray-wayland) gives a proper
# StatusNotifierItem tray icon that registers with waybar's `tray` module,
# but its click-to-hide/show is implemented via Hyprland's IPC and does
# nothing on Sway — hide/show here is a Sway-native scratchpad keybind
# instead ($mod+s), independent of the tray icon's own window handling.
#
let
  cfg = config.home.apps.media.spotify;
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
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

    home.packages = [
      pkgs.spotify-tray-wayland

      (pkgs.writeShellScriptBin "spotify-toggle" ''
        has_spotify() {
          swaymsg -t get_tree | grep -q '"app_id": "spotify"'
        }
        if has_spotify; then
          swaymsg scratchpad show
        else
          spotify &
          for _ in $(seq 1 50); do
            has_spotify && break
            sleep 0.2
          done
          sleep 0.5
          swaymsg scratchpad show
        fi
      '')
    ];

    wayland.windowManager.sway.config = {
      window.commands = [
        { command = "move to scratchpad, floating enable"; criteria = { app_id = "spotify"; }; }
      ];
      keybindings = {
        "${config.wayland.windowManager.sway.config.modifier}+s" = "exec spotify-toggle";
      };
    };
  };
}
