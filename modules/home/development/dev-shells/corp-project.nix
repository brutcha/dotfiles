{ pkgs, lib, inputs, project, private, config }:
# Per-project direnv sidecar. Instantiated from ./default.nix per private.projects entry.
let
  projectId = project.projectId;
  flakePackages = project.packages;

  # Sanitize dots/dashes for use as a home.activation attribute name.
  attrSafeId = builtins.replaceStrings [ "." "-" ] [ "_" "_" ] projectId;

  codexCfg = config.home.apps.development.codex;
  codexEnabled = codexCfg.enable;
  codexHomeDir = "${config.home.homeDirectory}/.local/share/dev-shells/${projectId}/codex";

  projectMcpServers = project.mcpServers or { };

  # env.sh written at activation (chmod 0600); values may reference $CORP_* from
  # keepassSecretsExtract. CODEX_HOME crosses direnv-eval boundaries (env vars
  # survive `eval "$(direnv export bash)"` used by Emdash shellSetup), so
  # per-project codex config + auth resolve automatically for agents spawned
  # inside worktrees.
  envExportsAttrs = (project.env or { })
    // lib.optionalAttrs codexEnabled { CODEX_HOME = codexHomeDir; };
  envExports = lib.concatStringsSep ""
    (lib.mapAttrsToList (k: v: "export ${k}=\"${v}\"\n") envExportsAttrs);

  # Per-project `claude mcp add -s local` registrations. Attribute schema
  # mirrors programs.claude-code.mcpServers in claude-code.nix:
  #   { type = "http";  url = "..."; }
  #   { type = "stdio"; command = "..."; args = [ ... ]; }
  # `mcp get` is the idempotency check — `add` only runs on first entry.
  mcpAddCmd = name: cfg:
    let base = "claude mcp add ${lib.escapeShellArg name} -s local"; in
    if cfg.type == "http" then
      "${base} --transport http ${lib.escapeShellArg cfg.url}"
    else if cfg.type == "stdio" then
      "${base} -- ${lib.escapeShellArg cfg.command} ${
        lib.concatMapStringsSep " " lib.escapeShellArg (cfg.args or [ ])
      }"
    else throw "corp-project.nix: projects.${projectId}.mcpServers.${name}.type '${cfg.type}' unsupported (want 'http' or 'stdio').";

  claudeAddLines = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: cfg:
      "  claude mcp get ${lib.escapeShellArg name} >/dev/null 2>&1 || \\\n    ${mcpAddCmd name cfg}"
    ) projectMcpServers
  );

  claudeAddBlock =
    if claudeAddLines == "" then ""
    else ''

      if command -v claude >/dev/null 2>&1; then
      ${claudeAddLines}
      fi'';

  # For each per-project MCP: if `codex mcp list` reports it "Not logged in",
  # trigger `codex mcp login <name>` when the shell is a TTY (browser OAuth
  # can complete). Otherwise just print a hint — never block a non-interactive
  # shell on an OAuth handshake that has no way to finish.
  codexLoginLines = lib.concatMapStringsSep "\n" (name:
    let n = lib.escapeShellArg name; in
    ''
      if printf '%s\n' "$codex_mcp_list" | ${pkgs.gawk}/bin/awk -v n=${n} '$1==n' | grep -q "Not logged in"; then
        if [ -t 0 ] && [ -t 1 ]; then
          echo "codex: MCP ${name} needs OAuth — opening browser" >&2
          codex mcp login ${n} || echo "warn: codex mcp login ${name} failed" >&2
        else
          echo ">>> non-interactive shell — run manually: codex mcp login ${name}" >&2
        fi
      fi''
  ) (lib.attrNames projectMcpServers);

  codexLoginBlock =
    if !codexEnabled || codexLoginLines == "" then ""
    else ''

      if command -v codex >/dev/null 2>&1; then
        codex_mcp_list="$(codex mcp list 2>/dev/null || true)"
      ${codexLoginLines}
      fi'';

  shellHook = ''
    envFile="$HOME/.local/share/dev-shells/${projectId}/env.sh"
    [ -r "$envFile" ] && . "$envFile"${claudeAddBlock}${codexLoginBlock}
  '';

  flakeContent = pkgs.replaceVars ./templates/node-project.flake.nix {
    inherit shellHook;
    nixpkgsRev = inputs.nixpkgs.rev;
    system = pkgs.stdenv.hostPlatform.system;
    packages = lib.concatStringsSep " " flakePackages;
  };

  envrcContent = pkgs.writeText ".envrc"
    "use flake ~/.local/share/dev-shells/${projectId}\n";

  emdashConfig = pkgs.writeText ".emdash.json" (builtins.toJSON {
    preservePatterns = [
      ".env"
      ".env.local"
      ".envrc"
      ".claude/.custom/**"
      ".claude/.custom-autoload/**"
    ];
    shellSetup = ''eval "$(direnv export bash)"'';
    scripts = {
      setup = "direnv allow . && direnv exec . yarn install --frozen-lockfile && direnv exec . yarn gitnexus-analyze --skip-agents-md";
      run = "";
      teardown = "";
    };
  });

  # Per-project config.toml store path: base module settings/typed knobs +
  # host-global mcpServers + this project's mcpServers, in one file.
  codexProjectConfig =
    if codexEnabled then codexCfg._lib.renderConfigToml projectMcpServers
    else null;
in
{
  # Unquoted heredoc expands $CORP_* refs (populated by keepassSecretsExtract)
  # at write time — env.sh and the per-project Codex config.toml both rely
  # on that, so the DAG must order us after those secrets are in the env.
  home.activation."corpSidecar_${attrSafeId}" =
    lib.hm.dag.entryAfter [ "writeBoundary" "keepassSecretsExtract" ] ''
      $DRY_RUN_CMD install -d -m 0755 "$HOME/.local/share/dev-shells/${projectId}"
      $DRY_RUN_CMD install -m 0644 -T ${flakeContent} "$HOME/.local/share/dev-shells/${projectId}/flake.nix"
      $DRY_RUN_CMD install -m 0644 -T ${emdashConfig} "$HOME/.local/share/dev-shells/${projectId}/.emdash.json"
      $DRY_RUN_CMD install -m 0644 -T ${envrcContent} "$HOME/.local/share/dev-shells/${projectId}/.envrc"

      tmpEnv="$(mktemp)"
      cat > "$tmpEnv" <<ENV_EOF
      ${envExports}ENV_EOF
      $DRY_RUN_CMD install -m 0600 -T "$tmpEnv" "$HOME/.local/share/dev-shells/${projectId}/env.sh"
      $DRY_RUN_CMD rm -f "$tmpEnv"

      # Real files (not symlinks) so emdash preservePatterns copies them into worktrees.
      if [ -d "$HOME/git/${projectId}" ]; then
        for f in .emdash.json .envrc; do
          rm -f "$HOME/git/${projectId}/$f"
          $DRY_RUN_CMD install -m 0644 -T \
            "$HOME/.local/share/dev-shells/${projectId}/$f" \
            "$HOME/git/${projectId}/$f"
        done
      fi
    ${lib.optionalString codexEnabled ''

      # Per-project Codex home. config.toml is rendered by codex.nix's _lib
      # with this project's mcpServers merged in; base_url placeholder in
      # `settings` (e.g. __CORP_CODEX_BASE_URL__) is substituted here from
      # the corresponding $CORP_* env var populated by keepassSecretsExtract.
      $DRY_RUN_CMD install -d -m 0700 "${codexHomeDir}"
      if [ -z "''${CORP_CODEX_BASE_URL:-}" ]; then
        echo "warn: CORP_CODEX_BASE_URL unset — skipping ${projectId} Codex config write" >&2
      else
        tmpCodex="$(mktemp)"
        ${pkgs.gnused}/bin/sed "s|__CORP_CODEX_BASE_URL__|$CORP_CODEX_BASE_URL|g" \
          ${codexProjectConfig} > "$tmpCodex"
        $DRY_RUN_CMD install -m 0600 -T "$tmpCodex" "${codexHomeDir}/config.toml"
        $DRY_RUN_CMD rm -f "$tmpCodex"
      fi

      # Share the single ~/.codex/auth.json across all per-project homes,
      # so one `codex login --with-api-key` covers every project.
      $DRY_RUN_CMD ln -sfn "$HOME/.codex/auth.json" "${codexHomeDir}/auth.json"
    ''}
    '';

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
