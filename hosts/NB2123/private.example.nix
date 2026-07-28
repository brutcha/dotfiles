# Template — copy to ~/.config/dotfiles/private.nix and fill in real values.
# Consumed by flake.nix via `import` under --impure. Non-secret host metadata
# only; secrets live in KeePassXC and are extracted at activation time (see
# home.activation.keepassSecretsExtract in hosts/NB2123/home.nix).
let
  corpCaBundle = "/etc/nix/cert-bundle.pem";
  # Pulled into a let-binding so per-project env can reference the same value
  # as `user.email` — e.g. CONFLUENCE_USERNAME below.
  corpEmail = "you@corp.example";
in
{
  user = {
    name = "Your Full Name";
    email = corpEmail;
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
      projectId = "MyOrg.Team.Project";
      adoOrganization = "myorg";
      registryFeed = "feed-name%40Local"; # URL-encoded
      registryScope = "myorg"; # npm scope prefix (@myorg/...)
      packages = [ "nodejs_22" "corepack_22" "python3" "gnumake" "azure-cli" ];

      # Optional. Runs once at worktree creation via emdash's scripts.setup,
      # after `cp .emdash.json` (which is always prefixed for you). Default:
      # `direnv allow . && direnv exec . yarn install --frozen-lockfile`.
      scriptsSetup = "direnv allow . && direnv exec . yarn install --frozen-lockfile && direnv exec . yarn my-post-install-script";

      env = {
        NODE_EXTRA_CA_CERTS = corpCaBundle;
        SSL_CERT_FILE = corpCaBundle;

        # All refs must match a key in `corpSecrets` in hosts/NB2123/home.nix.
        AZURE_DEVOPS_RELEASE_TOKEN = "$CORP_AZURE_DEVOPS_RELEASE_TOKEN";

        # Literals — public config / user identity, not secrets.
        CONFLUENCE_USERNAME = corpEmail;
      };

      # Per-project MCP servers merged into each agent's config:
      #   - Codex: written to <projectHome>/codex/config.toml as [mcp_servers.<name>].
      #   - Claude: written to <projectHome>/claude/.claude.json under .mcpServers.<name>.
      # Schema — one of:
      #   { type = "http";  url = "..."; authorization_env_var = "..."; }
      #   { type = "stdio"; command = "..."; args = [ ... ]; env = { ... }; }
      #
      # For stdio, `env` values with `$CORP_*` refs are resolved to literals
      # at activation and baked into config.toml / .claude.json (chmod 0600).
      mcpServers = {
        atlassian = {
          type = "http";
          url = "https://mcp.atlassian.com/v1/mcp";
        };
        # DevOps MCP. --authentication envvar reads raw PAT from $ADO_MCP_AUTH_TOKEN
        # (no interactive az login). Note: `env` is a DIFFERENT mode meaning
        # DefaultAzureCredential chain — don't confuse the two.
        # --ignore-scripts skips the postinstall that would shell out to the
        # system npm instead of the one direnv provides. PAT needs Code R/W.
        azure-devops = {
          type = "stdio";
          command = "npx";
          args = [ "-y" "--ignore-scripts" "@azure-devops/mcp" "myorg" "--authentication" "envvar" ];
          env = {
            ADO_MCP_AUTH_TOKEN = "$CORP_AZURE_DEVOPS_MCP";
          };
        };
      };
    };

    otherProject = {
      projectId = "MyOrg.Other.Project";
      adoOrganization = "myorg";
      packages = [ "nodejs_22" "corepack_22" "python3" "azure-cli" ];
      env = {
        NODE_EXTRA_CA_CERTS = corpCaBundle;
        #     # Local cache + Yarn 4.1 on Node 22 → EBADF; force global cache back on.
        YARN_ENABLE_GLOBAL_CACHE = "1";
      };
    };
  };

  # Host-global Claude Code plugin marketplaces + plugin picks.
  claude = {
    marketplaces = {
      my-marketplace = {
        url = "https://dev.azure.com/<org>/<project>/_git/<marketplace-repo>";
        ref = "main";
      };
    };
    plugins = [
      # `marketplace` matches an attr key above; `path` is the plugin dir
      # inside that repo (typically "plugins/<plugin-name>").
      { marketplace = "my-marketplace"; path = "plugins/plugin-name"; }
    ];
  };
}
