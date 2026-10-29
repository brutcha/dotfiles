{ config, lib, pkgs, ... }:
#
# OpenCode V2 — vendor-installed binary with a Nix-rendered, writable config
# layer.  OpenCode itself owns ~/.config/opencode/{opencode,cli,service}.json;
# activation only supplies the layer referenced by OPENCODE_CONFIG and merges
# the environment keys that the service needs.
let
  cfg = config.home.apps.development.opencode;
  home = config.home.homeDirectory;
  stateDir = "${home}/.local/share/opencode-nix";
  configPath = "${stateDir}/opencode.json";
  servicePath = "${home}/.config/opencode/service.json";
  pluginSource = "${home}/.config/dotfiles/opencode-devkit-port/shim/opencode-plugin.ts";
  fallbackModels = {
    corp-anthropic = [
      "claude-haiku-4-5" "claude-haiku-5-5" "claude-opus-4-7"
      "claude-opus-4-8" "claude-opus-5" "claude-opus-5-5"
      "claude-sonnet-4-6" "claude-sonnet-5" "claude-sonnet-5-5"
    ];
    corp-openai = [ "gpt-5.4" "gpt-5.5" "gpt-5.6-luna" "gpt-5.6-sol" "gpt-5.6-terra" "gpt-6-astra" ];
  };
  modelAttrs = names: lib.genAttrs names (_: { });
  layer = {
    "$schema" = "https://opencode.ai/config.json";
    update = "notify";
    share = "disabled";
    websearch = false;
    # This checked fallback is intentionally retained if gateway discovery is
    # unavailable (for example, during a VPN-off rebuild).
    providers = {
      corp-anthropic = {
        name = "Corp Anthropic";
        canonical = "anthropic";
        package = "@opencode/ai/providers/anthropic";
        settings = {
          baseURL = "{file:${stateDir}/secrets/anthropic-base-url}/v1";
          apiKey = "{file:${stateDir}/secrets/anthropic-jwt}";
        };
        models = modelAttrs fallbackModels.corp-anthropic;
      };
      corp-openai = {
        name = "Corp OpenAI (Codex proxy)";
        canonical = "openai";
        package = "@opencode/ai/providers/azure/responses";
        settings = {
          baseURL = "{file:${stateDir}/secrets/codex-base-url}";
          apiKey = "{file:${stateDir}/secrets/codex-api-key}";
        };
        models = modelAttrs fallbackModels.corp-openai;
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
      kagi = {
        type = "remote";
        url = "https://mcp.kagi.com/mcp";
        headers.Authorization = "Bearer {file:${stateDir}/secrets/kagi-api-key}";
        codemode = false;
      };
      figma = {
        type = "remote";
        url = "https://mcp.figma.com/mcp";
        headers.X-Figma-Plugin-Bundle = "figma_prod@2_2_157";
      };
      context7 = {
        type = "remote";
        url = "https://mcp.context7.com/mcp";
        codemode = false;
      };
      playwright = {
        type = "local";
        command = [ "yarn" "dlx" "@playwright/mcp@latest" "--headless" ];
        codemode = false;
      };
    };
    instructions = [
      "${home}/.claude/RTK.md"
      "${stateDir}/instructions/dotfiles-rebuild.md"
      "${stateDir}/instructions/user-shell.md"
    ];
  };
  layerJson = pkgs.writeText "opencode.json" (builtins.toJSON layer);
  mergeService = pkgs.writers.writePython3 "opencode-merge-service" { } ''
    import json
    import os
    import pathlib
    import tempfile

    path = pathlib.Path(os.environ["OPENCODE_SERVICE_PATH"])
    owned = json.loads(os.environ["OPENCODE_SERVICE_ENV"])
    try:
        existing = json.loads(path.read_text()) if path.exists() else {}
    except json.JSONDecodeError:
        existing = {}
    env = existing.get("env") if isinstance(existing.get("env"), dict) else {}
    env.update(owned)
    existing["env"] = env
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(prefix="service.json.", dir=path.parent)
    with os.fdopen(fd, "w") as out:
        json.dump(existing, out, indent=2)
        out.write("\n")
    os.chmod(temp, 0o600)
    os.replace(temp, path)
  '';
  serviceEnv = builtins.toJSON {
    OPENCODE_CONFIG = configPath;
    PATH = "/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
    NODE_EXTRA_CA_CERTS = "/etc/nix/cert-bundle.pem";
  };
in
{
  options.home.apps.development.opencode.enable = lib.mkEnableOption "OpenCode V2 global configuration and service";
  options.home.apps.development.opencode.cli = lib.mkOption {
    type = (pkgs.formats.json { }).type;
    default = { };
    description = ''
      OpenCode V2 CLI settings. This is a local compatibility shim for
      Home Manager issue #10070: V2 reads cli.json rather than tui.json.
      Leave empty to retain OpenCode's mutable CLI settings file.
    '';
  };

  config = lib.mkIf cfg.enable {
    # Home Manager's module supplies the CLI integration but must not install
    # or manage the vendor Homebrew package or writable OpenCode config.
    programs.opencode = {
      enable = true;
      package = null;
    };

    home.sessionVariables.OPENCODE_CONFIG = configPath;

    # Do not set this by default: the OpenCode UI writes cli.json itself. The
    # option is available for future deliberately declarative CLI settings
    # until Home Manager grows native V2 cli.json support (#10070).
    xdg.configFile."opencode/cli.json" = lib.mkIf (cfg.cli != { }) {
      source = (pkgs.formats.json { }).generate "opencode-cli.json" (
        { "$schema" = "https://opencode.ai/v2/cli.json"; } // cfg.cli
      );
    };

    home.activation.opencodeConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      install -d -m 0700 "${stateDir}" "${stateDir}/secrets" "$HOME/.config/opencode/plugins"
      # The hook shim imports OpenCode's runtime SDK and has no independent
      # npm dependency today. Reserve its cache outside the OneDrive-backed
      # source tree so any future lockfile install remains local.
      install -d -m 0700 "$HOME/.cache/opencode-devkit-port/node_modules"
      if [ ! -e "$HOME/.config/dotfiles/opencode-devkit-port/node_modules" ]; then
        $DRY_RUN_CMD ln -s "$HOME/.cache/opencode-devkit-port/node_modules" \
          "$HOME/.config/dotfiles/opencode-devkit-port/node_modules"
      fi
      $DRY_RUN_CMD install -m 0600 ${layerJson} "${configPath}"

      # OpenCode creates and owns this file after first launch.  Bootstrap only;
      # never replace user configuration or an OpenCode migration.
      if [ ! -e "$HOME/.config/opencode/opencode.json" ]; then
        printf '{}\n' | $DRY_RUN_CMD install -m 0600 /dev/stdin "$HOME/.config/opencode/opencode.json"
      fi

      $DRY_RUN_CMD ln -sfn "${pluginSource}" "$HOME/.config/opencode/plugins/npa-hook-compat.ts"
      OPENCODE_SERVICE_PATH=${lib.escapeShellArg servicePath} \
      OPENCODE_SERVICE_ENV=${lib.escapeShellArg serviceEnv} \
        $DRY_RUN_CMD ${mergeService}
    '';

    # The vendor service reads service.json, including the merged environment.
    # It has no gateway credentials in its environment; providers read the
    # activation-written 0600 secret files referenced by the layer instead.
    launchd.agents.opencode = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      enable = true;
      config = {
        Label = "org.dotfiles.opencode";
        ProgramArguments = [ "/opt/homebrew/bin/opencode" "serve" "--service" ];
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Interactive";
        StandardOutPath = "${home}/.local/state/opencode/service.log";
        StandardErrorPath = "${home}/.local/state/opencode/service.log";
      };
    };
  };
}
