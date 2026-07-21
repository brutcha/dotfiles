# Template — copy to ~/.config/dotfiles/private.nix and fill in real values.
# Consumed by flake.nix via `import` under --impure. Non-secret host metadata
# only; secrets live in KeePassXC and are extracted at activation time (see
# home.activation.keepassSecretsExtract in hosts/NB2123/home.nix).
let
  corpCaBundle = "/etc/nix/cert-bundle.pem";
in
{
  user = {
    name  = "Your Full Name";
    email = "you@corp.example";
  };

  # Each entry becomes a per-project direnv sidecar via
  # modules/home/development/dev-shells/corp-project.nix. Every project
  # declares its own packages + env exports. `env` values are written to
  # $HOME/.local/share/dev-shells/<projectId>/env.sh at activation time
  # (chmod 0600) and shell-expanded, so a value of "$CORP_XYZ" resolves
  # against whatever keepassSecretsExtract has exported — same channel as
  # registries.nix. registries.nix currently consumes
  # `projects.npaApp.{adoOrganization,registryFeed,registryScope}` for the
  # .yarnrc.yml Azure Artifacts wiring.
  projects = {
    npaApp = {
      projectId       = "MyOrg.Team.Project";
      adoOrganization = "myorg";
      registryFeed    = "feed-name%40Local";  # URL-encoded
      registryScope   = "myorg";              # npm scope prefix (@myorg/...)
      packages        = [ "nodejs_22" "corepack_22" "python3" "gnumake" ];
      env = {
        NODE_EXTRA_CA_CERTS = corpCaBundle;
      };

      # Optional. Per-project MCP servers, consumed by both agents:
      #   - Claude: `claude mcp add -s local` on direnv entry (cwd-scoped
      #     via .claude/settings.local.json).
      #   - Codex:  merged into <projectHome>/codex/config.toml at
      #     home-manager activation; direnv exports CODEX_HOME so terminals
      #     and Emdash worktrees pick up the per-project set automatically.
      # Schema — one of:
      #   { type = "http";  url = "..."; }
      #   { type = "stdio"; command = "..."; args = [ ... ]; }
      mcpServers = {
        # atlassian = {
        #   type = "http";
        #   url  = "https://mcp.atlassian.com/v1/mcp";
        # };
        # azure-devops = {
        #   type    = "stdio";
        #   command = "npx";
        #   # --ignore-scripts skips the postinstall that would shell out
        #   # to the system npm instead of the one direnv provides.
        #   args    = [ "-y" "--ignore-scripts" "@azure-devops/mcp" "myorg" ];
        # };
      };

    };
    # feApp = {
    #   projectId       = "MyOrg.Other.Project";
    #   adoOrganization = "myorg";
    #   packages        = [ "nodejs_22" "corepack_22" ];
    #   env = {
    #     NODE_EXTRA_CA_CERTS      = corpCaBundle;
    #     YARN_ENABLE_GLOBAL_CACHE = "1";
    #   };
    # };
  };

  # Host-global Claude Code plugin marketplaces + plugin picks.
  # Wired into programs.claude-code.{marketplaces,plugins} by NB2123/home.nix.
  # `builtins.fetchGit` clones with the user's git credentials, so ADO auth
  # (git credential helper / PAT) must be set up on the machine. URLs stay
  # out of flake.lock because fetchGit is called at eval time, not as a
  # flake input. Bump `ref`/add `rev` to pin an exact revision.
  claude = {
    marketplaces = {
      # my-marketplace = {
      #   url = "https://dev.azure.com/<org>/<project>/_git/<marketplace-repo>";
      #   ref = "main";
      # };
    };
    plugins = [
      # `marketplace` matches an attr key above; `path` is the plugin dir
      # inside that repo (typically "plugins/<plugin-name>").
      # { marketplace = "my-marketplace"; path = "plugins/plugin-name"; }
    ];
  };
}
