{ config, inputs, lib, pkgs, ... }:
#
# Claude Code — plugins, MCP servers, and host-supplied env.
#
# `programs.claude-code.settings` is intentionally NOT used: home-manager
# would symlink settings.json to a read-only store path, blocking rtk's
# hook writer. Instead we jq-merge our declared values into a writable
# file, so untouched keys (rtk hooks, UI prefs) survive between rebuilds.
#
let
  cfg = config.home.apps.development.claude-code;
  settingsOverridesJson = builtins.toJSON {
    env = cfg.env;
    enabledPlugins = {
      "typescript-lsp@claude-plugins-official" = true;
    };
    permissions = {
      allow = [ "Bash(rtk *)" ];
    };
  };
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

    home.activation.claudeCodeSettings =
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        settingsPath="$HOME/.claude/settings.json"
        $DRY_RUN_CMD mkdir -p "$(dirname "$settingsPath")"

        # Replace a store-symlinked settings.json with a writable copy.
        if [ -L "$settingsPath" ]; then
          target="$(readlink "$settingsPath")"
          $DRY_RUN_CMD rm "$settingsPath"
          $DRY_RUN_CMD cp "$target" "$settingsPath"
          $DRY_RUN_CMD chmod u+w "$settingsPath"
        fi
        [ -f "$settingsPath" ] || echo '{}' > "$settingsPath"

        tmp="$(mktemp)"
        ${pkgs.jq}/bin/jq --argjson o ${lib.escapeShellArg settingsOverridesJson} \
          '. * $o' "$settingsPath" > "$tmp"
        $DRY_RUN_CMD mv "$tmp" "$settingsPath"
      '';
  };
}
