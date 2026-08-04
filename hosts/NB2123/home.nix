#
# NB2123 home-manager configuration (user-level)
#
{ config, lib, pkgs, private, ... }:
let
  keepassxcCli = pkgs.keepassxc.passthru.cli;
  vaultPath = "${config.home.homeDirectory}/.config/dotfiles/vault.kdbx";
  # env var name → KDBX entry path (Password attribute).
  corpSecrets = {
    CORP_ANTHROPIC_JWT              = "corp/anthropic-jwt";
    CORP_ANTHROPIC_BASE_URL         = "corp/anthropic-base-url";
    CORP_AZURE_DEVOPS_MCP           = "corp/azure-devops-mcp";
    CORP_AZURE_DEVOPS_NPMRC         = "corp/azure-devops-npmrc";
    CORP_AZURE_DEVOPS_RELEASE_TOKEN = "corp/azure-devops-release-token";
    CORP_CODEX_API_KEY              = "corp/codex-api-key";
    CORP_CODEX_BASE_URL             = "corp/codex-base-url";
    CORP_ATLASSIAN_TOKEN            = "corp/atlassian-token";
    CORP_CONFLUENCE_TOKEN           = "corp/confluence-token";
    CORP_TEMPO_TOKEN                = "corp/tempo-token";
    CORP_ROVO_TOKEN                 = "corp/rovo-token";
    CORP_WSO2_TECH_PASSWORD_TST     = "corp/wso2-tech-password-tst";
    CORP_WSO2_TECH_PASSWORD_ITG     = "corp/wso2-tech-password-itg";
    CORP_PHRASE_ACCESS_TOKEN        = "corp/phrase-access-token";
    CORP_FIGMA_ACCESS_TOKEN         = "corp/figma-access-token";
  };

  # Corp Claude Code marketplaces + plugin picks, sourced from private.nix.
  # `programs.claude-code.plugins` is either-attrset-or-list; the base module
  # in modules/home/development/claude-code.nix defines an attrset, so this
  # override must too — the two forms can't merge.
  corpMarketplaces = lib.mapAttrs (_: cfg: fetchGit cfg)
    (private.claude.marketplaces or { });
  corpPlugins = lib.listToAttrs (map
    (p: {
      name = p.name or (baseNameOf p.path);
      value = "${corpMarketplaces.${p.marketplace}}/${p.path}";
    })
    (private.claude.plugins or [ ]));
in
{
  home.stateVersion = "25.05";

  imports = [
    ../../modules/home
    ./registries.nix              # NB2123-only npm/yarn corp registries
  ];

  home.apps = {
    development = {
      direnv.enable = true;
      ghostty.enable = true;
      git.enable = true;
      podman.enable = true;
      zed.enable = true;

      # Public env only; JWT + base URL injected at activation time from
      # KeePassXC (see home.activation.claudeCodeCorpSecrets below).
      claude-code = {
        enable = true;
        env = {
          ANTHROPIC_MODEL = "claude-opus-4-7[1m]";
          ANTHROPIC_DEFAULT_SONNET_MODEL = "claude-opus-4-7[1m]";
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
          model_providers.openai-proxy = {
            name = "OpenAI via Node proxy (Codex) -> AID ITG";
            base_url = "$CORP_CODEX_BASE_URL";
            wire_api = "responses";
            supports_websockets = false;
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
          '.env.ANTHROPIC_AUTH_TOKEN = $jwt | .env.ANTHROPIC_BASE_URL = $baseUrl' \
          "$settingsPath" > "$tmp"
        $DRY_RUN_CMD mv "$tmp" "$settingsPath"
      else
        echo "warn: CORP_ANTHROPIC_JWT unset — settings.json not patched" >&2
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

  # Corp marketplaces/plugins are appended to the ones declared in
  # modules/home/development/claude-code.nix
  programs.claude-code = {
    marketplaces = corpMarketplaces;
    plugins      = corpPlugins;
  };

  programs.git.settings = {
    # Corp CA for VPN HTTPS (cert-bundle.nix is host-scoped).
    http.sslCAInfo = "/etc/nix/cert-bundle.pem";
    # Per-org credential scoping for ADO — without useHttpPath, every org
    # under dev.azure.com shares one credential.
    credential."https://dev.azure.com".useHttpPath = true;
  };
}
