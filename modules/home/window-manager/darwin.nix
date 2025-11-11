{ pkgs, config, ... }:

# macOS window manager configuration
#
# This module configures:
# - AeroSpace: tiling window manager for macOS
# - JankyBorders: customizable window borders
# - SketchyBar: status bar replacement integrated with AeroSpace
# - Tokyo Night theme: color palette for SketchyBar
#
# ============================================================================
# SKETCHYBAR LUA MIGRATION PLAN
# ============================================================================
#
# OVERVIEW:
# Migrating from inline bash scripts to external Lua files using SbarLua
# for better development experience (LSP, syntax highlighting, refactoring)
#
# DIRECTORY STRUCTURE (to create in config/sketchybar/):
# config/sketchybar/
# ├── init.lua                    # Main entry point (required)
# ├── bar.lua                     # Bar appearance
# ├── colors.lua                  # Tokyo Night theme colors
# ├── icons.lua                   # Icon mappings
# ├── default.lua                 # Default item properties
# ├── items/
# │   ├── spaces.lua             # Aerospace workspaces (PHASE 2 - CRITICAL)
# │   ├── lock.lua               # Lock icon (PHASE 1)
# │   ├── front_app.lua          # Front app indicator (PHASE 2)
# │   ├── clock.lua              # Clock (PHASE 1)
# │   ├── battery.lua            # Battery monitor (PHASE 3)
# │   ├── network.lua            # Network monitor (PHASE 3)
# │   ├── ram.lua                # RAM monitor (PHASE 3)
# │   ├── volume.lua             # Volume control (PHASE 3)
# │   └── conditional.lua        # Conditional items manager (PHASE 4)
# └── helpers/
#     └── conditional_items_legacy.lua  # Old watcher (remove in Phase 4)
#
# MIGRATION PHASES:
#
# PHASE 1: Foundation Setup
# - Change configType from "bash" to "lua"
# - Add sbarlua to extraPackages
# - Change config from inline string to { source = ...; recursive = true; }
# - Create init.lua, bar.lua, colors.lua (Tokyo Night), icons.lua, default.lua
# - Convert lock.lua and clock.lua (simplest items)
# - Test: sketchybar --reload
# - Expected: Bar appears with lock (left) and clock (right), both clickable
#
# PHASE 2: Aerospace Integration (CRITICAL - Your Priority)
# - Convert spaces.lua (workspace indicators)
#   * Loop through aerospace workspaces
#   * Subscribe to aerospace_workspace_change
#   * Color highlighting (focused/visible/inactive)
#   * Click handlers to switch workspaces
# - Convert front_app.lua
# - Test: Workspace switching, color changes, front_app shows/hides
# - Expected: Full aerospace functionality maintained
#
# PHASE 3: System Monitors
# - Convert battery.lua (pmset system calls, icon logic)
# - Convert network.lua (caching, WiFi signal)
# - Convert ram.lua (vm_stat parsing)
# - Convert volume.lua (animations, scroll handling)
# - Test: Each monitor individually
# - Expected: All system monitors working, click/scroll handlers preserved
#
# PHASE 4: Conditional Items Integration
# - Move conditional logic into items/conditional.lua
# - Use invisible timer item (update_freq=5) for periodic checks
# - Remove separate LaunchAgent
# - Integrate docker, insync, elgato, protonmail, watchman checks
# - Test: Items appear/disappear when apps start/stop
# - Expected: Dynamic items without separate daemon
#
# BENEFITS OF MIGRATION:
# - Full Lua LSP support in Neovim
# - Syntax highlighting and error detection
# - Better refactoring and code navigation
# - Git diffs show actual changes (not nix string escaping)
# - Async execution with sbar.exec() (non-blocking)
# - Native animation support
# - Query returns Lua tables (easy parsing)
# - Consistent Tokyo Night theme across bar and Neovim
#
# TOKYO NIGHT COLOR INTEGRATION:
# colors.lua will import from tokyonight.nvim palette:
# - bg: #1a1b26 (background)
# - fg: #c0caf5 (foreground)
# - blue: #7aa2f7
# - purple: #bb9af7
# - red: #f7768e
# - green: #9ece6a
# - yellow: #e0af68
# - cyan: #7dcfff
# - magenta: #bb9af7
#
# TESTING COMMANDS:
# sudo darwin-rebuild switch --flake .#makima  # Apply changes
# sketchybar --reload                          # Reload bar
# sketchybar --query bar                       # Debug bar state
# sketchybar --query <item_name>              # Debug specific item
# tail -f /tmp/sketchybar-conditional-items.log  # Monitor conditional items
#
# ============================================================================

{
  programs = {
    # AeroSpace tiling window manager for macOS
    # https://nikitabobko.github.io/AeroSpace/guide.html
    # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.aerospace.enable
    aerospace = {
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
          "exec-and-forget borders active_color=0xff7aa2f7 inactive_color=0x007aa2f7 width=8.0"
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

    # SketchyBar - status bar replacement for macOS
    # https://felixkratz.github.io/SketchyBar/setup
    # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.sketchybar.enable
    #
    # TODO PHASE 1: Uncomment the Lua configuration below and comment out the bash config
    # sketchybar = {
    #   enable = true;
    #   configType = "lua";
    #   extraPackages = with pkgs; [
    #     jq
    #   ];
    #   config = {
    #     source = ../../config/sketchybar;
    #     recursive = true;
    #   };
    # };

    # CURRENT BASH CONFIGURATION (TO BE MIGRATED)
    sketchybar = {
      enable = true;

      # Configuration type (bash or lua)
      configType = "bash";

      # Extra packages available in PATH for plugins
      extraPackages = with pkgs; [
        jq
        # TODO PHASE 1: Add sbarlua here when switching to lua
      ];

      # Main configuration file
      config = ''
        # This is a demo config to showcase some of the most important commands.
        # It is meant to be changed and configured, as it is intentionally kept sparse.
        # For a (much) more advanced configuration example see my dotfiles:
        # https://github.com/FelixKratz/dotfiles

        # Ensure home-manager binaries are in PATH
        export PATH="${config.home.homeDirectory}/.nix-profile/bin:/etc/profiles/per-user/${config.home.username}/bin:$PATH"

        PLUGIN_DIR="$CONFIG_DIR/plugins"

        ##### Bar Appearance #####
        # Configuring the general appearance of the bar.
        # These are only some of the options available. For all options see:
        # https://felixkratz.github.io/SketchyBar/config/bar
        # If you are looking for other colors, see the color picker:
        # https://felixkratz.github.io/SketchyBar/config/tricks#color-picker

        sketchybar --bar position=top height=32 color=0xFF1A1B26 topomost=on display=main padding_left=12 padding_right=12

        ##### Changing Defaults #####
        # We now change some default values, which are applied to all further items.
        # For a full list of all available item properties see:
        # https://felixkratz.github.io/SketchyBar/config/items

        default=(
          padding_left=4
          padding_right=4
          icon.font="JetBrainsMonoNL Nerd Font:Bold:14.0"
          label.font="JetBrainsMonoNL Nerd Font:Normal:14.0"
          icon.color=0xffffffff
          label.color=0xffffffff
          icon.padding_left=4
          icon.padding_right=4
          label.padding_left=4
          label.padding_right=4
        )
        sketchybar --default "''${default[@]}"

        ##### Setup aerospace workspaces indicators #####
        # Let's add some aerospace workspaces:
        # https://felixkratz.github.io/SketchyBar/config/components#space----associate-mission-control-spaces-with-an-item
        sketchybar --add event aerospace_workspace_change

        # Add lock icon FIRST (leftmost position)
        sketchybar --add item lock left \
                   --set lock script="$PLUGIN_DIR/lock.sh" click_script="$PLUGIN_DIR/lock.sh"

        # Define workspace icon mapping
        declare -A WORKSPACE_ICONS
        WORKSPACE_ICONS[1]="1"
        WORKSPACE_ICONS[2]="2"
        WORKSPACE_ICONS[3]="3"
        WORKSPACE_ICONS[4]="4"
        WORKSPACE_ICONS[5]="5"
        WORKSPACE_ICONS[6]="6"
        WORKSPACE_ICONS[7]="7"
        WORKSPACE_ICONS[8]="8"
        WORKSPACE_ICONS[9]="9"
        WORKSPACE_ICONS[10]="10"

        for sid in $(aerospace list-workspaces --all)
        do
          # Get the icon for this workspace, default to workspace number if not mapped
          icon="''${WORKSPACE_ICONS[$sid]:-$sid}"

          # Get the monitor ID for this workspace (for multi-monitor support)
          workspace_info=$(aerospace list-workspaces --workspace $sid --format '%{workspace} %{monitor-id}')
          display_num=$(echo $workspace_info | awk '{print $2}')

          space=(
            space="$sid"
            icon="$icon"
            icon.padding_left=6
            icon.padding_right=6
            icon.font="JetBrainsMonoNL Nerd Font:Bold:12.0"
            background.color=0x447aa2f7
            background.corner_radius=6
            background.height=20
            background.border_width=0
            background.drawing=on
            label.drawing=off
            script="$CONFIG_DIR/plugins/aerospace.sh $sid"
            click_script="aerospace workspace $sid"
            associated_display=0
            ignore_association=on
          )
          sketchybar --add item space.$sid left \
                     --set space.$sid "''${space[@]}" \
                     --subscribe space.$sid aerospace_workspace_change
        done

        ##### Adding Left Items #####
        # We add some regular items to the left side of the bar, where
        # only the properties deviating from the current defaults need to be set


        sketchybar --set chevron icon= label.drawing=off \
                   --add item front_app left \
                   --set front_app icon.drawing=off padding_left=8 script="$PLUGIN_DIR/front_app.sh" \
                   --subscribe front_app front_app_switched \
                   --subscribe front_app aerospace_workspace_change

        ##### Adding Right Items #####
        # In the same way as the left items we can add items to the right side.
        # Additional position (e.g. center) are available, see:
        # https://felixkratz.github.io/SketchyBar/config/items#adding-items-to-sketchybar

        # Some items refresh on a fixed cycle, e.g. the clock runs its script once
        # every 10s. Other items respond to events they subscribe to, e.g. the
        # volume.sh script is only executed once an actual change in system audio
        # volume is registered. More info about the event system can be found here:
        # https://felixkratz.github.io/SketchyBar/config/events

        sketchybar --add item clock right \
                   --set clock update_freq=10 icon=  script="$PLUGIN_DIR/clock.sh" click_script="$PLUGIN_DIR/clock.sh" \
                   --add item volume right \
                   --set volume script="$PLUGIN_DIR/volume.sh" \
                   --subscribe volume volume_change mouse.scrolled mouse.clicked \
                   --add item battery right \
                   --set battery update_freq=120 script="$PLUGIN_DIR/battery.sh" click_script="$PLUGIN_DIR/battery.sh" \
                   --subscribe battery system_woke power_source_change \
                   --add item network right \
                   --set network update_freq=5 script="$PLUGIN_DIR/network.sh" click_script="$PLUGIN_DIR/network.sh" \
                   --add item ram right \
                   --set ram update_freq=5 script="$PLUGIN_DIR/ram.sh" click_script="$PLUGIN_DIR/ram.sh"

        ##### Force all scripts to run the first time (never do this in a script) #####
        sketchybar --update

        ##### Update the currently focused workspace after reload #####
        FOCUSED_WORKSPACE=$(aerospace list-workspaces --focused)
        if [ ! -z "$FOCUSED_WORKSPACE" ]; then
          # Small delay to ensure all items are loaded, then trigger update
          (sleep 0.1 && sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE="$FOCUSED_WORKSPACE") &
        fi
      '';
    };
  };

  # JankyBorders - customizable window borders for macOS
  # https://github.com/FelixKratz/JankyBorders/wiki/Man-Page
  # https://nix-community.github.io/home-manager/options.xhtml#opt-services.jankyborders.enable
  services.jankyborders = {
    enable = true;
    settings = {
      active_color = "0xff7aa2f7";
      inactive_color = "0x007aa2f7";
      width = 8.0;
    };
  };

  # LaunchAgent to run conditional items watcher
  # TODO PHASE 4: Disable this when conditional items are integrated into main config
  launchd.agents.sketchybar-conditional-items = {
    enable = true;
    config = {
      ProgramArguments = [ "${pkgs.lua}/bin/lua" "${config.home.homeDirectory}/.config/sketchybar/conditional_items.lua" ];
      StartInterval = 5;
      RunAtLoad = true;
      StandardOutPath = "/tmp/sketchybar-conditional-items.log";
      StandardErrorPath = "/tmp/sketchybar-conditional-items.err";
    };
  };

  # Install SketchyBar plugin scripts
  # TODO PHASE 1: Remove this entire xdg.configFile section when switching to Lua
  xdg.configFile = {
    "sketchybar/plugins/space.sh" = {
      executable = true;
      text = ''
        #!/bin/sh

        # The $SELECTED variable is available for space components and indicates if
        # the space invoking this script (with name: $NAME) is currently selected:
        # https://felixkratz.github.io/SketchyBar/config/components#space----associate-mission-control-spaces-with-an-item

        sketchybar --set "$NAME" background.drawing="$SELECTED"
      '';
    };

    "sketchybar/plugins/aerospace.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash

        # make sure it's executable with:
        # chmod +x ~/.config/sketchybar/plugins/aerospace.sh

        # Get all workspace info and find this workspace's visibility
        ALL_WORKSPACES=$(aerospace list-workspaces --all --format '%{workspace} %{workspace-is-visible} %{workspace-is-focused}')

        # Find the visibility status for workspace $1
        WORKSPACE_VISIBLE="false"
        FOCUSED_WORKSPACE_CHECK="false"

        while IFS=' ' read -r workspace visible focused; do
            if [ "$workspace" = "$1" ]; then
                WORKSPACE_VISIBLE="$visible"
                FOCUSED_WORKSPACE_CHECK="$focused"
                break
            fi
        done <<< "$ALL_WORKSPACES"

        if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
            # Fully active: cyan with dark text
            sketchybar --set $NAME background.drawing=on background.color=0xffbb99f7 background.border_width=0 icon.color=0xff1a1b26
        elif [ "$WORKSPACE_VISIBLE" = "true" ]; then
            # Semi-active: purple with dark text (visible but not focused)
            sketchybar --set $NAME background.drawing=on background.color=0x99bb99f7 background.border_width=0 icon.color=0xff1a1b26
        else
            # Inactive: light gray with blue text (not visible)
            sketchybar --set $NAME background.drawing=on background.color=0x337aa2f7 background.border_width=0 icon.color=0x88ffffff
        fi
      '';
    };

    "sketchybar/plugins/front_app.sh" = {
      executable = true;
      text = ''
        #!/bin/sh

        # Some events send additional information specific to the event in the $INFO
        # variable. E.g. the front_app_switched event sends the name of the newly
        # focused application in the $INFO variable:
        # https://felixkratz.github.io/SketchyBar/config/events#events-and-scripting

        if [ "$SENDER" = "front_app_switched" ]; then
          sketchybar --set "$NAME" label="$INFO"
        fi

        if [ "$SENDER" = "aerospace_workspace_change" ]; then
          if [ $(aerospace list-windows --workspace focused --count) = "0" ]; then
            sketchybar --set "$NAME" label=""
          fi
        fi
      '';
    };

    "sketchybar/plugins/cpu.sh" = {
      executable = true;
      text = ''
        #!/bin/sh

        # CPU usage plugin for SketchyBar
        # Using Nerd Font icon (cpu-64bit symbol)
        ICON="󰻠"

        # Get CPU usage percentage using top command
        # This averages all cores into a single percentage
        CPU_PERCENT=$(top -l 2 -n 0 -F -s 0 | grep "CPU usage" | tail -1 | awk '{print $3}' | sed 's/%//')

        # If CPU_PERCENT is empty or invalid, default to 0
        if [ -z "$CPU_PERCENT" ]; then
          CPU_PERCENT="0.0"
        fi

        # Format to integer for display
        CPU_INT=$(echo "$CPU_PERCENT" | awk '{printf "%.0f", $1}')

        sketchybar --set "$NAME" icon="$ICON" label="''${CPU_INT}%"

        if [ "$BUTTON" = "left" ]; then
          # Open btm (bottom) in a new Ghostty terminal window
          /Applications/Ghostty.app/Contents/MacOS/ghostty -e btm &
        fi
      '';
    };

    "sketchybar/plugins/ram.sh" = {
      executable = true;
      text = ''
        #!/bin/sh

        # RAM usage plugin for SketchyBar
        # Using Nerd Font icon (memory-module symbol)
        ICON="󰘚"

        # Get memory stats using vm_stat
        # Parse the output to calculate used memory percentage
        PAGE_SIZE=$(pagesize)
        STATS=$(vm_stat)

        PAGES_FREE=$(echo "$STATS" | grep "Pages free" | awk '{print $3}' | tr -d '.')
        PAGES_ACTIVE=$(echo "$STATS" | grep "Pages active" | awk '{print $3}' | tr -d '.')
        PAGES_INACTIVE=$(echo "$STATS" | grep "Pages inactive" | awk '{print $3}' | tr -d '.')
        PAGES_WIRED=$(echo "$STATS" | grep "Pages wired down" | awk '{print $4}' | tr -d '.')
        PAGES_COMPRESSED=$(echo "$STATS" | grep "Pages occupied by compressor" | awk '{print $5}' | tr -d '.')

        # Calculate memory in GB using proper byte conversion
        # Note: Active + Wired + Compressed = Actually used memory (inactive can be reclaimed)
        USED_BYTES=$(echo "$PAGES_ACTIVE $PAGES_WIRED $PAGES_COMPRESSED $PAGE_SIZE" | awk '{print ($1 + $2 + $3) * $4}')
        USED_MEM=$(echo "$USED_BYTES" | awk '{printf "%.1f", $1 / 1024 / 1024 / 1024}')
        TOTAL_MEM=$(sysctl -n hw.memsize | awk '{printf "%.0f", $1 / 1024 / 1024 / 1024}')

        # Calculate percentage
        # PERCENTAGE=$(echo "$USED_BYTES" $(sysctl -n hw.memsize) | awk '{printf "%.0f", ($1 / $2) * 100}')

        # sketchybar --set "$NAME" icon="$ICON" label="''${USED_MEM}GB (''${PERCENTAGE}%)"
        sketchybar --set "$NAME" icon="$ICON" label="''${USED_MEM}GB"

        if [ "$BUTTON" = "left" ]; then
          # Open btm (bottom) in a new Ghostty terminal window
          /Applications/Ghostty.app/Contents/MacOS/ghostty -e btm &
        fi
      '';
    };

    "sketchybar/plugins/network.sh" = {
      executable = true;
      text = ''
        #!/bin/sh

        # Network speed indicator for SketchyBar with signal strength icons

        # Cache files
        CACHE_FILE="/tmp/sketchybar_network_cache"
        SIGNAL_CACHE="/tmp/sketchybar_network_signal"
        SPEED_CACHE="/tmp/sketchybar_network_speed"

        # Check connection
        IP=$(ipconfig getifaddr en0 2>/dev/null)

        if [ -z "$IP" ]; then
          # Not connected
          ICON="󰌙"
          LABEL=""
          COLOR="0xffffffff"
          sketchybar --set "$NAME" icon="$ICON" label="$LABEL" icon.color="$COLOR"
          exit 0
        fi

        # Get WiFi signal for icon (cached, updated every 10 seconds)
        INTERFACE_TYPE=$(ipconfig getsummary en0 2>/dev/null | grep "InterfaceType" | awk '{print $3}')
        CURRENT_TIME=$(date +%s)

        if [ "$INTERFACE_TYPE" = "WiFi" ]; then
          # Check if we should update signal
          UPDATE_SIGNAL=1
          if [ -f "$SIGNAL_CACHE" ]; then
            LAST_UPDATE=$(cat "$SIGNAL_CACHE" | cut -d: -f2)
            if [ $((CURRENT_TIME - LAST_UPDATE)) -lt 10 ]; then
              UPDATE_SIGNAL=0
              SIGNAL=$(cat "$SIGNAL_CACHE" | cut -d: -f1)
            fi
          fi

          if [ "$UPDATE_SIGNAL" -eq 1 ]; then
            SIGNAL=$(system_profiler SPAirPortDataType 2>/dev/null | grep "Signal / Noise" | head -1 | awk '{print $4}' | tr -d '-')
            echo "''${SIGNAL}:''${CURRENT_TIME}" > "$SIGNAL_CACHE"
          fi

          # Set WiFi icon based on signal
          if [ -n "$SIGNAL" ] && [ "$SIGNAL" != "" ]; then
            if [ "$SIGNAL" -le 50 ]; then
              ICON="󰤨"
            elif [ "$SIGNAL" -le 60 ]; then
              ICON="󰤥"
            elif [ "$SIGNAL" -le 70 ]; then
              ICON="󰤢"
            else
              ICON="󰤟"
            fi
          else
            ICON="󰤨"
          fi
        else
          ICON="󰈀"
        fi

        # Calculate download speed
        CURRENT_STATS=$(netstat -ibn | grep -e "^en0" | head -1 | awk '{print $7":"$10}')
        CURRENT_RX=$(echo "$CURRENT_STATS" | cut -d: -f1)

        if [ -f "$CACHE_FILE" ] && [ -f "$SPEED_CACHE" ]; then
          PREV_RX=$(cat "$CACHE_FILE" | cut -d: -f1)
          PREV_TIME=$(cat "$CACHE_FILE" | cut -d: -f2)

          TIME_DIFF=$((CURRENT_TIME - PREV_TIME))

          if [ "$TIME_DIFF" -ge 5 ]; then
            # Calculate new speed
            RX_SPEED=$(((CURRENT_RX - PREV_RX) / TIME_DIFF))

            if [ "$RX_SPEED" -gt 1048576 ]; then
              LABEL="$((RX_SPEED / 1048576))MB/s"
            elif [ "$RX_SPEED" -gt 1024 ]; then
              LABEL="$((RX_SPEED / 1024))KB/s"
            else
              LABEL="''${RX_SPEED}B/s"
            fi

            # Save new speed and update cache
            echo "$LABEL" > "$SPEED_CACHE"
            echo "''${CURRENT_RX}:''${CURRENT_TIME}" > "$CACHE_FILE"
          else
            # Use last known speed
            LABEL=$(cat "$SPEED_CACHE")
          fi
        else
          # First run
          echo "''${CURRENT_RX}:''${CURRENT_TIME}" > "$CACHE_FILE"
          echo "0KB/s" > "$SPEED_CACHE"
          LABEL="0KB/s"
        fi

        COLOR="0xffffffff"
        sketchybar --set "$NAME" icon="$ICON" label="$LABEL" icon.color="$COLOR"
      '';
    };

    "sketchybar/plugins/battery.sh" = {
      executable = true;
      text = ''
        #!/bin/sh

        PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
        CHARGING="$(pmset -g batt | grep 'AC Power')"

        if [ "$PERCENTAGE" = "" ]; then
          exit 0
        fi

        case "''${PERCENTAGE}" in
          9[0-9]|100) ICON="󰂂"
          ;;
          [6-8][0-9]) ICON="󰂀"
          ;;
          [3-5][0-9]) ICON="󰁾"
          ;;
          [1-2][0-9]) ICON="󰁻"
          ;;
          *) ICON="󰂎"
        esac

        if [[ "$CHARGING" != "" ]]; then
          ICON="󰂄"
        fi

        # The item invoking this script (name $NAME) will get its icon and label
        # updated with the current battery status
        sketchybar --set "$NAME" icon="$ICON" label="''${PERCENTAGE}%"

        # Handle click events to open AlDente
        if [ "$BUTTON" = "left" ]; then
          # Try to open AlDente - check common locations
          if [ -d "/Applications/AlDente.app" ]; then
            open "/Applications/AlDente.app"
          elif [ -d "$HOME/Applications/AlDente.app" ]; then
            open "$HOME/Applications/AlDente.app"
          elif command -v aldente &> /dev/null; then
            # If AlDente CLI is available, try to open it
            aldente &
          else
            # Fallback: try to find and open any battery management app
            open -a "System Preferences" "Energy" 2>/dev/null || open -a "System Settings" "Energy" 2>/dev/null
          fi
        fi
      '';
    };

    "sketchybar/plugins/clock.sh" = {
      executable = true;
      text = ''
        #!/bin/sh

        # The $NAME variable is passed from sketchybar and holds the name of
        # the item invoking this script:
        # https://felixkratz.github.io/SketchyBar/config/events#events-and-scripting

        sketchybar --set "$NAME" label="$(date '+%d/%m %H:%M')"

        # Handle click events to open Thunderbird
        if [ "$BUTTON" = "left" ]; then
          # Try to open Thunderbird - check common locations
          if [ -d "/Applications/Thunderbird.app" ]; then
            open "/Applications/Thunderbird.app"
          else
            # Thunderbird not found - you could add a notification here
            echo "Thunderbird not found in any expected location"
          fi
        fi
      '';
    };

    "sketchybar/plugins/volume.sh" = {
      executable = true;
      text = ''
        #!/bin/bash

        # Debug log file
        LOG_FILE="/tmp/sketchybar_volume_debug.log"

        # Function to log all event details
        log_event() {
          echo "======================================" >> "$LOG_FILE"
          echo "$(date '+%Y-%m-%d %H:%M:%S.%3N') - Event Received" >> "$LOG_FILE"
          echo "SENDER: $SENDER" >> "$LOG_FILE"
          echo "NAME: $NAME" >> "$LOG_FILE"
          echo "INFO: $INFO" >> "$LOG_FILE"
          echo "BUTTON: $BUTTON" >> "$LOG_FILE"
          echo "MODIFIER: $MODIFIER" >> "$LOG_FILE"
          echo "SCROLL_DELTA: $SCROLL_DELTA" >> "$LOG_FILE"

          # Get actual system state
          VOLUME_STATE=$(osascript -e "get volume settings")
          echo "SYSTEM_STATE: $VOLUME_STATE" >> "$LOG_FILE"
          echo "--------------------------------------" >> "$LOG_FILE"
        }

        parse_volume() {
          local volume_state
          volume_state=$(osascript -e "get volume settings")

          # Extract volume using parameter expansion
          local temp="''${volume_state#*output volume:}"  # Remove everything before "output volume:"
          VOLUME="''${temp%%,*}"                           # Store in global variable

          # Trim whitespace using bash built-in parameter expansion
          VOLUME="''${VOLUME// /}"  # Remove all spaces
        }

        parse_muted() {
          local volume_state
          volume_state=$(osascript -e "get volume settings")

          if [[ "$volume_state" =~ output\ muted:([a-z]+) ]]; then
            MUTED="''${BASH_REMATCH[1]}"
          else
            MUTED="false"
          fi
        }

        set_volume() {
          local volume="$1"
          osascript -e "set volume output volume $volume"
        }

        set_muted() {
          local muted="$1"
          osascript -e "set volume output muted $muted"
        }

        update_widget() {
          local volume="$1"
          local muted="$2"
          local icon

          case "$volume" in
            [6-9][0-9]|100)
              icon="󰕾"
            ;;
            [3-5][0-9])
              icon="󰖀"
            ;;
            [1-9]|[1-2][0-9])
              icon="󰕿"
            ;;
            *)
              icon="󰖁"
          esac

          if [[ "$muted" == "true" ]]; then
            icon="󰖁"
          fi

          sketchybar --set "$NAME" icon="$icon" label="$volume%"
        }


        case "$SENDER" in
          "forced")
            # The forced event is triggered on plugin init, doesn't contains any info.
            # Clear the log file
            > $LOG_FILE
          ;;
          "volume_change")
            # The volume_change event supplies a $INFO variable in which the current volume
            # percentage is passed to the script.
            parse_muted
            update_widget "$INFO" "$MUTED"
          ;;
          "mouse.clicked")
            parse_muted

            if [[ "$MUTED" == "false" ]]; then
              set_muted "true"
            else
              set_muted "false"
            fi
          ;;
          "mouse.scrolled")
            # The mouse.scrolled event supplies a $SCROLL_DELTA variable from which we can find
            # out the scroll direction, positive number scrolls up and negative scrolls down
            parse_volume
            local new_volume

            case "$SCROLL_DELTA" in
              -*)
                # Scroll down - decrease volume
                new_volume=$((VOLUME - 6))
                if [ "$new_volume" -lt 0 ]; then
                  new_volume=0
                fi
                set_volume "$new_volume"
              ;;
              *)
                # Scroll up - increase volume
                if [ "$SCROLL_DELTA" -gt 0 ]; then
                  new_volume=$((VOLUME + 6))
                  if [ "$new_volume" -gt 100 ]; then
                    new_volume=100
                  fi
                  set_volume "$new_volume"
                fi
              ;;
            esac
          ;;
        esac

        # Log event to a log file
        # log_event
      '';
    };

    "sketchybar/plugins/lock.sh" = {
      executable = true;
      text = ''
        #!/bin/sh

        # Lock icon for SketchyBar
        # Using Nerd Font icon (lock symbol)
        ICON="󰌾"

        sketchybar --set "$NAME" icon="$ICON" label.drawing=off

        # Handle click events to lock the Mac
        if [ "$BUTTON" = "left" ]; then
          # Lock the screen immediately using osascript
          osascript -e 'tell application "System Events" to keystroke "q" using {control down, command down}'
        fi
      '';
    };

    "sketchybar/plugins/protonmail.sh" = {
      executable = true;
      text = ''
        #!/bin/sh

        # Proton Mail Bridge plugin for SketchyBar
        # Note: Existence checking is handled by conditional_items.lua watcher
        # This script only updates the visual state when the item exists

        sketchybar --set "$NAME" \
          icon="󰇰" \
          icon.color="0xffffffff" \
          icon.font="JetBrainsMonoNL Nerd Font:Black:16.0" \
          label.drawing=off

        # Handle click events to open Proton Mail Bridge
        if [ "$BUTTON" = "left" ]; then
          open -a "Proton Mail Bridge"
        fi
      '';
    };

    "sketchybar/plugins/elgato.sh" = {
      executable = true;
      text = ''
        #!/bin/sh

        # Elgato Control Center plugin for SketchyBar
        # Note: Existence checking is handled by conditional_items.lua watcher
        # This script only updates the visual state when the item exists

        sketchybar --set "$NAME" \
          icon="󱩎" \
          icon.color="0xffffffff" \
          icon.font="JetBrainsMonoNL Nerd Font:Black:16.0" \
          label.drawing=off

        # Handle click events to open Elgato Control Center
        if [ "$BUTTON" = "left" ]; then
          open -a "Elgato Control Center"
        fi
      '';
    };

    "sketchybar/plugins/insync.sh" = {
      executable = true;
      text = ''
        #!/bin/sh

        # Insync plugin for SketchyBar
        # Note: Existence checking is handled by conditional_items.lua watcher
        # This script only updates the visual state when the item exists

        sketchybar --set "$NAME" \
          icon="󰓦" \
          icon.color="0xffffffff" \
          icon.font="JetBrainsMonoNL Nerd Font:Black:16.0" \
          label.drawing=off

        # Handle click events to open Insync
        if [ "$BUTTON" = "left" ]; then
          open -a "Insync"
        fi
      '';
    };

    "sketchybar/plugins/docker.sh" = {
      executable = true;
      text = ''
        #!/bin/sh

        # Docker plugin for SketchyBar
        # Note: Existence checking is handled by conditional_items.lua watcher
        # This script only updates the visual state when the item exists

        # Simple display - the watcher ensures this only runs when Docker is active
        sketchybar --set "$NAME" \
          icon="󰡨" \
          icon.color="0xffffffff" \
          icon.font="JetBrainsMonoNL Nerd Font:Black:16.0" \
          label.drawing=off

        # Handle click events to open lazydocker
        if [ "$BUTTON" = "left" ]; then
          /Applications/Ghostty.app/Contents/MacOS/ghostty -e lazydocker &
        fi
      '';
    };

    "sketchybar/plugins/watchman.sh" = {
      executable = true;
      text = ''
        #!/bin/sh

        # Watchman plugin for SketchyBar
        # Note: Existence checking is handled by conditional_items.lua watcher
        # This script only updates the visual state when the item exists

        # Simple display - the watcher ensures this only runs when Watchman has active watches
        sketchybar --set "$NAME" \
          icon="󰈈" \
          icon.color="0xffffa500" \
          icon.font="JetBrainsMonoNL Nerd Font:Black:16.0" \
          label.drawing=off

        # Handle click events to show watchman watch-list in terminal
        if [ "$BUTTON" = "left" ]; then
          /Applications/Ghostty.app/Contents/MacOS/ghostty -e sh -c "watchman watch-list | jq -C . 2>/dev/null || watchman watch-list; echo '\nPress any key to close...'; read -n 1" &
        fi
      '';
    };

    "sketchybar/conditional_items.lua" = {
      executable = true;
      text = ''
        #!/usr/bin/env lua

        -- SketchyBar Conditional Items Watcher
        -- Managed by nix home-manager via launchd.agents.sketchybar-conditional-items
        -- Runs every 5 seconds to dynamically add/remove items based on service availability

        --------------------------------------------------------------------------------
        -- Configuration
        --------------------------------------------------------------------------------

        local ITEM_PREFIX = "conditional"

        --------------------------------------------------------------------------------
        -- Helpers
        --------------------------------------------------------------------------------

        -- Execute sketchybar command
        local SKETCHYBAR = "/etc/profiles/per-user/${config.home.username}/bin/sketchybar"
        local function sketchybar(...)
          local args = table.concat({...}, " ")
          os.execute(SKETCHYBAR .. " " .. args)
        end

        -- Check if item exists in SketchyBar
        local function item_exists(name)
          local handle = io.popen(SKETCHYBAR .. " --query " .. name .. " 2>/dev/null")
          if not handle then return false end
          local result = handle:read("*a")
          local success = handle:close()
          return success == true and result ~= ""
        end

        -- Check if any conditional items exist (using pattern matching)
        local function any_conditional_exists()
          local handle = io.popen(SKETCHYBAR .. " --query bar 2>/dev/null | jq -r '.items[]' 2>/dev/null")
          if not handle then return false end
          local items = handle:read("*a")
          handle:close()

          -- Check if any item starts with "conditional."
          return items:find(ITEM_PREFIX .. "%.") ~= nil
        end

        --------------------------------------------------------------------------------
        -- Docker Item
        -- Example: Simple existence check using os.execute()
        -- Use this pattern when you only need to know if a command succeeds
        --------------------------------------------------------------------------------

        local function docker_exists()
          -- Returns true if docker daemon is running
          -- os.execute() in Lua 5.4+ returns (success, exit_type, exit_code)
          local success, _, _ = os.execute("/usr/local/bin/docker ps >/dev/null 2>&1")
          return success == true
        end

        local function manage_docker()
          local item_id = ITEM_PREFIX .. ".docker"
          local should_exist = docker_exists()
          local exists = item_exists(item_id)

          if should_exist and not exists then
            sketchybar("--add", "item", item_id, "right",
                       "--set", item_id,
                       "script=$HOME/.config/sketchybar/plugins/docker.sh",
                       "click_script=$HOME/.config/sketchybar/plugins/docker.sh",
                       "update_freq=5")
            print("[SketchyBar] Added: " .. item_id)
          elseif not should_exist and exists then
            sketchybar("--remove", item_id)
            print("[SketchyBar] Removed: " .. item_id)
          end
        end

        --------------------------------------------------------------------------------
        -- Watchman Item
        -- Example: Parsing command output using io.popen()
        -- Use this pattern when you need to read and parse command output
        --------------------------------------------------------------------------------

        local function watchman_exists()
          -- Check if watchman is running and watching any directories
          -- This demonstrates the io.popen() pattern for parsing output
          local handle = io.popen("watchman watch-list 2>/dev/null | jq '.roots | length' 2>/dev/null")
          if not handle then return false end
          local output = handle:read("*a")
          handle:close()

          local count = tonumber(output)
          if not count then return false end  -- Handle case where watchman/jq fails

          return count > 0
        end

        local function manage_watchman()
          local item_id = ITEM_PREFIX .. ".watchman"
          local should_exist = watchman_exists()
          local exists = item_exists(item_id)

          if should_exist and not exists then
            sketchybar("--add", "item", item_id, "right",
                       "--set", item_id,
                       "script=$HOME/.config/sketchybar/plugins/watchman.sh",
                       "click_script=$HOME/.config/sketchybar/plugins/watchman.sh",
                       "update_freq=5")
            print("[SketchyBar] Added: " .. item_id)
          elseif not should_exist and exists then
            sketchybar("--remove", item_id)
            print("[SketchyBar] Removed: " .. item_id)
          end
        end

        --------------------------------------------------------------------------------
        -- Insync Item
        --------------------------------------------------------------------------------

        local function insync_exists()
          local success, _, _ = os.execute("pgrep -x 'Insync' >/dev/null 2>&1")
          return success == true
        end

        local function manage_insync()
          local item_id = ITEM_PREFIX .. ".insync"
          local should_exist = insync_exists()
          local exists = item_exists(item_id)

          if should_exist and not exists then
            sketchybar("--add", "item", item_id, "right",
                       "--set", item_id,
                       "script=$HOME/.config/sketchybar/plugins/insync.sh",
                       "click_script=$HOME/.config/sketchybar/plugins/insync.sh",
                       "update_freq=5")
            print("[SketchyBar] Added: " .. item_id)
          elseif not should_exist and exists then
            sketchybar("--remove", item_id)
            print("[SketchyBar] Removed: " .. item_id)
          end
        end

        --------------------------------------------------------------------------------
        -- Elgato Item
        --------------------------------------------------------------------------------

        local function elgato_exists()
          local success, _, _ = os.execute("pgrep -x 'Elgato Control Center' >/dev/null 2>&1")
          return success == true
        end

        local function manage_elgato()
          local item_id = ITEM_PREFIX .. ".elgato"
          local should_exist = elgato_exists()
          local exists = item_exists(item_id)

          if should_exist and not exists then
            sketchybar("--add", "item", item_id, "right",
                       "--set", item_id,
                       "script=$HOME/.config/sketchybar/plugins/elgato.sh",
                       "click_script=$HOME/.config/sketchybar/plugins/elgato.sh",
                       "update_freq=5")
            print("[SketchyBar] Added: " .. item_id)
          elseif not should_exist and exists then
            sketchybar("--remove", item_id)
            print("[SketchyBar] Removed: " .. item_id)
          end
        end

        --------------------------------------------------------------------------------
        -- Protonmail Item
        --------------------------------------------------------------------------------

        local function protonmail_exists()
          local success, _, _ = os.execute("pgrep -x 'bridge-gui' >/dev/null 2>&1")
          return success == true
        end

        local function manage_protonmail()
          local item_id = ITEM_PREFIX .. ".protonmail"
          local should_exist = protonmail_exists()
          local exists = item_exists(item_id)

          if should_exist and not exists then
            sketchybar("--add", "item", item_id, "right",
                       "--set", item_id,
                       "script=$HOME/.config/sketchybar/plugins/protonmail.sh",
                       "click_script=$HOME/.config/sketchybar/plugins/protonmail.sh",
                       "update_freq=5")
            print("[SketchyBar] Added: " .. item_id)
          elseif not should_exist and exists then
            sketchybar("--remove", item_id)
            print("[SketchyBar] Removed: " .. item_id)
          end
        end

        --------------------------------------------------------------------------------
        -- Separator (dynamic - only shows when conditional items exist)
        --------------------------------------------------------------------------------

        local function add_separator()
          if not item_exists("separator") then
            sketchybar("--add", "item", "separator", "right",
                       "--set", "separator",
                       "icon='│'",
                       "label.drawing=off",
                       "icon.padding_left=8",
                       "icon.padding_right=8")
            print("[SketchyBar] Added: separator")
          end
        end

        local function remove_separator_if_no_conditionals()
          if not any_conditional_exists() and item_exists("separator") then
            sketchybar("--remove", "separator")
            print("[SketchyBar] Removed: separator")
          end
        end

        --------------------------------------------------------------------------------
        -- Main: Check all conditional items
        --------------------------------------------------------------------------------

        local function main()
          -- Add separator first (so it appears rightmost when conditional items are added)
          add_separator()

          -- Manage all conditional items
          manage_docker()
          manage_watchman()
          manage_insync()
          manage_elgato()
          manage_protonmail()

          -- Remove separator if no conditional items exist
          remove_separator_if_no_conditionals()
        end

        -- Run once and exit (nix launchd agent will restart every 5 seconds)
        main()
      '';
    };
  };
}
