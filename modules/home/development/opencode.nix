{ config, lib, pkgs, ... }:
#
# OpenCode V2
#
# The configuration layer is exported through OPENCODE_CONFIG. OpenCode keeps
# its mutable opencode.json and cli.json files writable.
#
# Kagi is a shared MCP. Each enabled host must materialize its API key at
# ~/.local/share/opencode-nix/secrets/kagi-api-key before OpenCode starts.
let
  cfg = config.home.apps.development.opencode;
  home = config.home.homeDirectory;
  stateDirectory = "${home}/.local/share/opencode-nix";
  configPath = "${stateDirectory}/opencode.json";
  servicePath = "${home}/.config/opencode/service.json";
  rtkEnabled = config.home.apps.development.rtk.enable;
  rtkInstruction = "${home}/.claude/RTK.md";
  baseConfiguration = {
    "$schema" = "https://opencode.ai/config.json";
    update = "notify";
    share = "disabled";
    mcp.servers = {
      # Hosts supply this private file through their own secret activation.
      kagi = {
        type = "remote";
        url = "https://mcp.kagi.com/mcp";
        headers.Authorization = "Bearer {file:${stateDirectory}/secrets/kagi-api-key}";
        codemode = false;
      };
      context7 = {
        type = "remote";
        url = "https://mcp.context7.com/mcp";
        codemode = false;
      };
    };
  };
  hostConfiguration = lib.recursiveUpdate baseConfiguration cfg.configuration;
  instructionPaths = (hostConfiguration.instructions or [ ])
    ++ lib.optional rtkEnabled rtkInstruction;
  renderedConfiguration = hostConfiguration // lib.optionalAttrs (instructionPaths != [ ]) {
    instructions = instructionPaths;
  };
  configuration = pkgs.writeText "opencode.json" (builtins.toJSON renderedConfiguration);
  mergeService = pkgs.writers.writePython3 "opencode-merge-service" { }
    (builtins.readFile ./scripts/merge-opencode-service.py);
  serviceEnvironment = cfg.service.environment // {
    OPENCODE_CONFIG = configPath;
  };
in
{
  options.home.apps.development.opencode = {
    enable = lib.mkEnableOption "OpenCode";

    configuration = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Host-specific settings merged over OpenCode's shared configuration.";
    };

    service = {
      enable = lib.mkEnableOption "the OpenCode background service";
      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Additional environment for the OpenCode background service.";
      };
    };

    cli = lib.mkOption {
      type = (pkgs.formats.json { }).type;
      default = { };
      description = "Optional OpenCode CLI configuration.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      programs.opencode = {
        enable = true;
        package = pkgs.opencode;
      };

      home.sessionVariables.OPENCODE_CONFIG = configPath;

      xdg.configFile."opencode/cli.json" = lib.mkIf (cfg.cli != { }) {
        source = (pkgs.formats.json { }).generate "opencode-cli.json" (
          { "$schema" = "https://opencode.ai/v2/cli.json"; } // cfg.cli
        );
      };

      home.activation.opencodeConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        install -d -m 0700 "${stateDirectory}" "$HOME/.config/opencode/plugins"
        $DRY_RUN_CMD install -m 0600 ${configuration} "${configPath}"

        if [ ! -e "$HOME/.config/opencode/opencode.json" ]; then
          printf '{}\n' | $DRY_RUN_CMD install -m 0600 /dev/stdin "$HOME/.config/opencode/opencode.json"
        fi
      '';
    }

    (lib.mkIf (pkgs.stdenv.hostPlatform.isDarwin && cfg.service.enable) {
      home.activation.opencodeService =
        lib.hm.dag.entryAfter [ "opencodeConfig" ] ''
          OPENCODE_SERVICE_PATH=${lib.escapeShellArg servicePath} \
          OPENCODE_SERVICE_ENV=${lib.escapeShellArg (builtins.toJSON serviceEnvironment)} \
            $DRY_RUN_CMD ${mergeService}
        '';

      launchd.agents.opencode = {
        enable = true;
        config = {
          Label = "org.dotfiles.opencode";
          ProgramArguments = [ "${pkgs.opencode}/bin/opencode" "serve" "--service" ];
          RunAtLoad = true;
          KeepAlive = true;
          ProcessType = "Interactive";
          StandardOutPath = "${home}/.local/state/opencode/service.log";
          StandardErrorPath = "${home}/.local/state/opencode/service.log";
        };
      };
    })

    (lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && cfg.service.enable) {
      systemd.user.services.opencode = {
        Unit.Description = "OpenCode background service";
        Service = {
          ExecStart = "${pkgs.opencode}/bin/opencode serve --service";
          Environment = lib.mapAttrsToList (name: value: "${name}=${value}") serviceEnvironment;
          Restart = "on-failure";
        };
        Install.WantedBy = [ "default.target" ];
      };
    })
  ]);
}
