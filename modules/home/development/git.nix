{ config, lib, pkgs, ... }:
#
# Git user-level config
#
# Available options:
# - home.apps.development.git.enable - User-level git config + GCM credential helper
#
# Note: the `git` binary itself is also in flake.nix:79 environment.systemPackages
# as a foundational package. This module layers user config on top.
#
let
  cfg = config.home.apps.development.git;
in
{
  options.home.apps.development.git.enable =
    lib.mkEnableOption "git user config + GCM (browser OAuth for ADO/GitHub)";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.git-credential-manager pkgs.gh ];

    programs.git = {
      enable = true;
      ignores = [
        ".envrc"
        ".direnv/"
        ".emdash.json"
      ];
      settings = {
        credential = {
          helper = "manager";
        } // lib.optionalAttrs pkgs.stdenv.isLinux {
          # GCM needs an explicit store on Linux (no single obvious default,
          # unlike macOS Keychain). gnome-keyring's Secret Service is already
          # enabled system-wide (services.gnome.gnome-keyring.enable).
          credentialStore = "secretservice";
        };
      };
      includes = [
        {
          condition = "hasconfig:remote.*.url:**/brutcha/**";
          contents.user = {
            name = "brutcha";
            email = "mail@brutcha.dev";
          };
        }
      ];
    };
  };
}
