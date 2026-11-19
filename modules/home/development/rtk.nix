{ config, lib, pkgs, ... }:
#
# rtk (https://github.com/rtk-ai/rtk) — Claude Code Bash-tool output compressor
#
# Available options:
# - home.apps.development.rtk.enable - Install rtk and run `rtk init -g --auto-patch` on activation.
#   Auto-defaults to home.apps.development.claude-code.enable.
#
# `rtk init -g --auto-patch` writes a PreToolUse hook into ~/.claude/settings.json.
# Requires that file to be writable — handled by claude-code.nix's
# claudeCodeSettings activation (runs first, converts the home-manager
# symlink into a real file).
#
# OpenCode uses the V2 adapter below.
#
let
  cfg = config.home.apps.development.rtk;
  claudeEnabled = config.home.apps.development.claude-code.enable;
  opencodeEnabled = config.home.apps.development.opencode.enable;
  opencodePluginDir = "${config.home.homeDirectory}/.config/opencode/plugins";
  opencodeAdapterPath = "${opencodePluginDir}/rtk.ts";
  opencodeAdapter = pkgs.replaceVars ./scripts/rtk-opencode.ts {
    rtkBinary = "${pkgs.rtk}/bin/rtk";
  };
in
{
  options.home.apps.development.rtk.enable = lib.mkOption {
    type = lib.types.bool;
    default = claudeEnabled || opencodeEnabled;
    description = "Install RTK and configure its enabled Claude Code/OpenCode integrations.";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.rtk ];

    # Keep a dedicated instruction file for OpenCode. Unlike ~/.claude/RTK.md,
    # this file is declaratively present whenever the OpenCode adapter is used.
    home.file.".config/opencode/RTK.md" = lib.mkIf opencodeEnabled {
      text = ''
        # RTK

        RTK is enabled for OpenCode and rewrites shell commands through its
        OpenCode adapter before execution.
      '';
    };

    home.activation.rtkInit = lib.mkIf claudeEnabled
      (lib.hm.dag.entryAfter [ "claudeCodeSettings" "installPackages" ] ''
        _rtk_init() {
          local out
          if out="$($DRY_RUN_CMD ${pkgs.rtk}/bin/rtk init -g --auto-patch 2>&1)"; then
            echo "rtk hook: registered" >&2
          else
            echo "warn: rtk hook registration failed — downstream activations will still run" >&2
            printf '  %s\n' "$out" >&2
            return 1
          fi
        }
        _rtk_init || true
      '');

    home.activation.rtkOpenCodeAdapter = lib.mkIf opencodeEnabled
      (lib.hm.dag.entryAfter [ "installPackages" ] ''
        $DRY_RUN_CMD install -d -m 0700 ${lib.escapeShellArg opencodePluginDir}
        if [ ! -f ${lib.escapeShellArg opencodeAdapterPath} ] || ! ${pkgs.diffutils}/bin/cmp -s ${opencodeAdapter} ${lib.escapeShellArg opencodeAdapterPath}; then
          adapter_tmp=${lib.escapeShellArg opencodeAdapterPath}.tmp.$$
          $DRY_RUN_CMD install -m 0600 ${opencodeAdapter} "$adapter_tmp"
          $DRY_RUN_CMD mv -f "$adapter_tmp" ${lib.escapeShellArg opencodeAdapterPath}
        fi
      '');
  };
}
