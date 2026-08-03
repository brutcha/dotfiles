{ config, lib, pkgs, ... }:
#
# Sway (https://swaywm.org) — wlroots-based tiling Wayland compositor.
#
# Available options:
# - home.apps.windowManager.sway.enable
#
# System-level `programs.sway.enable` in the host installs the compositor
# system-wide; this module owns user config (bindings, output, input,
# startup, idle chain, colors).
#
# grp:caps_toggle binds Capslock at the xkb layer to cycle us↔cz — no app
# can bind it and Capslock loses its latch function.
#
let
  cfg = config.home.apps.windowManager.sway;
in
{
  options.home.apps.windowManager.sway.enable =
    lib.mkEnableOption "Sway window manager (user-level config)";

  config = lib.mkIf cfg.enable {
    # Power-aware swayidle stages — swayidle itself has no AC/battery
    # awareness, so each stage checks power state at fire time via
    # /sys/class/power_supply/AC/online (this machine's actual AC device).
    home.packages = [
      (pkgs.writeShellScriptBin "on-ac" ''
        [ "$(cat /sys/class/power_supply/AC/online)" = "1" ]
      '')
      # 3min: dim on battery only (AC's dim is deferred to stage 2).
      (pkgs.writeShellScriptBin "idle-stage1" ''
        on-ac || brightnessctl -s set 20%
      '')
      # 5min: dim on AC, screen off on battery.
      (pkgs.writeShellScriptBin "idle-stage2" ''
        if on-ac; then
          brightnessctl -s set 20%
        else
          swaymsg 'output * dpms off'
        fi
      '')
      # 10min: screen off on AC, RAM-suspend on battery.
      (pkgs.writeShellScriptBin "idle-stage3" ''
        if on-ac; then
          swaymsg 'output * dpms off'
        else
          systemctl suspend
        fi
      '')
      # 20min: suspend-then-hibernate on AC (auto-hibernates ~30min later
      # if left unplugged and unresumed), explicit hibernate on battery.
      (pkgs.writeShellScriptBin "idle-stage4" ''
        if on-ac; then
          systemctl suspend-then-hibernate
        else
          systemctl hibernate
        fi
      '')
    ];

    home.pointerCursor = {
      enable = true;
      package = pkgs.capitaine-cursors;
      name = "capitaine-cursors";
      size = 24;
      gtk.enable = true;
      x11.enable = true;
      sway.enable = true;
    };

    wayland.windowManager.sway = {
      enable = true;
      wrapperFeatures.gtk = true;

      config = rec {
        modifier = "Mod4";
        terminal = "ghostty";
        menu = "fuzzel";
        bars = [ ];

        window.titlebar = false;
        floating.titlebar = false;
        gaps.smartBorders = "on";

        output."eDP-1" = {
          mode = "3840x2400@60Hz";
          scale = "2";
        };

        input."type:keyboard" = {
          xkb_layout = "us,cz";
          xkb_variant = "altgr-intl,";
          xkb_options = "grp:caps_toggle";
        };
        input."type:touchpad" = {
          tap = "enabled";
          natural_scroll = "enabled";
        };

        keybindings = let mod = modifier; in {
          "${mod}+Return" = "exec ${terminal}";
          "${mod}+space" = "exec ${menu}";
          "${mod}+w" = "kill";
          "${mod}+Shift+e" = "exit";

          "${mod}+h" = "focus left";
          "${mod}+j" = "focus down";
          "${mod}+k" = "focus up";
          "${mod}+l" = "focus right";

          "${mod}+Ctrl+h" = "move left";
          "${mod}+Ctrl+j" = "move down";
          "${mod}+Ctrl+k" = "move up";
          "${mod}+Ctrl+l" = "move right";

          "${mod}+1" = "workspace number 1";
          "${mod}+2" = "workspace number 2";
          "${mod}+3" = "workspace number 3";
          "${mod}+4" = "workspace number 4";
          "${mod}+5" = "workspace number 5";

          "${mod}+Ctrl+1" = "move container to workspace number 1";
          "${mod}+Ctrl+2" = "move container to workspace number 2";
          "${mod}+Ctrl+3" = "move container to workspace number 3";
          "${mod}+Ctrl+4" = "move container to workspace number 4";
          "${mod}+Ctrl+5" = "move container to workspace number 5";

          "${mod}+e" = "layout toggle split";
          "${mod}+f" = "fullscreen";
          "${mod}+Shift+space" = "floating toggle";

          "XF86MonBrightnessUp" = "exec brightnessctl set +5%";
          "XF86MonBrightnessDown" = "exec brightnessctl set 5%-";
          "XF86AudioRaiseVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
          "XF86AudioLowerVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
          "XF86AudioMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";

          "Print" = "exec screenshot-region";
          "Shift+Print" = "exec screenshot-full";
        };

        # Polkit auth agent — the system-level `security.polkit.enable`
        # counterpart lives in the host default.nix.
        startup = [
          { command = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"; }
        ];

        colors = let c = config.theme.dark; in {
          focused = { border = c.blue; background = c.bg; text = c.fg; indicator = c.blue; childBorder = c.blue; };
          focusedInactive = { border = c.bg_dark; background = c.bg; text = c.fg_dark; indicator = c.bg_dark; childBorder = c.bg_dark; };
          unfocused = { border = c.bg_dark; background = c.bg; text = c.comment; indicator = c.bg_dark; childBorder = c.bg_dark; };
          urgent = { border = c.red; background = c.red; text = c.fg; indicator = c.red; childBorder = c.red; };
        };

        fonts = {
          names = [ "JetBrainsMonoNL Nerd Font" ];
          size = 10.0;
        };
      };

      extraConfig = ''
        seat seat0 xcursor_theme capitaine-cursors 24

        exec swayidle -w \
          timeout 180 idle-stage1 resume 'brightnessctl -r' \
          timeout 300 idle-stage2 resume 'swaymsg "output * dpms on"; brightnessctl -r' \
          timeout 600 idle-stage3 resume 'swaymsg "output * dpms on"' \
          timeout 1200 idle-stage4
      '';
    };
  };
}
