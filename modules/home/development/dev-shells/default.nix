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
in
{
  config = lib.mkIf config.home.apps.development.direnv.enable (lib.mkMerge sidecars);
}
