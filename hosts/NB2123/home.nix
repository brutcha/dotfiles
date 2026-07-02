#
# NB2123 home-manager configuration (user-level)
#
{ config, lib, pkgs, ... }:
let
  keepassxcCli = "${pkgs.keepassxc}/Applications/KeePassXC.app/Contents/MacOS/keepassxc-cli";
  vaultPath = "${config.home.homeDirectory}/.config/dotfiles/vault.kdbx";
  # env var name → KDBX entry path (Password attribute).
  corpSecrets = {
    CORP_ANTHROPIC_JWT      = "corp/anthropic-jwt";
    CORP_ANTHROPIC_BASE_URL = "corp/anthropic-base-url";
    CORP_AZURE_DEVOPS_PAT   = "corp/azure-devops-pat";
  };
in
{
  home.stateVersion = "25.05";

  imports = [
    ../../modules/home/darwin     # darwin bundle (imports shared + darwin-only extras)
    ./registries.nix              # NB2123-only npm/yarn corp registries
  ];

  # Per-host opt-in for home-manager apps. Mirrors the darwin.apps.* /
  # shared.apps.* pattern but for user-level (home-manager) modules.
  home.apps = {
    development = {
      direnv.enable = true;
      ghostty.enable = true;
      tmux.enable = true;
      git.enable = true;                     # auto-enables lazygit
      zed.enable = true;
      # xcbuild.enable auto-defaults from direnv
      # lazydocker.enable auto-defaults from orbstack/docker

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
    };

    internet.helium.enable = true;

    security.keepass.enable = true;

    # broken on this host — leave off until fixed
    windowManager = {
      aerospace.enable = false;
      jankyborders.enable = false;
      sketchybar.enable = false;
    };
  };

  # Extract corp secrets from KeePassXC at activation, using the KDBX master
  # password cached in macOS Keychain. Bootstrap once per machine:
  #   security add-generic-password -a du234 -s kdbx-master -w '<master>' -T /usr/bin/security
  # (`-T /usr/bin/security` restricts ACL to the security binary — the only
  # thing that reads this item. `-A` is broader and should be avoided.)
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

  programs.git.settings = {
    # Corp CA for VPN HTTPS (cert-bundle.nix is host-scoped).
    http.sslCAInfo = "/etc/nix/cert-bundle.pem";
    # Per-org credential scoping for ADO — without useHttpPath, every org
    # under dev.azure.com shares one credential.
    credential."https://dev.azure.com".useHttpPath = true;
  };
}
