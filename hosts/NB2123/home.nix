#
# NB2123 home-manager configuration (user-level)
#
{ config, lib, pkgs, ... }:
let
  keepassxcCli = pkgs.keepassxc.passthru.cli;
  vaultPath = "${config.home.homeDirectory}/.config/dotfiles/vault.kdbx";
  # env var name → KDBX entry path (Password attribute).
  corpSecrets = {
    CORP_ANTHROPIC_JWT = "corp/anthropic-jwt";
    CORP_ANTHROPIC_BASE_URL = "corp/anthropic-base-url";
    CORP_AZURE_DEVOPS_MCP = "corp/azure-devops-mcp";
    CORP_AZURE_DEVOPS_NPMRC = "corp/azure-devops-npmrc";
    CORP_AZURE_DEVOPS_RELEASE_TOKEN = "corp/azure-devops-release-token";
    CORP_CODEX_API_KEY = "corp/codex-api-key";
    CORP_CODEX_BASE_URL = "corp/codex-base-url";
    CORP_ATLASSIAN_TOKEN = "corp/atlassian-token";
    CORP_CONFLUENCE_TOKEN = "corp/confluence-token";
    CORP_TEMPO_TOKEN = "corp/tempo-token";
    CORP_ROVO_TOKEN = "corp/rovo-token";
    CORP_WSO2_TECH_PASSWORD_TST = "corp/wso2-tech-password-tst";
    CORP_WSO2_TECH_PASSWORD_ITG = "corp/wso2-tech-password-itg";
    CORP_PHRASE_ACCESS_TOKEN = "corp/phrase-access-token";
    CORP_FIGMA_ACCESS_TOKEN = "corp/figma-access-token";
    CORP_DYNATRACE_PAT = "corp/dynatrace-token";
    CORP_KAGI_API_KEY = "corp/kagi-api-key";
  };
in
{
  home.stateVersion = "25.05";

  imports = [
    ../../modules/home
    ./registries.nix # NB2123-only npm/yarn corp registries
  ];

  home.apps = {
    development = {
      azure-cli.enable = true;
      direnv.enable = true;
      ghostty.enable = true;
      git.enable = true;
      podman.enable = true;
      tmux.enable = true;
      workmux.enable = true;
      zed.enable = true;

      # Public env only; JWT + base URL injected at activation time from
      # KeePassXC (see home.activation.claudeCodeCorpSecrets below).
      claude-code = {
        enable = true;
        env = {
          ANTHROPIC_MODEL = "claude-sonnet-5";
          ANTHROPIC_DEFAULT_SONNET_MODEL = "claude-sonnet-5";
          ANTHROPIC_DEFAULT_HAIKU_MODEL = "claude-haiku-4-5";
          NODE_EXTRA_CA_CERTS = "/etc/nix/cert-bundle.pem";
          CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY = "1";
          CLAUDE_CODE_API_KEY_HELPER_TTL_MS = "300000";
          ENABLE_TOOL_SEARCH = "true";
        };
      };

      # base_url $CORP_CODEX_BASE_URL ref + `codex login --with-api-key` are
      # patched in at activation by home.activation.codexCorpSecrets below.
      codex = {
        enable = true;
        settings = {
          model_provider = "openai-proxy";
          features = {
            api_key_model_discovery = true;
            daemon_auto_start = true;
            # Workmux status tracking uses Codex lifecycle hooks. Keep this
            # declarative so Home Manager does not erase the setting that the
            # interactive status-tracking installer adds to each project home.
            hooks = true;
          };
          model_providers.openai-proxy = {
            name = "OpenAI via Node proxy (Codex) -> AID ITG";
            base_url = "$CORP_CODEX_BASE_URL";
            wire_api = "responses";
            supports_websockets = false;
            http_headers = { "api-key" = "$CORP_CODEX_API_KEY"; };
          };
        };
      };
      opencode = {
        enable = true;
        configuration = {
          websearch = false;
          providers = {
            corp-anthropic = {
              name = "Corp Anthropic";
              canonical = "anthropic";
              package = "@opencode/ai/providers/anthropic";
              settings = {
                baseURL = "{file:${config.home.homeDirectory}/.local/share/opencode-nix/secrets/anthropic-base-url}/v1";
                apiKey = "{file:${config.home.homeDirectory}/.local/share/opencode-nix/secrets/anthropic-jwt}";
              };
              models = lib.genAttrs [
                "claude-haiku-4-5" "claude-haiku-5-5" "claude-opus-4-7"
                "claude-opus-4-8" "claude-opus-5" "claude-opus-5-5"
                "claude-sonnet-4-6" "claude-sonnet-5" "claude-sonnet-5-5"
              ] (_: { });
            };
            corp-openai = {
              name = "Corp OpenAI (Codex proxy)";
              canonical = "openai";
              package = "@opencode/ai/providers/azure/responses";
              settings = {
                baseURL = "{file:${config.home.homeDirectory}/.local/share/opencode-nix/secrets/codex-base-url}";
                apiKey = "{file:${config.home.homeDirectory}/.local/share/opencode-nix/secrets/codex-api-key}";
              };
              models = lib.genAttrs [
                "gpt-5.4" "gpt-5.5" "gpt-5.6-luna" "gpt-5.6-sol"
                "gpt-5.6-terra" "gpt-6-sol" "gpt-6.1-sol" "gpt-6-astra"
              ] (_: { });
            };
          };
          policies = [
            { action = "provider.use"; resource = "*"; effect = "deny"; }
            { action = "provider.use"; resource = "corp-anthropic"; effect = "allow"; }
            { action = "provider.use"; resource = "corp-openai"; effect = "allow"; }
          ];
          model = "corp-openai/gpt-5.6-terra";
          agents = {
            title.model = "corp-openai/gpt-5.6-luna";
            build.model = "corp-openai/gpt-5.6-terra";
            plan.model = "corp-openai/gpt-5.6-terra";
            general.model = "corp-openai/gpt-5.6-terra";
            explore.model = "corp-openai/gpt-5.6-terra";
          };
          mcp.servers = {
            figma = {
              type = "remote";
              url = "https://mcp.figma.com/mcp";
              headers.X-Figma-Plugin-Bundle = "figma_prod@2_2_157";
            };
            playwright = {
              type = "local";
              command = [ "${pkgs.yarn-berry}/bin/yarn" "dlx" "@playwright/mcp@latest" "--headless" ];
              codemode = false;
            };
          };
          instructions = [
            "${config.home.homeDirectory}/.config/dotfiles/opencode-devkit-port/instructions/dotfiles-rebuild.md"
            "${config.home.homeDirectory}/.config/dotfiles/opencode-devkit-port/instructions/user-shell.md"
            "${config.home.homeDirectory}/.config/dotfiles/opencode-devkit-port/instructions/dotfiles-conventions.md"
          ];
        };
        service = {
          enable = true;
          environment = {
            PATH = "/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
            NODE_EXTRA_CA_CERTS = "/etc/nix/cert-bundle.pem";
          };
        };
      };
    };

    internet.helium.enable = true;

    media.obs.enable = true;

    security.keepass.enable = true;

    # broken on this host — leave off until fixed
    windowManager = {
      aerospace.enable = false;
      jankyborders.enable = false;
      sketchybar.enable = false;
    };
  };

  # Extract corp secrets from KeePassXC at activation
  home.activation.keepassSecretsExtract =
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if [ ! -f "${vaultPath}" ]; then
        echo "warn: KeePassXC vault not found at ${vaultPath} — corp secrets not extracted" >&2
      elif ! KPXC_PWD="$(/usr/bin/security find-generic-password -a "${config.home.username}" -s kdbx-master -w 2>/dev/null)"; then
        echo "warn: 'kdbx-master' not in Keychain — corp secrets not extracted" >&2
        echo "  bootstrap: security add-generic-password -a ${config.home.username} -s kdbx-master -w '<master>' -T /usr/bin/security" >&2
      else
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (var: entry: ''
          if ${var}="$(${keepassxcCli} show -sq -a Password "${vaultPath}" "${entry}" <<< "$KPXC_PWD" 2>/dev/null)"; then
            export ${var}
          else
            echo "warn: failed to extract '${entry}' from KDBX" >&2
          fi
        '') corpSecrets)}
        unset KPXC_PWD
      fi
    '';

  # Merge corp secrets into settings.json after claude-code.nix writes it.
  home.activation.claudeCodeCorpSecrets =
    lib.hm.dag.entryAfter [ "keepassSecretsExtract" "claudeCodeSettings" ] ''
      if [ -n "''${CORP_ANTHROPIC_JWT:-}" ]; then
        settingsPath="$HOME/.claude/settings.json"
        tmp="$(mktemp)"
        ${pkgs.jq}/bin/jq \
          --arg jwt "$CORP_ANTHROPIC_JWT" \
          --arg baseUrl "$CORP_ANTHROPIC_BASE_URL" \
          '.env.ANTHROPIC_API_KEY = $jwt | .env.ANTHROPIC_BASE_URL = $baseUrl | del(.env.ANTHROPIC_AUTH_TOKEN)' \
          "$settingsPath" > "$tmp"
        $DRY_RUN_CMD mv "$tmp" "$settingsPath"
      else
        echo "warn: CORP_ANTHROPIC_JWT unset — settings.json not patched" >&2
      fi
    '';

  # OpenCode's rendered configuration references these files with `{file:...}`.
  # Keep them out of the Nix store and service environment.
  home.activation.opencodeCorpSecrets =
    lib.hm.dag.entryBetween [ "setupLaunchAgents" ] [ "keepassSecretsExtract" "opencodeConfig" ] ''
      if [ -z "''${DRY_RUN+x}" ]; then
        secretDir="$HOME/.local/share/opencode-nix/secrets"
        install -d -m 0700 "$secretDir"
        _opencode_secret() {
        local name="$1" file="$2"
        if [ -n "''${!name:-}" ]; then
          # macOS install refuses /dev/stdin after it has been replaced by a
          # pipe. Write a private sibling first, then atomically replace.
          local tmp="$secretDir/.$file.tmp.$$"
          (umask 077; printf '%s' "''${!name}" > "$tmp")
          $DRY_RUN_CMD mv "$tmp" "$secretDir/$file"
          $DRY_RUN_CMD chmod 0600 "$secretDir/$file"
        else
          echo "warn: $name unset — OpenCode secret $file not updated" >&2
        fi
        }
        _opencode_secret CORP_ANTHROPIC_JWT anthropic-jwt
        _opencode_secret CORP_ANTHROPIC_BASE_URL anthropic-base-url
        _opencode_secret CORP_CODEX_API_KEY codex-api-key
        _opencode_secret CORP_CODEX_BASE_URL codex-base-url
        _opencode_secret CORP_KAGI_API_KEY kagi-api-key

        # Rewrite the final layer after secrets so a running OpenCode instance
        # observes the completed activation state on its next reload.
        touch "$HOME/.local/share/opencode-nix/opencode.json"
      fi
    '';

  home.activation.opencodeDevkitPort =
    lib.hm.dag.entryAfter [ "opencodeConfig" "rtkOpenCodeAdapter" ] ''
      if [ -z "''${DRY_RUN+x}" ]; then
        install -d -m 0700 "$HOME/.cache/opencode-devkit-port/node_modules"
        if [ ! -e "${config.home.homeDirectory}/.config/dotfiles/opencode-devkit-port/node_modules" ] || [ -L "${config.home.homeDirectory}/.config/dotfiles/opencode-devkit-port/node_modules" ]; then
          ln -sfn "$HOME/.cache/opencode-devkit-port/node_modules" \
          "${config.home.homeDirectory}/.config/dotfiles/opencode-devkit-port/node_modules"
        fi
        ln -sfn "${config.home.homeDirectory}/.config/dotfiles/opencode-devkit-port/shim/opencode-plugin.ts" \
        "$HOME/.config/opencode/plugins/npa-hook-compat.ts"
        ln -sfn "${config.home.homeDirectory}/.config/dotfiles/opencode-devkit-port/shim/compaction-overlay-state.mjs" \
        "$HOME/.config/opencode/plugins/compaction-overlay-state.mjs"

      if [ ! -f "${config.home.homeDirectory}/.config/dotfiles/opencode-devkit-port/scripts/check-npa-drift.py" ]; then
        echo "error: OpenCode Devkit drift check is unavailable" >&2
        exit 1
      fi
      if ! driftReport="$(PATH=${pkgs.git}/bin:$PATH ${pkgs.python3}/bin/python3 \
        "${config.home.homeDirectory}/.config/dotfiles/opencode-devkit-port/scripts/check-npa-drift.py" 2>&1)"; then
        echo "error: OpenCode Devkit compatibility check failed:" >&2
        echo "$driftReport" >&2
        exit 1
      fi
      fi
    '';

  # Resolve `$VAR` refs in ~/.codex/config.toml, then run `codex login`
  home.activation.codexCorpSecrets =
    lib.hm.dag.entryAfter [ "keepassSecretsExtract" "codexBase" ] ''
      unset CODEX_HOME
      configPath="$HOME/.codex/config.toml"

      if [ -f "$configPath" ]; then
        tmp="$(mktemp)"
        # Explicit $CORP_* allowlist: unset refs stay literal (fails loudly at
        # Codex startup rather than being silently blanked), and unrelated
        # `$literals` in TOML values aren't touched.
        corpVars=""
        for v in ''${!CORP_*}; do corpVars="$corpVars \$$v"; done
        ${pkgs.gettext}/bin/envsubst "$corpVars" < "$configPath" > "$tmp"
        $DRY_RUN_CMD install -m 0600 -T "$tmp" "$configPath"
      else
        echo "warn: ~/.codex/config.toml missing — nothing to substitute" >&2
      fi

      if [ -n "''${CORP_CODEX_API_KEY:-}" ]; then
        fp="$(printf '%s' "$CORP_CODEX_API_KEY" \
          | ${pkgs.coreutils}/bin/sha256sum \
          | ${pkgs.coreutils}/bin/cut -d' ' -f1)"
        fpFile="$HOME/.codex/.dotfiles-key-fingerprint"
        if [ ! -f "$fpFile" ] || [ "$(${pkgs.coreutils}/bin/cat "$fpFile" 2>/dev/null)" != "$fp" ]; then
          printf '%s' "$CORP_CODEX_API_KEY" \
            | $DRY_RUN_CMD ${pkgs.codex}/bin/codex login --with-api-key
          $DRY_RUN_CMD sh -c "printf '%s' '$fp' > '$fpFile' && chmod 0600 '$fpFile'"
        fi
      else
        echo "warn: CORP_CODEX_API_KEY unset — skipping codex login" >&2
      fi
    '';

  programs.git.settings = {
    # Per-org credential scoping for ADO — without useHttpPath, every org
    # under dev.azure.com shares one credential.
    credential."https://dev.azure.com".useHttpPath = true;
  };
}
