{ config, inputs, lib, pkgs, ... }:
#
# Claude Code — plugins, MCP servers, and host-supplied env.
#
# settings.json is left as a writable regular file: rtk and Claude Code
# both edit it. `mergeSettingsScript` merges HM's baseline, recovered user
# keys, and nix overrides on each activation.
#
let
  cfg = config.home.apps.development.claude-code;
  settingsOverridesJson = builtins.toJSON {
    env = cfg.env;
    permissions = {
      allow = [ "Bash(rtk *)" ];
    };
  };

  mergeSettingsScript = pkgs.writers.writePython3 "claude-code-merge-settings" { } ''
    import glob
    import json
    import os
    import pathlib
    import sys


    def deep_merge(base, overlay):
        for key, value in overlay.items():
            if isinstance(value, dict) and isinstance(base.get(key), dict):
                deep_merge(base[key], value)
            else:
                base[key] = value


    settings_path = pathlib.Path(os.environ["HOME"]) / ".claude" / "settings.json"
    nix_overrides = json.loads(sys.argv[1])

    # Writable copy — rtk and Claude Code both write to this file at runtime.
    if settings_path.is_symlink():
        hm_baseline_content = settings_path.read_text()
        settings_path.unlink()
        settings_path.write_text(hm_baseline_content)
        settings_path.chmod(0o600)
    settings_path.parent.mkdir(parents=True, exist_ok=True)
    if not settings_path.exists():
        settings_path.write_text("{}")

    hm_baseline = json.loads(settings_path.read_text())
    nix_owned_keys = set(hm_baseline) | set(nix_overrides)
    merged_settings = dict(hm_baseline)

    # Recover user keys (rtk hooks, theme, plugin toggles) from any
    # interrupted prior activations.
    sidecars_from_prior_runs = (
        sorted(glob.glob(f"{settings_path}.recovery.*"))
        + [f"{settings_path}.backup"]
    )
    consumed_sidecars = []
    for sidecar_path_str in sidecars_from_prior_runs:
        sidecar_path = pathlib.Path(sidecar_path_str)
        if not sidecar_path.is_file():
            continue
        sidecar_contents = json.loads(sidecar_path.read_text())
        preserved_user_keys = {
            key: value for key, value in sidecar_contents.items()
            if key not in nix_owned_keys
        }
        deep_merge(merged_settings, preserved_user_keys)
        consumed_sidecars.append(sidecar_path)

    # Replace (not deep-merge) so keys removed from nix actually disappear.
    for key, value in nix_overrides.items():
        merged_settings[key] = value

    # Atomic write, then drop sidecars — if the write is interrupted the
    # sidecars survive so the next activation can retry.
    tmp_path = settings_path.with_suffix(settings_path.suffix + ".tmp")
    tmp_path.write_text(json.dumps(merged_settings, indent=2) + "\n")
    os.replace(tmp_path, settings_path)
    for sidecar_path in consumed_sidecars:
        sidecar_path.unlink()
  '';
in
{
  options.home.apps.development.claude-code = {
    enable = lib.mkEnableOption "Claude Code with plugins, MCP servers, and host-supplied env";

    env = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "settings.json env — provider URL, auth token, model, CA, gateway flags.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Node + corepack for MCPs spawned outside direnv (Emdash, etc.).
    home.packages = [
      (lib.hiPrio pkgs.nodejs_22)
      pkgs.corepack
    ];

    programs.claude-code = {
      enable = true;
      enableMcpIntegration = true;

      # Bump with `nix flake update <input>`.
      plugins = {
        figma-plugin = inputs.figma-plugin;
        typescript-lsp = "${inputs.claude-plugins-official}/plugins/typescript-lsp";
      };

      # User-global MCP servers (project-scoped ones live in each project's .mcp.json).
      mcpServers = {
        context7 = {
          type = "http";
          url = "https://mcp.context7.com/mcp";
        };
        playwright = {
          type = "stdio";
          command = "yarn";
          args = [ "dlx" "@playwright/mcp@latest" "--headless" ];
        };
      };
    };

    # Timestamped so repeated interrupts accumulate distinct sidecars for
    # claudeCodeSettings to merge — never clobbered.
    home.activation.claudeCodeBackupCleanup =
      lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        if [ -f "$HOME/.claude/settings.json.backup" ]; then
          $DRY_RUN_CMD mv "$HOME/.claude/settings.json.backup" \
            "$HOME/.claude/settings.json.recovery.$(date +%s)"
        fi
        $DRY_RUN_CMD rm -f "$HOME/.claude/plugins/known_marketplaces.json.backup"
      '';

    home.activation.claudeCodeSettings =
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        $DRY_RUN_CMD ${mergeSettingsScript} ${lib.escapeShellArg settingsOverridesJson}
      '';
  };
}
