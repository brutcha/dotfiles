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

  claudeEnabled = config.home.apps.development.claude-code.enable;
  claudeHomeDir = "${config.home.homeDirectory}/.local/share/dev-shells/${projectId}/claude";

  projectMcpServers = project.mcpServers or { };
  # File in /nix/store (not a shell heredoc) so a mcpServers value containing
  # an apostrophe can't break the activation-time jq invocation. Contents are
  # unresolved `$CORP_*` refs — the jq walker below resolves them.
  projectMcpServersFile = pkgs.writeText "${projectId}-mcps.json"
    (builtins.toJSON projectMcpServers);

  envExportsAttrs = (project.env or { })
    // lib.optionalAttrs codexEnabled  { CODEX_HOME = codexHomeDir; }
    // lib.optionalAttrs claudeEnabled { CLAUDE_CONFIG_DIR = claudeHomeDir; };
  envExports = lib.concatStringsSep ""
    (lib.mapAttrsToList (k: v: "export ${k}=\"${v}\"\n") envExportsAttrs);

  shellHook = ''
    envFile="$HOME/.local/share/dev-shells/${projectId}/env.sh"
    [ -r "$envFile" ] && . "$envFile"
  '';

  flakeContent = pkgs.replaceVars ./templates/node-project.flake.nix {
    inherit shellHook;
    nixpkgsRev = inputs.nixpkgs.rev;
    system = pkgs.stdenv.hostPlatform.system;
    packages = lib.concatStringsSep " " flakePackages;
  };

  envrcContent = pkgs.writeText ".envrc"
    "use flake ~/.local/share/dev-shells/${projectId}\n";

  # Single source of truth for emdash `preservePatterns`. Written both into the
  # base project's `.emdash.json` (worktree-runtime fallback source) and into
  # emdash's own SQLite `project_settings` row (authoritative at worktree-
  # provisioning time). The emdashDbSync activation below keeps the DB copy in
  # sync with this list.
  # Order matches what emdash's DB carries (append-only history via
  # json_set/UI edits), so `[ "$current" = "$expected" ]` in the sync
  # activation is a no-op once initial sync has run.
  emdashPreservePatterns = [
    ".env"
    ".env.local"
    ".envrc"
    ".claude/.custom/**"
    ".claude/.custom-autoload/**"
    ".emdash.json"
  ];

  emdashConfig = pkgs.writeText ".emdash.json" (builtins.toJSON {
    preservePatterns = emdashPreservePatterns;
    shellSetup = ''. "$HOME/.local/share/dev-shells/${projectId}/env.sh"'';
    scripts = {
      setup = "direnv allow . && direnv exec . yarn install --frozen-lockfile && direnv exec . yarn gitnexus-analyze --skip-agents-md";
      run = "";
      teardown = "";
    };
  });

  codexProjectConfig =
    if codexEnabled then codexCfg._lib.renderConfigToml projectMcpServers
    else null;
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
      # with this project's mcpServers merged in. Any `$CORP_*` refs in it
      # (base_url, mcp env values, …) are substituted here from the
      # activation-time process env — populated by keepassSecretsExtract.
      #
      # envsubst is passed an explicit `$CORP_*` allowlist built from currently
      # exported vars. Unset refs stay as literal `$CORP_XXX` (fails loudly at
      # Codex startup) instead of being silently blanked, and unrelated
      # `$literals` elsewhere in TOML values are untouched.
      $DRY_RUN_CMD install -d -m 0700 "${codexHomeDir}"
      tmpCodex="$(mktemp)"
      corpVars=""
      for v in ''${!CORP_*}; do corpVars="$corpVars \$$v"; done
      ${pkgs.gettext}/bin/envsubst "$corpVars" < ${codexProjectConfig} > "$tmpCodex"
      $DRY_RUN_CMD install -m 0600 -T "$tmpCodex" "${codexHomeDir}/config.toml"
      $DRY_RUN_CMD rm -f "$tmpCodex"

      # Share the single ~/.codex/auth.json across all per-project homes,
      # so one `codex login --with-api-key` covers every project.
      $DRY_RUN_CMD ln -sfn "$HOME/.codex/auth.json" "${codexHomeDir}/auth.json"
    ''}
    ${lib.optionalString claudeEnabled ''

      # Per-project Claude home. settings.json is a straight snapshot of the
      # base ~/.claude/settings.json (which already carries env + plugins +
      # permissions + RTK hook + corp JWT via
      # claudeCodeSettings/rtkInit/claudeCodeCorpSecrets).
      # Everything else (plugins/, skills/, CLAUDE.md, RTK.md) is symlinked so
      # upstream edits propagate; sessions + caches are per-project.
      $DRY_RUN_CMD install -d -m 0700 "${claudeHomeDir}"
      if [ -f "$HOME/.claude/settings.json" ]; then
        $DRY_RUN_CMD install -m 0600 "$HOME/.claude/settings.json" "${claudeHomeDir}/settings.json"
      else
        echo "warn: ~/.claude/settings.json missing — skipping ${projectId} Claude snapshot" >&2
      fi

      # Merge per-project MCPs into <claudeHome>/.claude.json.mcpServers.
      # Two transforms per entry:
      #   1. authorization_env_var → resolved literal headers.Authorization
      #   2. env values that look like "$VAR" → resolved literal via process env
      # Claude has no runtime env-var indirection, so both are baked at activation.
      # Missing env refs abort via jq `error()` — the .claude.json write is
      # then skipped, keeping any prior on-disk value rather than corrupting it
      # with `Authorization: ""`.
      claudeJson="${claudeHomeDir}/.claude.json"
      tmpClaude="$(mktemp)"
      if claudeMcps="$(${pkgs.jq}/bin/jq -c '
        to_entries | map(
          . as $mcp
          | if .value.env then .value.env |= with_entries(
              if (.value | type == "string") and (.value | startswith("$"))
              then .value = (env[.value[1:]]
                // error("MCP \($mcp.key): env ref $\(.value[1:]) unset"))
              else . end
            ) else . end
          | if .value.authorization_env_var
            then .value |= (
              .headers = (.headers // {}) + {
                "Authorization": (env[.authorization_env_var]
                  // error("MCP \($mcp.key): authorization env $\(.authorization_env_var) unset"))
              }
              | del(.authorization_env_var)
            )
            else . end
        ) | from_entries
      ' ${projectMcpServersFile})"; then
        if [ -f "$claudeJson" ]; then
          ${pkgs.jq}/bin/jq --argjson mcps "$claudeMcps" '.mcpServers = $mcps' \
            "$claudeJson" > "$tmpClaude"
        else
          ${pkgs.jq}/bin/jq -n --argjson mcps "$claudeMcps" '{mcpServers: $mcps}' \
            > "$tmpClaude"
        fi
        $DRY_RUN_CMD install -m 0600 -T "$tmpClaude" "$claudeJson"
      else
        echo "warn: ${projectId} MCP snapshot skipped — jq walker failed (likely a \$CORP_* env unset; prior $claudeJson left in place)" >&2
      fi
      $DRY_RUN_CMD rm -f "$tmpClaude"

      for name in CLAUDE.md RTK.md plugins skills; do
        if [ -e "$HOME/.claude/$name" ]; then
          $DRY_RUN_CMD ln -sfn "$HOME/.claude/$name" "${claudeHomeDir}/$name"
        fi
      done
    ''}
    '';

  # Keep emdash's SQLite `preservePatterns` for this project in sync with the
  # Nix-declared list. Emdash uses the DB (not the base `.emdash.json`) when
  # provisioning a new worktree, so without this the list drifts and new
  # worktrees miss files like `.emdash.json` itself. Idempotent + fail-open.
  home.activation."emdashDbSync_${attrSafeId}" =
    lib.hm.dag.entryAfter [ "corpSidecar_${attrSafeId}" ] ''
      db="$HOME/Library/Application Support/emdash/emdash4.db"
      [ -f "$db" ] || exit 0                     # emdash not installed → skip
      projRow="$(${pkgs.sqlite}/bin/sqlite3 "$db" \
        "SELECT id FROM projects WHERE path = '$HOME/git/${projectId}';")"
      [ -n "$projRow" ] || exit 0                # project not imported yet → skip

      expected='${builtins.toJSON emdashPreservePatterns}'
      current="$(${pkgs.sqlite}/bin/sqlite3 "$db" \
        "SELECT json_extract(shareable_project_settings_json, '\$.preservePatterns')
         FROM project_settings WHERE project_id = '$projRow';")"
      [ "$current" = "$expected" ] && exit 0     # already in sync → no-op

      if ${pkgs.procps}/bin/pgrep -qf '/Applications/emdash.app'; then
        echo "warn: emdash running during ${projectId} DB sync — quit + rebuild if the new value doesn't stick" >&2
      fi
      $DRY_RUN_CMD ${pkgs.sqlite}/bin/sqlite3 "$db" "UPDATE project_settings
        SET shareable_project_settings_json =
              json_set(shareable_project_settings_json, '\$.preservePatterns', json('$expected')),
            updated_at = datetime('now')
        WHERE project_id = '$projRow';"
      echo "emdash: synced ${projectId} preservePatterns" >&2
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
