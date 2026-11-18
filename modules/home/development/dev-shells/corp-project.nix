{ pkgs, lib, inputs, project, private, config }:
# Per-project direnv sidecar. Instantiated from ./default.nix per private.projects entry.
let
  projectId = project.projectId;
  flakePackages = project.packages;

  attrSafeId = builtins.replaceStrings [ "." "-" ] [ "_" "_" ] projectId;

  codexCfg = config.home.apps.development.codex;
  codexEnabled = codexCfg.enable;
  # Keep the app-server control socket path short.
  codexHomeDir = "${config.home.homeDirectory}/.codex-home/${builtins.substring 0 12 (builtins.hashString "sha256" projectId)}";

  claudeEnabled = config.home.apps.development.claude-code.enable;
  opencodeEnabled = config.home.apps.development.opencode.enable;
  claudeHomeDir = "${config.home.homeDirectory}/.local/share/dev-shells/${projectId}/claude";
  opencodeProjectDir = "${config.home.homeDirectory}/.local/share/opencode-projects/${projectId}";
  opencodeRenderer = "${config.home.homeDirectory}/.config/dotfiles/opencode-devkit-port/scripts/render-opencode-project.py";

  projectMcpServers = project.mcpServers or { };
  # { "<plugin>@<marketplace>" = { <userConfigKey> = "$CORP_FOO" | "literal"; }; }
  projectPluginUserConfig = project.pluginUserConfig or { };

  projectClaudePlugins = project.claudePlugins or [ ];
  readMarketplaceName = mpPath:
    builtins.unsafeDiscardStringContext # Remove store-path dependency metadata.
      (builtins.fromJSON (builtins.readFile "${mpPath}/.claude-plugin/marketplace.json")).name
  ;

  readPluginVersion = p:
    let jp = "${toString p}/plugin.json"; in
    if builtins.pathExists jp
    then
      builtins.unsafeDiscardStringContext
        ((builtins.fromJSON (builtins.readFile jp)).version or "")
    else "";

  mkPluginSpec = p:
    let
      mpRoot = dirOf (dirOf (toString p));
      mpJson = "${mpRoot}/.claude-plugin/marketplace.json";
    in
    if builtins.pathExists mpJson then {
      name = builtins.unsafeDiscardStringContext (baseNameOf (toString p));
      marketplace = readMarketplaceName mpRoot;
      id = builtins.unsafeDiscardStringContext
        "${baseNameOf (toString p)}@${readMarketplaceName mpRoot}";
      version = readPluginVersion p;
    } else null;
  projectClaudePluginSpecs = builtins.filter (s: s != null)
    (map mkPluginSpec projectClaudePlugins);
  projectClaudePluginIds = map (s: s.id) projectClaudePluginSpecs;
  projectClaudePluginNames = map (p: baseNameOf (toString p)) projectClaudePlugins;
  projectMarketplaceRoot =
    if projectClaudePlugins != [ ]
    then dirOf (dirOf (toString (builtins.head projectClaudePlugins)))
    else null;
  projectMarketplaceName =
    if projectMarketplaceRoot != null
    then readMarketplaceName projectMarketplaceRoot
    else null;
  projectMarketplaceInstallRoot =
    if projectMarketplaceRoot != null
    then "${config.home.homeDirectory}/.local/share/corp-marketplaces/${projectMarketplaceName}"
    else null;
  # Codex uses its own plugin cache and marketplace config. The same local
  # marketplace is valid for both CLIs, but Claude's installed state is not.
  codexPluginSettings =
    if projectClaudePluginIds == [ ] then { } else {
      marketplaces.${projectMarketplaceName} = {
        source_type = "local";
        source = projectMarketplaceInstallRoot;
      };
      plugins = lib.genAttrs projectClaudePluginIds (_: { enabled = true; });
    };
  # Codex starts stdio MCPs outside direnv; pass only the CA variables.
  projectMcpCertificateEnv = lib.filterAttrs
    (name: _: builtins.elem name [
      "NODE_EXTRA_CA_CERTS"
      "SSL_CERT_FILE"
    ])
    (project.env or { });
  projectMcpServersWithCertificates = lib.mapAttrs
    (_: server:
      if server.type or null == "stdio" then server // {
        # MCP-specific values override the project defaults.
        env = projectMcpCertificateEnv // (server.env or { });
      } else server
    )
    projectMcpServers;
  # In a store file (not a shell heredoc) so an apostrophe in any mcpServers
  # value can't break the activation-time jq call. Unresolved $CORP_* refs —
  # the jq walker below resolves them.
  projectMcpServersFile = pkgs.writeText "${projectId}-mcps.json"
    (builtins.toJSON projectMcpServersWithCertificates);
  opencodeProjectSpec = pkgs.writeText "${projectId}-opencode-project.json" (builtins.toJSON {
    inherit projectId;
    projectRoot = "${config.home.homeDirectory}/git/${projectId}";
    marketplace = if projectMarketplaceInstallRoot != null then projectMarketplaceInstallRoot else "";
    pluginNames = projectClaudePluginNames;
    mcpServers = projectMcpServersWithCertificates;
  });

  devShellScriptLibrary = pkgs.python3Packages.buildPythonPackage {
    pname = "dev-shell-scripts";
    version = "1";
    pyproject = false;
    dontUnpack = true;
    installPhase = ''
      install -Dm444 ${./scripts/dev_shell_scripts.py} \
        "$out/${pkgs.python3.sitePackages}/dev_shell_scripts.py"
    '';
  };
  writeDevShellPython = name: source:
    pkgs.writers.writePython3 name {
      libraries = [ devShellScriptLibrary ];
      flakeIgnore = [ "E501" "W503" ];
    }
      (builtins.readFile source);
  syncOpenCodeProject = writeDevShellPython "sync-opencode-project" ./scripts/sync-opencode-project.py;
  syncEmdashDb = writeDevShellPython "sync-emdash-db" ./scripts/sync-emdash-db.py;
  syncEnvLocal = writeDevShellPython "sync-env-local" ./scripts/sync-env-local.py;
  syncClaudePlugins = writeDevShellPython "sync-claude-plugins" ./scripts/sync-claude-plugins.py;
  syncCodexPlugins = writeDevShellPython "sync-codex-plugins" ./scripts/sync-codex-plugins.py;
  materializeSidecar = writeDevShellPython "materialize-dev-shell-sidecar" ./scripts/materialize-sidecar.py;
  claudePluginSyncSpec = pkgs.writeText "${projectId}-claude-plugin-sync.json"
    (builtins.toJSON (map
      (spec: spec // {
        config = projectPluginUserConfig.${spec.id} or { };
      })
      projectClaudePluginSpecs));

  envExportsAttrs = (project.env or { })
    // lib.optionalAttrs codexEnabled { CODEX_HOME = codexHomeDir; }
    // lib.optionalAttrs claudeEnabled {
    CLAUDE_CONFIG_DIR = claudeHomeDir;
    # Claude Code's settings.json env is trust-dialog-gated; process env isn't.
    ANTHROPIC_API_KEY = "$CORP_ANTHROPIC_JWT";
    ANTHROPIC_BASE_URL = "$CORP_ANTHROPIC_BASE_URL";
  };

  # Keys the user declared in project.env — the set envLocalSync rewrites.
  # Everything else in .env.local (manual literals, generated blocks,
  # comments) is left alone.
  envLocalManagedKeys = builtins.attrNames (project.env or { });

  shellHook = ''
    envFile="$HOME/.local/share/dev-shells/${projectId}/env.sh"
    [ -r "$envFile" ] && . "$envFile"

    # Per-direnv prefix — overrides the outer shell's ~/.npm-global.
    export NPM_CONFIG_PREFIX="$HOME/.local/share/dev-shells/${projectId}/npm-global"
    export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
  '';

  flakeContent = pkgs.replaceVars ./templates/node-project.flake.nix {
    inherit shellHook;
    nixpkgsRev = inputs.nixpkgs.rev;
    system = pkgs.stdenv.hostPlatform.system;
    packages = lib.concatStringsSep " " flakePackages;
  };

  envrcContent = pkgs.writeText ".envrc"
    "use flake ~/.local/share/dev-shells/${projectId}\n";

  # `.emdash.json` filtered out by emdash's schema — handled via scripts.setup.
  # `.custom*` paths symlinked (not copied) in scripts.setup to avoid drift.
  emdashPreservePatterns = [
    ".env"
    ".env.dev"
    ".env.test"
    ".env.local"
    ".envrc"
  ];

  # Prepended by emdash to every PTY/agent spawn. Without this, Claude spawns
  # without CLAUDE_CONFIG_DIR set → sessions leak to global ~/.claude/.
  emdashShellSetup = ''${emdashSetupScript} && . "$HOME/.local/share/dev-shells/${projectId}/env.sh"'';

  # scripts.setup runs emdashSetupScript first so a fresh worktree gets
  # .emdash.json + symlinks before shellSetup has anything to attach to.
  projectScriptsSetup = project.scriptsSetup or
    "direnv allow . && direnv exec . yarn install --immutable";

  # Shared from the base checkout's `.devkit/` once it holds `personal/`.
  emdashDevkitShared = [
    "personal"
    "tasks"
    "retrospectives"
    "research"
    "improvement-tracker.md"
    "recurring-issues-log.md"
    "reviewers.json"
  ];

  emdashSetupScript = pkgs.writeShellScript "emdash-worktree-setup-${attrSafeId}"
    (builtins.readFile (pkgs.replaceVars ./scripts/emdash-worktree-setup.sh {
      inherit projectId;
      devkitShared = lib.escapeShellArgs emdashDevkitShared;
    }));

  emdashScriptsSetup = ''${emdashSetupScript} && ${projectScriptsSetup}'';

  workmuxPostCreateScript = pkgs.writeShellScript "workmux-post-create-${attrSafeId}"
    (builtins.readFile (pkgs.replaceVars ./scripts/workmux-post-create.sh {
      inherit projectId;
      coreutils = pkgs.coreutils;
      direnv = pkgs.direnv;
      bash = pkgs.bash;
      devkitShared = lib.escapeShellArgs emdashDevkitShared;
      projectSetup = lib.escapeShellArg projectScriptsSetup;
    }));

  workmuxProjectConfig = pkgs.writeText "${projectId}.workmux.yaml" ''
    # Generated by Home Manager. Additional project-specific settings may be
    # added alongside this post_create hook.
    post_create:
      - ${config.home.homeDirectory}/.local/share/dev-shells/${projectId}/workmux-post-create
  '';

  emdashConfig = pkgs.writeText ".emdash.json" (builtins.toJSON {
    preservePatterns = emdashPreservePatterns;
    shellSetup = emdashShellSetup;
    scripts = {
      setup = emdashScriptsSetup;
      run = "";
      teardown = "";
    };
  });

  codexProjectConfig =
    if codexEnabled then codexCfg._lib.renderConfigToml projectMcpServersWithCertificates codexPluginSettings
    else null;
  sidecarSpec = pkgs.writeText "${projectId}-dev-shell-sidecar.json" (builtins.toJSON {
    inherit projectId;
    sidecarDirectory = "${config.home.homeDirectory}/.local/share/dev-shells/${projectId}";
    repositoryDirectory = "${config.home.homeDirectory}/git/${projectId}";
    sidecarFiles = {
      "flake.nix" = flakeContent;
      ".emdash.json" = emdashConfig;
      ".envrc" = envrcContent;
      "workmux-post-create" = workmuxPostCreateScript;
    };
    environment = envExportsAttrs;
    workmuxConfig = workmuxProjectConfig;
    marketplaceSource = if projectMarketplaceRoot != null then projectMarketplaceRoot else "";
    marketplaceDestination = if projectMarketplaceInstallRoot != null then projectMarketplaceInstallRoot else "";
    codex =
      if codexEnabled then {
        home = codexHomeDir;
        config = codexProjectConfig;
      } else null;
    claude =
      if claudeEnabled then {
        home = claudeHomeDir;
        mcpServers = projectMcpServersFile;
      } else null;
  });
in
{
  # Ordering constraints:
  #   - keepassSecretsExtract  — env.sh + Codex config.toml need $CORP_* set
  #   - claudeCodeSettings / claudeCodeCorpSecrets / rtkInit — the Claude
  #     branch snapshots ~/.claude/settings.json, and those three writers
  #     together produce the authoritative content (env + JWT + RTK hook).
  home.activation."corpSidecar_${attrSafeId}" =
    lib.hm.dag.entryAfter [
      "writeBoundary"
      "keepassSecretsExtract"
      "claudeCodeSettings"
      "claudeCodeCorpSecrets"
      "rtkInit"
    ] ''
      $DRY_RUN_CMD ${materializeSidecar} --spec ${sidecarSpec}
    '';

  home.activation."opencodeProject_${attrSafeId}" =
    lib.mkIf opencodeEnabled
      (lib.hm.dag.entryAfter [ "corpSidecar_${attrSafeId}" "opencodeConfig" ] ''
        $DRY_RUN_CMD ${syncOpenCodeProject} \
          --renderer ${lib.escapeShellArg opencodeRenderer} \
          --spec ${opencodeProjectSpec} \
          --project-directory ${lib.escapeShellArg opencodeProjectDir} \
          --repository-directory ${lib.escapeShellArg "${config.home.homeDirectory}/git/${projectId}"}
      '');

  home.activation."emdashDbSync_${attrSafeId}" =
    lib.hm.dag.entryAfter [ "corpSidecar_${attrSafeId}" ] ''
      $DRY_RUN_CMD ${syncEmdashDb} \
        --project-directory "$HOME/git/${projectId}" \
        --preserve-patterns ${lib.escapeShellArg (builtins.toJSON emdashPreservePatterns)} \
        --setup-script ${lib.escapeShellArg emdashScriptsSetup} \
        --database "$HOME/Library/Application Support/emdash/workspace-registry.db" || true
    '';

  home.activation."envLocalSync_${attrSafeId}" =
    lib.hm.dag.entryAfter [ "corpSidecar_${attrSafeId}" ] ''
      envShPath="$HOME/.local/share/dev-shells/${projectId}/env.sh"
      if [ -f "$envShPath" ] && [ -n ${lib.escapeShellArg (lib.concatStringsSep " " envLocalManagedKeys)} ]; then
        set +u
        . "$envShPath" 2>/dev/null
        ${syncEnvLocal} --keys ${lib.escapeShellArgs envLocalManagedKeys} \
          "$HOME/git/${projectId}/.env.local" \
          "$HOME/git/${projectId}__worktrees/"*/.env.local \
          "$HOME/emdash/worktrees/${projectId}/emdash/"*/.env.local \
          "$HOME/emdash/worktrees/${projectId}-"*/emdash-*/.env.local || true
      fi
    '';

  home.activation."codexPluginSync_${attrSafeId}" =
    lib.hm.dag.entryAfter [ "corpSidecar_${attrSafeId}" ] (
      lib.optionalString (codexEnabled && projectClaudePluginIds != [ ]) ''
        $DRY_RUN_CMD ${syncCodexPlugins} \
          --codex ${pkgs.codex}/bin/codex \
          --home ${lib.escapeShellArg codexHomeDir} \
          ${lib.escapeShellArgs projectClaudePluginIds}
      '');

  home.activation."claudePluginSync_${attrSafeId}" =
    lib.hm.dag.entryAfter [ "corpSidecar_${attrSafeId}" ] (
      lib.optionalString (claudeEnabled && projectClaudePluginIds != [ ]) ''
        (
          set +u
          envFile="$HOME/.local/share/dev-shells/${projectId}/env.sh"
          [ -f "$envFile" ] && . "$envFile" 2>/dev/null
          $DRY_RUN_CMD ${syncClaudePlugins} \
            --claude ${config.programs.claude-code.package}/bin/claude \
            --config-directory ${lib.escapeShellArg claudeHomeDir} \
            --marketplace ${lib.escapeShellArg projectMarketplaceName} \
            --marketplace-directory ${lib.escapeShellArg projectMarketplaceInstallRoot} \
            --settings-file "$HOME/.claude/settings.json" \
            --repository-directory ${lib.escapeShellArg "${config.home.homeDirectory}/git/${projectId}"} \
            --spec ${claudePluginSyncSpec}
        ) || true
      '');

  programs.git.includes = [
    {
      condition = "hasconfig:remote.*.url:**/${projectId}/**";
      contents.user = {
        name = private.user.name;
        email = private.user.email;
      };
    }
  ];
}
