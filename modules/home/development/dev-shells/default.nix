{ config, pkgs, lib, inputs, private ? null, ... }:
#
# Per-project dev-shell direnv sidecars (https://direnv.net).
#
# Enumerates entries in `private.projects` and instantiates corp-project.nix
# for each. Adding a project is a private.nix edit — no dotfiles change.
# `mkIf direnv.enable` gates the whole thing.
#
let
  mk = project: import ./corp-project.nix {
    inherit pkgs lib inputs project private config;
  };
  projects = if private != null then (private.projects or {}) else {};
  sidecars = lib.mapAttrsToList (_: mk) projects;

  # Emdash sometimes spawns agents without shellSetup, so the session lands in
  # ~/.claude and a later --resume (with env.sh) can't find it. Pick env.sh by cwd.
  claudeEnvCase = lib.concatMapStrings (project: let id = project.projectId; in ''
    "$HOME/git/${id}/"*|"$HOME/emdash/worktrees/${id}/"*|"$HOME/emdash/worktrees/${id}-"*)
      envFile="$HOME/.local/share/dev-shells/${id}/env.sh" ;;
  '') (lib.attrValues projects);
  claudeWrapper = pkgs.writeShellScriptBin "claude" ''
    if [ -z "''${CLAUDE_CONFIG_DIR:-}" ]; then
      envFile=
      case "$PWD/" in
      ${claudeEnvCase}
      esac
      if [ -n "$envFile" ] && [ -r "$envFile" ]; then . "$envFile"; fi
    fi
    exec ${config.programs.claude-code.finalPackage}/bin/claude "$@"
  '';
in
{
  config = lib.mkIf config.home.apps.development.direnv.enable (lib.mkMerge (sidecars ++ [
    (lib.mkIf (config.home.apps.development.claude-code.enable && projects != {}) {
      home.packages = [ (lib.hiPrio claudeWrapper) ];
    })
  ]));
}
