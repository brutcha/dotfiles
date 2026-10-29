{ pkgs, lib, inputs, project, private, config }:
# Per-project direnv sidecar. Instantiated from ./default.nix per private.projects entry.
let
  projectId = project.projectId;
  flakePackages = project.packages;

  # Sanitize dots/dashes for use as a home.activation attribute name.
  attrSafeId = builtins.replaceStrings [ "." "-" ] [ "_" "_" ] projectId;

  codexCfg = config.home.apps.development.codex;
  codexEnabled = codexCfg.enable;
  # Hashed, not nested under projectId — the app-server control socket lives
  codexHomeDir = "${config.home.homeDirectory}/.codex-home/${builtins.substring 0 12 (builtins.hashString "sha256" projectId)}";

  claudeEnabled = config.home.apps.development.claude-code.enable;
  claudeHomeDir = "${config.home.homeDirectory}/.local/share/dev-shells/${projectId}/claude";

  projectMcpServers = project.mcpServers or { };
  # { "<plugin>@<marketplace>" = { <userConfigKey> = "$CORP_FOO" | "literal"; }; }
  projectPluginUserConfig = project.pluginUserConfig or { };

  projectClaudePlugins = project.claudePlugins or [];
  # discardContext: the derived string carries a store-path dependency that
  # activation strings (non-derivation) aren't allowed to hold.
  readMarketplaceName = mpPath:
    builtins.unsafeDiscardStringContext
      (builtins.fromJSON (builtins.readFile "${mpPath}/.claude-plugin/marketplace.json")).name;
  readPluginVersion = p:
    let jp = "${toString p}/plugin.json"; in
    if builtins.pathExists jp
    then builtins.unsafeDiscardStringContext
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
  # Read-only fetchGit store path, used only for eval-time metadata reads.
  projectMarketplaceRoot =
    if projectClaudePlugins != []
    then dirOf (dirOf (toString (builtins.head projectClaudePlugins)))
    else null;
  projectMarketplaceName =
    if projectMarketplaceRoot != null
    then readMarketplaceName projectMarketplaceRoot
    else null;
  # Writable mirror (synced in corpSidecar below) that Claude/Codex register against instead.
  projectMarketplaceInstallRoot =
    if projectMarketplaceRoot != null
    then "${config.home.homeDirectory}/.local/share/corp-marketplaces/${projectMarketplaceName}"
    else null;
  # Codex uses its own plugin cache and marketplace config. The same local
  # marketplace is valid for both CLIs, but Claude's installed state is not.
  codexPluginSettings =
    if projectClaudePluginIds == [] then { } else {
      marketplaces.${projectMarketplaceName} = {
        source_type = "local";
        source = projectMarketplaceInstallRoot;
      };
      plugins = lib.genAttrs projectClaudePluginIds (_: { enabled = true; });
    };
  # Codex starts stdio MCPs outside direnv; pass only the CA variables.
  projectMcpCertificateEnv = lib.filterAttrs (name: _: builtins.elem name [
    "NODE_EXTRA_CA_CERTS"
    "SSL_CERT_FILE"
  ]) (project.env or { });
  projectMcpServersWithCertificates = lib.mapAttrs (_: server:
    if server.type or null == "stdio" then server // {
      # MCP-specific values override the project defaults.
      env = projectMcpCertificateEnv // (server.env or { });
    } else server
  ) projectMcpServers;
  # In a store file (not a shell heredoc) so an apostrophe in any mcpServers
  # value can't break the activation-time jq call. Unresolved $CORP_* refs —
  # the jq walker below resolves them.
  projectMcpServersFile = pkgs.writeText "${projectId}-mcps.json"
    (builtins.toJSON projectMcpServersWithCertificates);

  envExportsAttrs = (project.env or { })
    // lib.optionalAttrs codexEnabled  { CODEX_HOME = codexHomeDir; }
    // lib.optionalAttrs claudeEnabled {
      CLAUDE_CONFIG_DIR = claudeHomeDir;
      # Claude Code's settings.json env is trust-dialog-gated; process env isn't.
      ANTHROPIC_API_KEY = "$CORP_ANTHROPIC_JWT";
      ANTHROPIC_BASE_URL = "$CORP_ANTHROPIC_BASE_URL";
    };

  # Only `$CORP_<UPPER_SNAKE>` matches — `$HOME/foo` or `abc$def` fall through
  # to literal (avoids accidental shell interp in the emit path).
  isCorpRef = v: (builtins.match "\\$CORP_[A-Z_]+" v) != null;

  # Refs go through emit_env_ref which is nounset-safe (activation runs with
  # set -eu; an unset $CORP_* would otherwise abort the whole block).
  # Literals are single-quoted at Nix time so no shell interp happens.
  mkEnvExportLine = k: v:
    if isCorpRef v
    then ''emit_env_ref ${lib.escapeShellArg k} ${lib.escapeShellArg (builtins.substring 1 (builtins.stringLength v) v)}''
    else ''emit_env_line ${lib.escapeShellArg k} ${lib.escapeShellArg v}'';

  envExportCommands = lib.concatStringsSep "\n"
    (lib.mapAttrsToList mkEnvExportLine envExportsAttrs);

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
    "direnv allow . && direnv exec . yarn install --frozen-lockfile";

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

  emdashSetupScript = pkgs.writeScript "emdash-worktree-setup-${attrSafeId}" ''
    #!${pkgs.zsh}/bin/zsh
    setopt nullglob
    base="$HOME/git/${projectId}"
    [ "$PWD" -ef "$base" ] && exit 0
    cp "$base/.emdash.json" .emdash.json 2>/dev/null || true
    ln -sfn "$base/.claude/settings.local.json" .claude/settings.local.json
    if [ -d "$base/.devkit/personal" ]; then
      for p in .claude/.custom .claude/.custom-autoload .codex/.custom .codex/.custom-autoload; do
        [ -L "$p" ] && rm "$p"
      done
      for n in ${lib.escapeShellArgs emdashDevkitShared}; do
        [ -e "$base/.devkit/$n" ] || continue
        # A real dir/file here is worktree-local output; the migration script merges it.
        [ -e ".devkit/$n" ] && [ ! -L ".devkit/$n" ] && continue
        ln -sfn "$base/.devkit/$n" ".devkit/$n"
      done
      mkdir -p .claude/skills .agents/skills
      for d in "$base/.claude/skills/"*-custom; do
        [ -d "$d" ] || continue
        [ -e ".claude/skills/$(basename "$d")" ] || cp -r "$d" ".claude/skills/$(basename "$d")"
        [ -e ".agents/skills/$(basename "$d")" ] || cp -r "$d" ".agents/skills/$(basename "$d")"
      done
    else
      # Both CLIs need a leaf symlink for each personal skill in their own scan path.
      mkdir -p .claude/skills .agents/skills
      for d in "$base/.claude/skills/"*-custom "$base/.claude/skills/"custom-*; do
        [ -d "$d" ] || continue
        ln -sfn "$d" ".claude/skills/$(basename "$d")"
        [ -e ".agents/skills/$(basename "$d")" ] || \
          ln -sfn "$d" ".agents/skills/$(basename "$d")"
      done
      mkdir -p .codex
      ln -sfn "$base/.codex/.custom"          .claude/.custom
      ln -sfn "$base/.codex/.custom-autoload" .claude/.custom-autoload
      ln -sfn "$base/.codex/.custom"          .codex/.custom
      ln -sfn "$base/.codex/.custom-autoload" .codex/.custom-autoload
    fi
  '';

  emdashScriptsSetup = ''${emdashSetupScript} && ${projectScriptsSetup}'';

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
      # Skip install (and its mtime bump) when bytes are unchanged. Direnv
      # keys off flake.nix mtime for staleness — churn-free rebuild avoids
      # a multi-second nix print-dev-env on next `cd`.
      # Args: $1 = mode  $2 = src  $3 = dst
      _install_if_changed() {
        if [ -f "$3" ] && ${pkgs.diffutils}/bin/cmp -s "$2" "$3"; then
          $DRY_RUN_CMD chmod "$1" "$3" 2>/dev/null || true
        else
          $DRY_RUN_CMD install -m "$1" -T "$2" "$3"
        fi
      }

      # Refuses newlines, single-quote-wraps the value so nothing in a KDBX
      # token can break env.sh on source.
      emit_env_line() {
        local val="$2"
        case "$val" in
          *$'\n'*|*$'\r'*)
            echo "warn: env $1 contains a newline — skipping env.sh emit" >&2
            return 0
            ;;
        esac
        # Trailing 3 apostrophes = Nix escape for 2 + one more from sed.
        val="$(printf '%s' "$val" | ${pkgs.gnused}/bin/sed "s/'/'\\\\'''/g")"
        printf "export %s='%s'\n" "$1" "$val"
      }

      # Wraps emit_env_line for $CORP_* refs so an unset var doesn't abort
      # the whole activation under set -u; warns and skips instead.
      # Args: $1 = key to emit  $2 = source env var name (no `$` prefix)
      emit_env_ref() {
        if [ -z "''${!2+set}" ]; then
          echo "warn: env var $2 unset — skipping env.sh key $1" >&2
          return 0
        fi
        emit_env_line "$1" "''${!2}"
      }

      $DRY_RUN_CMD install -d -m 0755 "$HOME/.local/share/dev-shells/${projectId}"
      _install_if_changed 0644 ${flakeContent} "$HOME/.local/share/dev-shells/${projectId}/flake.nix"
      _install_if_changed 0644 ${emdashConfig} "$HOME/.local/share/dev-shells/${projectId}/.emdash.json"
      _install_if_changed 0644 ${envrcContent} "$HOME/.local/share/dev-shells/${projectId}/.envrc"

      _tmpEnv="$(mktemp)"
      {
        ${envExportCommands}
      } > "$_tmpEnv"
      _install_if_changed 0600 "$_tmpEnv" "$HOME/.local/share/dev-shells/${projectId}/env.sh"
      $DRY_RUN_CMD rm -f "$_tmpEnv"

      # Real files (not symlinks) so emdash preservePatterns copies them into
      # worktrees.
      if [ -d "$HOME/git/${projectId}" ]; then
        for f in .emdash.json .envrc; do
          src="$HOME/.local/share/dev-shells/${projectId}/$f"
          dst="$HOME/git/${projectId}/$f"
          if [ -e "$dst" ] && [ ! -L "$dst" ] && ${pkgs.diffutils}/bin/cmp -s "$src" "$dst"; then
            $DRY_RUN_CMD chmod 0644 "$dst" 2>/dev/null || true
          else
            $DRY_RUN_CMD rm -f "$dst"
            $DRY_RUN_CMD install -m 0644 -T "$src" "$dst"
          fi
        done
      fi
    ${lib.optionalString (projectMarketplaceRoot != null) ''

      # No --delete: plugin-written files aren't in source and must survive rebuilds.
      $DRY_RUN_CMD install -d -m 0755 "${projectMarketplaceInstallRoot}"
      $DRY_RUN_CMD ${pkgs.rsync}/bin/rsync -a --chmod=Du+w,Fu+w \
        "${projectMarketplaceRoot}/" "${projectMarketplaceInstallRoot}/"
    ''}
    ${lib.optionalString codexEnabled ''

      # envsubst is passed an explicit $CORP_* allowlist so unset refs stay
      # literal (fails loudly at Codex startup) and unrelated $literals in
      # TOML values are untouched.
      $DRY_RUN_CMD install -d -m 0700 "${codexHomeDir}"
      _tmpCodex="$(mktemp)"
      corpVars=""
      for v in ''${!CORP_*}; do corpVars="$corpVars \$$v"; done
      ${pkgs.gettext}/bin/envsubst "$corpVars" < ${codexProjectConfig} > "$_tmpCodex"
      _install_if_changed 0600 "$_tmpCodex" "${codexHomeDir}/config.toml"
      $DRY_RUN_CMD rm -f "$_tmpCodex"

      # One ~/.codex/auth.json shared by all per-project homes.
      $DRY_RUN_CMD ln -sfn "$HOME/.codex/auth.json" "${codexHomeDir}/auth.json"
    ''}
    ${lib.optionalString claudeEnabled ''

      # settings.json snapshot must come after claudeCodeCorpSecrets/rtkInit
      # (see entryAfter above) — that's what populates env + JWT + RTK hook
      # in the source file.
      $DRY_RUN_CMD install -d -m 0700 "${claudeHomeDir}"
      if [ -f "$HOME/.claude/settings.json" ]; then
        _install_if_changed 0600 "$HOME/.claude/settings.json" "${claudeHomeDir}/settings.json"
      else
        echo "warn: ~/.claude/settings.json missing — skipping ${projectId} Claude snapshot" >&2
      fi

      # Bake project.mcpServers into .claude.json.mcpServers (Claude has no
      # runtime env-var indirection). Missing env refs abort via jq error(),
      # keeping any prior on-disk value rather than baking `Authorization: ""`.
      claudeJson="${claudeHomeDir}/.claude.json"
      _tmpClaude="$(mktemp)"
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
            "$claudeJson" > "$_tmpClaude"
        else
          ${pkgs.jq}/bin/jq -n --argjson mcps "$claudeMcps" '{mcpServers: $mcps}' \
            > "$_tmpClaude"
        fi
        _install_if_changed 0600 "$_tmpClaude" "$claudeJson"
      else
        echo "warn: ${projectId} MCP snapshot skipped — jq walker failed (likely a \$CORP_* env unset; prior $claudeJson left in place)" >&2
      fi
      $DRY_RUN_CMD rm -f "$_tmpClaude"

      for name in CLAUDE.md RTK.md plugins; do
        if [ -e "$HOME/.claude/$name" ]; then
          $DRY_RUN_CMD ln -sfn "$HOME/.claude/$name" "${claudeHomeDir}/$name"
        fi
      done

      # Break any prior blanket symlink to ~/.claude/skills — ln/mkdir would
      # write through it and leak per-project plugins into the shared dir.
      if [ -L "${claudeHomeDir}/skills" ]; then
        $DRY_RUN_CMD rm "${claudeHomeDir}/skills"
      fi
      $DRY_RUN_CMD install -d -m 0755 "${claudeHomeDir}/skills"
      # Prune leftover plugin copies and stale /nix/store symlinks — plugins
      # now install properly via `claude plugin install`.
      for _f in "${claudeHomeDir}/skills"/*; do
        if [ -L "$_f" ]; then
          case "$(readlink "$_f")" in
            /nix/store/*) $DRY_RUN_CMD rm "$_f" ;;
          esac
        elif [ -d "$_f" ] && [ -f "$_f/.nix-source" ]; then
          $DRY_RUN_CMD rm -rf "$_f"
        fi
      done 2>/dev/null || true
    ''}
    '';

  # Keep emdash's DB row in sync with the Nix-declared settings. Personal_config
  # schema forbids shellSetup, so we sync scripts.setup + preservePatterns only.
  # Function + `|| true` so return-on-skip and sqlite failures can't cascade
  # into the outer set -e activation.
  home.activation."emdashDbSync_${attrSafeId}" =
    lib.hm.dag.entryAfter [ "corpSidecar_${attrSafeId}" ] ''
      _emdash_db_sync_${attrSafeId}() {
        local db projPath projPathSql wsId currentPc newPc newPcSql changed
        local expected_pp expected_scripts_setup
        db="$HOME/Library/Application Support/emdash/workspace-registry.db"
        [ -f "$db" ] || return 0

        # Doubles apostrophes for SQL single-quoted literals.
        _sqlq() {
          printf '%s' "$1" | ${pkgs.gnused}/bin/sed "s/'/'''/g"
        }

        projPath="$HOME/git/${projectId}"
        projPathSql="$(_sqlq "$projPath")"

        wsId="$(${pkgs.sqlite}/bin/sqlite3 "$db" \
          "SELECT id FROM workspace_records WHERE path = '$projPathSql' AND kind = 'repository';" \
          2>/dev/null)" || return 0
        [ -n "$wsId" ] || return 0

        expected_pp='${builtins.toJSON emdashPreservePatterns}'
        expected_scripts_setup=${lib.escapeShellArg emdashScriptsSetup}

        currentPc="$(${pkgs.sqlite}/bin/sqlite3 "$db" \
          "SELECT COALESCE(personal_config, ''') FROM workspace_records WHERE id = '$(_sqlq "$wsId")';" \
          2>/dev/null)" || return 0
        [ -n "$currentPc" ] || currentPc='{}'

        # Preserves user-set env / autoRun* / other script slots in .value.
        if ! newPc="$(printf '%s' "$currentPc" | ${pkgs.jq}/bin/jq -c \
          --argjson pp "$expected_pp" \
          --arg su "$expected_scripts_setup" \
          '{version: "2",
            value: ((.value // {})
                    | .preservePatterns = $pp
                    | .scripts = ((.scripts // {}) | .setup = $su))}')"; then
          echo "warn: emdash DB sync for ${projectId} could not parse existing personal_config — skipping" >&2
          return 0
        fi

        [ "$newPc" = "$currentPc" ] && return 0

        # This activation only reaches this line on darwin (the DB check
        # above short-circuits on Linux — emdash's app-support path is mac-
        # specific), so /usr/bin/pgrep is safe to hardcode.
        if /usr/bin/pgrep -qf '/Applications/[Ee]mdash.app'; then
          echo "warn: emdash running during ${projectId} DB sync — quit + rebuild if the new values don't stick" >&2
        fi

        newPcSql="$(_sqlq "$newPc")"
        # Bump updated_at (epoch millis) so emdash's in-memory cache invalidates.
        local sql="UPDATE workspace_records
                   SET personal_config = '$newPcSql',
                       updated_at = (strftime('%s','now') * 1000)
                   WHERE id = '$(_sqlq "$wsId")';
                   SELECT changes();"

        if [ -n "''${DRY_RUN_CMD:-}" ]; then
          $DRY_RUN_CMD ${pkgs.sqlite}/bin/sqlite3 "$db" "$sql"
          return 0
        fi

        if ! changed="$(${pkgs.sqlite}/bin/sqlite3 "$db" "$sql" 2>/dev/null)"; then
          echo "warn: emdash DB sync for ${projectId} failed — will retry on next rebuild" >&2
          return 0
        fi
        if [ "$changed" != "1" ]; then
          echo "warn: emdash DB sync for ${projectId} affected $changed rows — will retry on next rebuild" >&2
          return 0
        fi
        echo "emdash: synced ${projectId} personal settings" >&2
      }
      _emdash_db_sync_${attrSafeId} || true
    '';

  # Bake managed tokens into every .env.local (base + worktrees). Scripts
  # that read tokens via bare dotenv or dotenv.config({override: true}) don't
  # expand ${VAR}, so the literal has to be in the file directly. Non-managed
  # lines (manual literals, generated URL blocks, comments) pass through.
  home.activation."envLocalSync_${attrSafeId}" =
    lib.hm.dag.entryAfter [ "corpSidecar_${attrSafeId}" ] ''
      _env_local_sync_${attrSafeId}() {
        local envShPath envLocalPath tmp managedKeys
        envShPath="$HOME/.local/share/dev-shells/${projectId}/env.sh"
        [ -f "$envShPath" ] || return 0
        managedKeys='${lib.concatStringsSep " " envLocalManagedKeys}'
        [ -n "$managedKeys" ] || return 0

        shopt -s nullglob
        # Two worktree layouts: pre-1.2.6 `<project>/emdash/<name>/` and
        # 1.2.6+ `<project>-<hash>/emdash-<name>/`. Both may coexist.
        for envLocalPath in \
          "$HOME/git/${projectId}/.env.local" \
          "$HOME/emdash/worktrees/${projectId}/emdash/"*/.env.local \
          "$HOME/emdash/worktrees/${projectId}-"*/emdash-*/.env.local; do
          [ -f "$envLocalPath" ] || continue

          # install -T would rename over the target — a symlinked .env.local
          # would clobber whatever it points at (potentially another repo).
          if [ -L "$envLocalPath" ]; then
            echo "warn: skipping symlinked $envLocalPath" >&2
            continue
          fi

          # Unconditional: close any out-of-band widened mode even on no-op runs.
          $DRY_RUN_CMD chmod 0600 "$envLocalPath" 2>/dev/null || true

          tmp="$(mktemp)" || continue
          # Only env.sh's stderr is silenced (source-time noise from any
          # non-fatal shell warnings); awk warnings (clobber, newline,
          # appended-key info) stay visible via /dev/stderr writes.
          if (
            set +u
            . "$envShPath" 2>/dev/null
            ${pkgs.gawk}/bin/awk \
                -v KEYS="$managedKeys" \
                -v ENVFILE="$envLocalPath" '
              BEGIN {
                split(KEYS, k, " ")
                for (i in k) { managed[k[i]] = 1; unseen[k[i]] = 1 }
              }
              {
                eq = index($0, "=")
                if (eq == 0) { print; next }
                key = substr($0, 1, eq-1)
                oldval = substr($0, eq+1)
                if (!(key in managed)) { print; next }
                delete unseen[key]
                newval = ENVIRON[key]
                if (newval == "") { print; next }
                if (index(newval, "\n") > 0 || index(newval, "\r") > 0) {
                  print "warn: env " key " has embedded newline; keeping current line in " ENVFILE > "/dev/stderr"
                  print
                  next
                }
                refPattern = "${"$"}{" key "}"
                if (oldval != "" && oldval != newval && oldval != refPattern) {
                  # Length only — never log the secret itself.
                  print "warn: clobbering manual edit to " key " (" length(oldval) " chars) in " ENVFILE > "/dev/stderr"
                }
                print key "=" newval
              }
              END {
                # Append managed keys that never appeared in the file so
                # bare dotenv scripts can see them.
                for (key in unseen) {
                  newval = ENVIRON[key]
                  if (newval == "") continue
                  if (index(newval, "\n") > 0 || index(newval, "\r") > 0) {
                    print "warn: env " key " has embedded newline; not appended to " ENVFILE > "/dev/stderr"
                    continue
                  }
                  print key "=" newval
                  print "info: appended missing managed key " key " to " ENVFILE > "/dev/stderr"
                }
              }
            ' "$envLocalPath"
          ) > "$tmp"; then
            if ! ${pkgs.diffutils}/bin/cmp -s "$tmp" "$envLocalPath"; then
              $DRY_RUN_CMD install -m 0600 -T "$tmp" "$envLocalPath"
              echo "env.local: synced managed tokens in $envLocalPath" >&2
            fi
          fi
          $DRY_RUN_CMD rm -f "$tmp"
        done
      }
      _env_local_sync_${attrSafeId} || true
    '';

  # Populate Codex's per-project plugin cache from the marketplace already
  # declared in its generated config.toml. `plugin add` refreshes an existing
  # install when the marketplace version changes.
  home.activation."codexPluginSync_${attrSafeId}" =
    lib.hm.dag.entryAfter [ "corpSidecar_${attrSafeId}" ] (
      lib.optionalString (codexEnabled && projectClaudePluginIds != []) ''
      (
        export CODEX_HOME="${codexHomeDir}"
        codexBin="${pkgs.codex}/bin/codex"
        ${lib.concatMapStringsSep "\n" (pluginId: ''
          $DRY_RUN_CMD "$codexBin" plugin add ${lib.escapeShellArg pluginId} --json >/dev/null \
            || echo "warn: codex plugin add ${pluginId} failed" >&2
        '') projectClaudePluginIds}
      )
    '');

  # Patch known_marketplaces.json to the current fetchGit path (otherwise
  # Claude pins to the first-registered store path), then `plugin install`
  # each entry at user scope — idempotent, applies userConfig on the way.
  home.activation."claudePluginSync_${attrSafeId}" =
    lib.hm.dag.entryAfter [ "corpSidecar_${attrSafeId}" ] (
      lib.optionalString (claudeEnabled && projectClaudePluginIds != []) ''
      _claude_plugin_sync_${attrSafeId}() {
        local claudeBin envFile kmJson tmp
        # Absolute path — activation PATH doesn't include ~/.nix-profile so `command -v claude` returns empty and the sync silently no-ops.
        claudeBin="${config.programs.claude-code.package}/bin/claude"
        [ -x "$claudeBin" ] || return 0
        export CLAUDE_CONFIG_DIR="${claudeHomeDir}"

        kmJson="${claudeHomeDir}/plugins/known_marketplaces.json"
        if [ -f "$kmJson" ]; then
          tmp="$(mktemp)"
          ${pkgs.jq}/bin/jq \
            --arg n ${lib.escapeShellArg projectMarketplaceName} \
            --arg p ${lib.escapeShellArg projectMarketplaceInstallRoot} \
            '.[$n].source.path = $p | .[$n].installLocation = $p' \
            "$kmJson" > "$tmp"
          if ! ${pkgs.diffutils}/bin/cmp -s "$tmp" "$kmJson"; then
            $DRY_RUN_CMD install -m 0644 -T "$tmp" "$kmJson"
          fi
          $DRY_RUN_CMD rm -f "$tmp"
        fi

        # Prune stale `extraKnownMarketplaces` entries in ~/.claude/settings.json — nix-store paths there pin to an old fetchGit result and duplicate what we patch into known_marketplaces.json, giving Claude two "same-name" marketplaces and a stale plugin-panel version.
        _settingsJson="$HOME/.claude/settings.json"
        if [ -f "$_settingsJson" ]; then
          _tmp="$(mktemp)"
          ${pkgs.jq}/bin/jq '
            if (.extraKnownMarketplaces | type) == "object" then
              .extraKnownMarketplaces |= (
                to_entries
                | map(select(
                    (.value.source.source != "directory")
                    or ((.value.source.path // "") | startswith("/nix/store/") | not)
                  ))
                | from_entries
              )
              | if .extraKnownMarketplaces == {} then del(.extraKnownMarketplaces) else . end
            else . end' "$_settingsJson" > "$_tmp"
          if ! ${pkgs.diffutils}/bin/cmp -s "$_tmp" "$_settingsJson"; then
            $DRY_RUN_CMD install -m 0600 -T "$_tmp" "$_settingsJson"
          fi
          $DRY_RUN_CMD rm -f "$_tmp"
        fi

        # Refresh plugin-catalog-cache.json — `plugin update` reads the cached catalog, so stale entries here mask new marketplace versions.
        $DRY_RUN_CMD "$claudeBin" plugin marketplace update ${lib.escapeShellArg projectMarketplaceName} >/dev/null 2>&1 || true

        envFile="$HOME/.local/share/dev-shells/${projectId}/env.sh"
        # Subshell keeps sourced CORP_* refs out of the outer activation env.
        (
          set +u
          [ -f "$envFile" ] && . "$envFile" 2>/dev/null

          ${lib.concatMapStringsSep "\n" (spec:
            let pluginId = spec.id;
                pluginName = spec.name;
                marketplaceName = spec.marketplace;
                expectedVersion = spec.version;
                cachePrefix = "${claudeHomeDir}/plugins/cache/${marketplaceName}/${pluginName}/";
                newInstallPath = "${cachePrefix}${expectedVersion}";
                cfg = projectPluginUserConfig.${pluginId} or {};
                argLines = lib.concatMapStringsSep "\n" (key:
                  let v = cfg.${key}; in
                    if isCorpRef v then
                      let varName = builtins.substring 1 (builtins.stringLength v) v; in ''
                        if [ -n "''${${varName}+set}" ]; then
                          _cfg+=( --config ${lib.escapeShellArg "${key}="}"''${${varName}}" )
                        else
                          echo "warn: env var ${varName} unset — skipping ${pluginId}.${key} sync" >&2
                          _skip=1
                        fi
                      ''
                    else
                      ''_cfg+=( --config ${lib.escapeShellArg "${key}=${v}"} )''
                ) (builtins.attrNames cfg);
            in ''
              _cfg=()
              _skip=0
              ${argLines}
              if [ "$_skip" = 0 ]; then
                # `plugin install` never upgrades in place; `update` is idempotent (no-op when at latest or not installed).
                $DRY_RUN_CMD "$claudeBin" plugin update ${lib.escapeShellArg pluginId} \
                  -s user -y >/dev/null 2>&1 || true
                # Install runs after update to (re)apply --config — update has no --config flag.
                $DRY_RUN_CMD "$claudeBin" plugin install ${lib.escapeShellArg pluginId} \
                  -s user -y "''${_cfg[@]}" --json >/dev/null 2>&1 \
                  || echo "warn: claude plugin install ${pluginId} failed" >&2

                # Bump stale local/project-scope pins under this project's cache — both win over user scope, so old worktree pins mask the fresh user-scope version.
                _installedJson="${claudeHomeDir}/plugins/installed_plugins.json"
                if [ -n ${lib.escapeShellArg expectedVersion} ] \
                    && [ -d ${lib.escapeShellArg newInstallPath} ] \
                    && [ -f "$_installedJson" ]; then
                  _tmp=$(${pkgs.coreutils}/bin/mktemp)
                  ${pkgs.jq}/bin/jq \
                    --arg id ${lib.escapeShellArg pluginId} \
                    --arg v ${lib.escapeShellArg expectedVersion} \
                    --arg np ${lib.escapeShellArg newInstallPath} \
                    --arg prefix ${lib.escapeShellArg cachePrefix} \
                    '.plugins[$id] |= (map(
                      if (.scope == "local" or .scope == "project")
                          and (.version != $v)
                          and ((.installPath // "") | startswith($prefix))
                      then .version = $v
                         | .installPath = $np
                         | .lastUpdated = (now | todateiso8601)
                      else . end))' \
                    "$_installedJson" > "$_tmp"
                  if ! ${pkgs.diffutils}/bin/cmp -s "$_tmp" "$_installedJson"; then
                    $DRY_RUN_CMD install -m 0644 -T "$_tmp" "$_installedJson"
                  fi
                  $DRY_RUN_CMD rm -f "$_tmp"
                fi
              fi
            ''
          ) projectClaudePluginSpecs}
        )
      }
      _claude_plugin_sync_${attrSafeId} || true
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
