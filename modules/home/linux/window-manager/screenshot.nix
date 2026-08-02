{ config, lib, pkgs, ... }:
#
# Screenshots — grim (capture) + slurp (region select) + swappy (annotate).
# Sway-native via wlr-screencopy; spectacle/flameshot don't target wlroots
# compositors well.
#
# Available options:
# - home.apps.windowManager.screenshot.enable
#
let
  cfg = config.home.apps.windowManager.screenshot;
in
{
  options.home.apps.windowManager.screenshot.enable =
    lib.mkEnableOption "grim/slurp/swappy screenshot tooling";

  config = lib.mkIf cfg.enable {
    home.packages = [
      # Region select, opens swappy for annotate/save/copy.
      (pkgs.writeShellScriptBin "screenshot-region" ''
        exec ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" - | ${pkgs.swappy}/bin/swappy -f -
      '')
      # Full screen, saved straight to disk + clipboard, no editor.
      (pkgs.writeShellScriptBin "screenshot-full" ''
        set -euo pipefail
        dir="$HOME/Pictures/Screenshots"
        mkdir -p "$dir"
        f="$dir/screenshot-$(date +%Y%m%d-%H%M%S).png"
        ${pkgs.grim}/bin/grim "$f"
        ${pkgs.wl-clipboard}/bin/wl-copy < "$f"
        ${pkgs.libnotify}/bin/notify-send "Screenshot saved" "$f"
      '')
    ];

    xdg.configFile."swappy/config".text = ''
      [Default]
      save_dir=$HOME/Pictures/Screenshots
      save_filename_format=screenshot-%Y%m%d-%H%M%S.png
      show_panel=false
      line_size=5
      text_size=20
      text_font=JetBrainsMonoNL Nerd Font
      paint_mode=brush
      early_exit=true
      fill_shape=false
    '';
  };
}
