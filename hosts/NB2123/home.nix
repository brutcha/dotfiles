#
# NB2123 home-manager configuration (user-level)
#
{ private, ... }:
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

      # Corporate gateway provider — JWT + base URL from private.nix.
      claude-code = {
        enable = true;
        env = {
          ANTHROPIC_BASE_URL = private.secrets.anthropicBaseUrl;
          ANTHROPIC_AUTH_TOKEN = private.secrets.anthropicJwt;
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

  programs.git.settings = {
    # Corp CA for VPN HTTPS (cert-bundle.nix is host-scoped).
    http.sslCAInfo = "/etc/nix/cert-bundle.pem";
    # Per-org credential scoping for ADO — without useHttpPath, every org
    # under dev.azure.com shares one credential.
    credential."https://dev.azure.com".useHttpPath = true;
  };
}
