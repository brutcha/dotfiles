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
let
  cfg = config.home.apps.development.rtk;
in
{
  options.home.apps.development.rtk.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.home.apps.development.claude-code.enable;
    description = "Install rtk and re-run `rtk init -g --auto-patch` on every rebuild. Auto-on with claude-code.";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.rtk ];

    # Invoke rtk by absolute store path — during home-manager activation
    # the new profile's PATH isn't always live, so `command -v rtk` can
    # spuriously return false even when installPackages has just put it in
    # the store.
    # Function + `|| true` so rtk failure doesn't abort downstream
    # activations (set -e is on).
    home.activation.rtkInit =
      lib.hm.dag.entryAfter [ "claudeCodeSettings" "installPackages" ] ''
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
      '';
  };
}
