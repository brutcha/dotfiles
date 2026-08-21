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
  '';

  flakeContent = pkgs.replaceVars ./templates/node-project.flake.nix {
    inherit shellHook;
    nixpkgsRev = inputs.nixpkgs.rev;
    system = pkgs.stdenv.hostPlatform.system;
    packages = lib.concatStringsSep " " flakePackages;
  };

  envrcContent = pkgs.writeText ".envrc"
    "use flake ~/.local/share/dev-shells/${projectId}\n";

  # Emdash treats its SQLite DB as authoritative post-migration; the
  # `.emdash.json` file below is for documentation / first-import bootstrap
  # only. The emdashDbSync activation is what actually shapes emdash's
  # behavior for these projects.

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
  emdashShellSetup = ''. "$HOME/.local/share/dev-shells/${projectId}/env.sh"'';

  # scripts.setup runs once at worktree creation. Always prefixed with the
  # `.emdash.json` copy (which emdash's preservePatterns filter drops); then
  # the per-project setup from private.nix. Default installs deps if the
  # project doesn't override.
  projectScriptsSetup = project.scriptsSetup or
    "direnv allow . && direnv exec . yarn install --frozen-lockfile";

  # Both `.claude/.custom*` and `.codex/.custom*` symlinked — Claude writes to
  # the former, repo skills write to the latter. Missing either → real dirs on
  # first write → drift.
  emdashScriptsSetup =
    ''cp "$HOME/git/${projectId}/.emdash.json" .emdash.json 2>/dev/null || true; ''
    + ''mkdir -p .claude .codex; ''
    + ''ln -sfn "$HOME/git/${projectId}/.codex/.custom"          .claude/.custom; ''
    + ''ln -sfn "$HOME/git/${projectId}/.codex/.custom-autoload" .claude/.custom-autoload; ''
    + ''ln -sfn "$HOME/git/${projectId}/.codex/.custom"          .codex/.custom; ''
    + ''ln -sfn "$HOME/git/${projectId}/.codex/.custom-autoload" .codex/.custom-autoload; ''
    + ''${projectScriptsSetup}'';

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
    if codexEnabled then codexCfg._lib.renderConfigToml projectMcpServersWithCertificates
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

      for name in CLAUDE.md RTK.md plugins skills; do
        if [ -e "$HOME/.claude/$name" ]; then
          $DRY_RUN_CMD ln -sfn "$HOME/.claude/$name" "${claudeHomeDir}/$name"
        fi
      done
    ''}
    '';

  # Keep emdash's DB row in sync with the Nix-declared shareable settings.
  # Function + `|| true` so return-on-skip and sqlite failures (busy, missing
  # row, missing file) can't cascade into the outer set -e activation.
  home.activation."emdashDbSync_${attrSafeId}" =
    lib.hm.dag.entryAfter [ "corpSidecar_${attrSafeId}" ] ''
      _emdash_db_sync_${attrSafeId}() {
        local db projRow expected_pp expected_ss expected_scripts_setup
        local projPath projPathSql ss_sql scripts_sql current expected changed
        db="$HOME/Library/Application Support/emdash/emdash4.db"
        [ -f "$db" ] || return 0

        # Doubles apostrophes for SQL single-quoted literals.
        _sqlq() {
          printf '%s' "$1" | ${pkgs.gnused}/bin/sed "s/'/'''/g"
        }

        projPath="$HOME/git/${projectId}"
        projPathSql="$(_sqlq "$projPath")"

        projRow="$(${pkgs.sqlite}/bin/sqlite3 "$db" \
          "SELECT id FROM projects WHERE path = '$projPathSql';" \
          2>/dev/null)" || return 0
        [ -n "$projRow" ] || return 0

        expected_pp='${builtins.toJSON emdashPreservePatterns}'
        expected_ss=${lib.escapeShellArg emdashShellSetup}
        expected_scripts_setup=${lib.escapeShellArg emdashScriptsSetup}
        ss_sql="$(_sqlq "$expected_ss")"
        scripts_sql="$(_sqlq "$expected_scripts_setup")"

        current="$(${pkgs.sqlite}/bin/sqlite3 "$db" \
          "SELECT json_object(
                   'preservePatterns', json_extract(shareable_project_settings_json, '\$.preservePatterns'),
                   'shellSetup',       json_extract(shareable_project_settings_json, '\$.shellSetup'),
                   'scriptsSetup',     json_extract(shareable_project_settings_json, '\$.scripts.setup'))
           FROM project_settings WHERE project_id = '$projRow';" \
          2>/dev/null)" || return 0
        expected="$(${pkgs.jq}/bin/jq -cn \
          --argjson pp "$expected_pp" \
          --arg ss "$expected_ss" \
          --arg ssu "$expected_scripts_setup" \
          '{preservePatterns:$pp, shellSetup:$ss, scriptsSetup:$ssu}')"
        [ "$current" = "$expected" ] && return 0

        # This activation only reaches this line on darwin (the DB check
        # above short-circuits on Linux — emdash's app-support path is mac-
        # specific), so /usr/bin/pgrep is safe to hardcode.
        if /usr/bin/pgrep -qf '/Applications/emdash.app'; then
          echo "warn: emdash running during ${projectId} DB sync — quit + rebuild if the new values don't stick" >&2
        fi
        # COALESCE guards against a NULL shareable_project_settings_json
        # (json_set on NULL returns NULL — would blank the field). SELECT
        # changes() reports the affected-row count so a projects-row-exists-
        # but-project_settings-row-doesn't case doesn't report success.
        local sql="UPDATE project_settings
                   SET shareable_project_settings_json =
                         json_set(COALESCE(shareable_project_settings_json, '{}'),
                                  '\$.preservePatterns', json('$expected_pp'),
                                  '\$.shellSetup',       '$ss_sql',
                                  '\$.scripts.setup',    '$scripts_sql'),
                       updated_at = datetime('now')
                   WHERE project_id = '$projRow';
                   SELECT changes();"

        if [ -n "''${DRY_RUN_CMD:-}" ]; then
          # Dry-run: report what would happen, skip the changes-check.
          $DRY_RUN_CMD ${pkgs.sqlite}/bin/sqlite3 "$db" "$sql"
          return 0
        fi

        if ! changed="$(${pkgs.sqlite}/bin/sqlite3 "$db" "$sql" 2>/dev/null)"; then
          echo "warn: emdash DB sync for ${projectId} failed — will retry on next rebuild" >&2
          return 0
        fi
        if [ "$changed" != "1" ]; then
          echo "warn: emdash DB sync for ${projectId} affected $changed rows (no project_settings row?) — will retry on next rebuild" >&2
          return 0
        fi
        echo "emdash: synced ${projectId} shareable settings" >&2
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
        for envLocalPath in \
          "$HOME/git/${projectId}/.env.local" \
          "$HOME/emdash/worktrees/${projectId}/emdash/"*/.env.local; do
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
