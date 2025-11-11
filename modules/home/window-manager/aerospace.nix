#{ config, lib, ... }:

# AeroSpace: tiling window manager for macOS
# https://nikitabobko.github.io/AeroSpace/guide.html
# https://nix-community.github.io/home-manager/options.xhtml#opt-programs.aerospace.enable
{
  programs.aerospace = {
    enable = true;
    launchd.enable = true;

    userSettings = {
      # Start AeroSpace at login
      start-at-login = true;

      # Run Sketchybar together with AeroSpace
      # sketchybar has built-in detection of already running process,
      # so it won't be run twice on AeroSpace restart
      after-startup-command = [
        "exec-and-forget sketchybar"
      ];

      # Notify Sketchybar about workspace change
      exec-on-workspace-change = [
        "/bin/bash"
        "-c"
        "sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE"
      ];

      # Normalizations
      # See: https://nikitabobko.github.io/AeroSpace/guide#normalization
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      # Possible values: tiles|accordion
      default-root-container-layout = "tiles";

      # Gaps between windows (inner-*) and between monitor edges (outer-*)
      # Possible values:
      # - Constant:     gaps.outer.top = 8
      # - Per monitor:  gaps.outer.top = [{ monitor.main = 16 }, { monitor."some-pattern" = 32 }, 24]
      #                 In this example, 24 is a default value when there is no match.
      #                 Monitor pattern is the same as for 'workspace-to-monitor-force-assignment'.
      # See: https://nikitabobko.github.io/AeroSpace/guide#assign-workspaces-to-monitors
      gaps = {
        inner = {
          horizontal = 8;
          vertical = 8;
        };
        outer = {
          left = 8;
          bottom = 8;
          top = [
            { monitor."^built-in retina display$" = 0; }
            { monitor.main = 40; }
            8
          ];
          right = 8;
        };
      };

      # 'main' binding mode declaration
      # See: https://nikitabobko.github.io/AeroSpace/guide#binding-modes
      # 'main' binding mode must be always presented
      mode.main.binding = {
        # All possible keys:
        # - Letters.        a, b, c, ..., z
        # - Numbers.        0, 1, 2, ..., 9
        # - Keypad numbers. keypad0, keypad1, keypad2, ..., keypad9
        # - F-keys.         f1, f2, ..., f20
        # - Special keys.   minus, equal, period, comma, slash, backslash, quote, semicolon, backtick,
        #                   leftSquareBracket, rightSquareBracket, space, enter, esc, backspace, tab
        # - Keypad special. keypadClear, keypadDecimalMark, keypadDivide, keypadEnter, keypadEqual,
        #                   keypadMinus, keypadMultiply, keypadPlus
        # - Arrows.         left, down, up, right

        # All possible modifiers: cmd, alt, ctrl, shift

        # All possible commands: https://nikitabobko.github.io/AeroSpace/commands

        # See: https://nikitabobko.github.io/AeroSpace/commands#close
        alt-w = "close --quit-if-last-window";

        # See: https://nikitabobko.github.io/AeroSpace/commands#exec-and-forget
        alt-f = "fullscreen --no-outer-gaps";

        # See: https://nikitabobko.github.io/AeroSpace/commands#layout
        alt-space = "layout tiles horizontal vertical";
        ctrl-down = "layout tiles accordion";
        alt-shift-space = "layout floating tiling"; # 'floating toggle' in i3

        # See: https://nikitabobko.github.io/AeroSpace/commands#focus
        alt-h = "focus left";
        alt-j = "focus down";
        alt-k = "focus up";
        alt-l = "focus right";

        # See: https://nikitabobko.github.io/AeroSpace/commands#move
        alt-ctrl-h = "move left";
        alt-ctrl-j = "move down";
        alt-ctrl-k = "move up";
        alt-ctrl-l = "move right";

        # See: https://nikitabobko.github.io/AeroSpace/commands#exec-and-forget
        alt-shift-h = "join-with left";
        alt-shift-j = "join-with down";
        alt-shift-k = "join-with up";
        alt-shift-l = "join-with right";

        # See: https://nikitabobko.github.io/AeroSpace/commands#workspace
        ctrl-right = "workspace --wrap-around next";
        ctrl-left = "workspace --wrap-around prev";
        alt-1 = "workspace 1";
        alt-2 = "workspace 2";
        alt-3 = "workspace 3";
        alt-4 = "workspace 4";
        alt-5 = "workspace 5";

        # See: https://nikitabobko.github.io/AeroSpace/commands#move-node-to-workspace
        alt-ctrl-right = "move-node-to-workspace --wrap-around next";
        alt-ctrl-left = "move-node-to-workspace --wrap-around prev";
        alt-ctrl-1 = "move-node-to-workspace 1";
        alt-ctrl-2 = "move-node-to-workspace 2";
        alt-ctrl-3 = "move-node-to-workspace 3";
        alt-ctrl-4 = "move-node-to-workspace 4";
        alt-ctrl-5 = "move-node-to-workspace 5";

        # Application launchers (mnemonic-based)
        ctrl-alt-w = "exec-and-forget open -a 'Zen Browser'"; # W = Web
        ctrl-alt-a = "exec-and-forget open -a 'Claude'"; # A = AI
        ctrl-alt-t = "exec-and-forget open -a 'Ghostty'"; # T = Terminal
        ctrl-alt-e = "exec-and-forget open -a 'Windsurf'"; # E = Editor
        ctrl-alt-c = "exec-and-forget open -a 'Discord'"; # C = Chat (Discord)
        ctrl-alt-shift-c = "exec-and-forget open -a 'Telegram'"; # C = Chat (Telegram)
        cmd-ctrl-alt-shift-c = "exec-and-forget open -a 'Slack'"; # C = Chat (Slack - Hyper)

        # Quick terminal launcher
        cmd-enter = "exec-and-forget open -na 'Ghostty'";

        # Lock the Mac
        cmd-alt-l = "exec-and-forget osascript -e 'tell application \"System Events\" to keystroke \"q\" using {control down, command down}'";

        # See: https://nikitabobko.github.io/AeroSpace/commands#mode
        alt-r = "mode resize";
      };

      # See: https://nikitabobko.github.io/AeroSpace/guide#binding-modes
      mode.resize.binding = {
        h = "resize width -50";
        j = "resize height +50";
        k = "resize height -50";
        l = "resize width +50";
        enter = "mode main";
        esc = "mode main";
      };

      # See:https://nikitabobko.github.io/AeroSpace/guide#assign-workspaces-to-monitors
      workspace-to-monitor-force-assignment = {
        "1" = [ "main" "M14t" "^built-in retina display$" ];
        "2" = [ "main" "M14t" "^built-in retina display$" ];
        "3" = [ "main" "M14t" "^built-in retina display$" ];
        "4" = [ "main" "M14t" "^built-in retina display$" ];
        "5" = [ "M14t" "^built-in retina display$" "main" ];
      };

      # See:https://nikitabobko.github.io/AeroSpace/guide#on-window-detected-callback
      # Workspace 1: Development browsers + API testing
      # TODO check if application is installed before adding it into a config, once i have migrate all these apps to nix
      on-window-detected = [
        { "if"."app-id" = "org.mozilla.firefoxdeveloperedition"; run = "move-node-to-workspace 1"; }
        { "if"."app-id" = "com.microsoft.edgemac"; run = "move-node-to-workspace 1"; }
        { "if"."app-id" = "org.chromium.Chromium"; run = "move-node-to-workspace 1"; }
        { "if"."app-id" = "com.postmanlabs.mac"; run = "move-node-to-workspace 1"; }

        # Workspace 2: Personal browsing + Design + Media
        { "if"."app-id" = "com.figma.Desktop"; run = "move-node-to-workspace 2"; }
        { "if"."app-id" = "app.zen-browser.zen"; run = "move-node-to-workspace 2"; }
        { "if"."app-id" = "com.spotify.client"; run = "move-node-to-workspace 2"; }
        { "if"."app-id" = "com.obsproject.obs-studio"; run = "move-node-to-workspace 2"; }

        # Workspace 3: Communication
        { "if"."app-id" = "com.tinyspeck.slackmacgap"; run = "move-node-to-workspace 3"; }
        { "if"."app-id" = "com.mozilla.thunderbird"; run = "move-node-to-workspace 3"; }
        { "if"."app-id" = "com.hnc.Discord"; run = "move-node-to-workspace 3"; }
        { "if"."app-id" = "ru.keepcoder.Telegram"; run = "move-node-to-workspace 3"; }

        # Workspace 4: Terminal + AI assistance
        { "if"."app-id" = "com.mitchellh.ghostty"; run = "move-node-to-workspace 4"; }
        { "if"."app-id" = "com.anthropic.claudefordesktop"; run = "move-node-to-workspace 4"; }

        # Workspace 5: Code editors
        { "if"."app-id" = "com.exafunction.windsurf"; run = "move-node-to-workspace 5"; }
        { "if"."app-id" = "com.vscodium"; run = "move-node-to-workspace 5"; }
      ];
    };
  };
}
