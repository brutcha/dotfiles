{ config, lib, pkgs, ... }:
#
# OpenAI Codex CLI — package + declarative ~/.codex/config.toml writer.
#
# Available options:
# - home.apps.development.codex.enable      - install codex; write config.toml
# - home.apps.development.codex.model       - default model (str)
# - home.apps.development.codex.reasoning   - model_reasoning_effort (low/medium/high)
# - home.apps.development.codex.settings    - free-form TOML fields (attrsOf anything)
# - home.apps.development.codex.mcpServers  - typed [mcp_servers.*] entries (attrsOf submodule)
#
# `model`, `reasoning`, and `mcpServers` from the typed options always win on
# merge against `settings`. `_lib.renderConfigToml` is an internal helper that
# takes an extra mcpServers attrset and returns the merged TOML as a store
# path — consumers use it to render project-scoped variants.
#
let
  cfg = config.home.apps.development.codex;

  mcpServerType = lib.types.submodule ({ name, ... }: {
    options = {
      type = lib.mkOption {
        type = lib.types.enum [ "http" "stdio" ];
        description = "Transport for MCP server '${name}'.";
      };
      url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "URL for http transport.";
      };
      command = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Executable for stdio transport.";
      };
      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Arguments for stdio transport.";
      };
      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Extra env vars for stdio transport.";
      };
      authorization_env_var = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Env var whose value is sent as the Authorization header verbatim
          (e.g. "Bearer xyz" or "Basic <base64(user:pass)>"). Only valid for
          http transport. Written to config.toml as
          `http_headers.Authorization = "$<env var name>"` and then expanded
          to a literal value at activation time by envsubst (see
          hosts/NB2123/home.nix and modules/home/development/dev-shells/
          corp-project.nix). Codex has no runtime env-var indirection for
          headers, so the secret is baked into the on-disk 0600 config.toml.
        '';
      };
    };
  });

  # mcpServerType -> Codex TOML shape.
  #   http  -> { url = ...; }
  #   stdio -> { command = ...; args = [...]; env = { ... }; }  (env dropped when empty)
  toTomlServer = name: s:
    let
      require = field: value:
        if value == null then
          throw "codex.nix: mcp_servers.${name} is type '${s.type}' but has no '${field}' — set mcpServers.${name}.${field}."
        else value;
    in
    if s.type or null == "http" then
      { url = require "url" (s.url or null); } //
        lib.optionalAttrs ((s.authorization_env_var or null) != null)
          { http_headers.Authorization = "$" + s.authorization_env_var; }
    else if s.type or null == "stdio" then
      lib.throwIf ((s.authorization_env_var or null) != null)
        "codex.nix: mcp_servers.${name} is stdio — authorization_env_var only applies to http transport (Codex has no runtime header injection for stdio; set env instead)."
        ({ command = require "command" (s.command or null); args = s.args or [ ]; } //
          lib.optionalAttrs ((s.env or { }) != { }) { env = s.env; })
    else throw "codex.nix: mcp_servers.${name}.type '${s.type or "<unset>"}' unsupported (want 'http' or 'stdio').";

  tomlFormat = pkgs.formats.toml { };

  mkConfigAttrs = extraMcpServers:
    cfg.settings // {
      model = cfg.model;
      model_reasoning_effort = cfg.reasoning;
      mcp_servers = lib.mapAttrs toTomlServer (cfg.mcpServers // extraMcpServers);
    };

  renderConfigToml = extraMcpServers:
    tomlFormat.generate "codex-config.toml" (mkConfigAttrs extraMcpServers);
in
{
  options.home.apps.development.codex = {
    enable = lib.mkEnableOption "OpenAI Codex CLI";

    model = lib.mkOption {
      type = lib.types.str;
      default = "gpt-5.5";
      description = "Default model — written as `model = ...` in config.toml.";
    };

    reasoning = lib.mkOption {
      type = lib.types.enum [ "low" "medium" "high" ];
      default = "medium";
      description = "Written as `model_reasoning_effort = ...` in config.toml.";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = ''
        Free-form TOML fields merged into config.toml. Use for anything the
        typed options above don't cover: `model_provider`, `model_providers`,
        hooks, sandbox policy, etc.
      '';
    };

    mcpServers = lib.mkOption {
      type = lib.types.attrsOf mcpServerType;
      default = { };
      description = "Entries written under `[mcp_servers.<name>]` in config.toml.";
    };

    _lib = lib.mkOption {
      type = lib.types.raw;
      internal = true;
      readOnly = true;
      default = { inherit renderConfigToml; };
      description = ''
        Exposes `renderConfigToml : attrsOf mcpServerType -> path`. Returns
        a store path holding config.toml with the given extras merged over
        `mcpServers`. `settings`, `model`, and `reasoning` are always taken
        from the module's own values.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.codex ];

    # Public MCP defaults — hosts extend via home.apps.development.codex.mcpServers.foo.
    home.apps.development.codex.mcpServers = {
      openaiDeveloperDocs = {
        type = "http";
        url = "https://developers.openai.com/mcp";
      };
      context7 = {
        type = "http";
        url = "https://mcp.context7.com/mcp";
      };
    };

    home.activation.codexBase =
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        # Guard against a stray CODEX_HOME redirecting the write.
        unset CODEX_HOME
        $DRY_RUN_CMD install -d -m 0700 "$HOME/.codex"
        $DRY_RUN_CMD install -m 0600 -T ${renderConfigToml { }} "$HOME/.codex/config.toml"
      '';
  };
}
