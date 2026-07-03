{ config, lib, ... }:
# NOPASSWD for the single darwin-rebuild switch invocation, so it can run
# from Claude Code / scripts without an OS prompt. All other sudo actions
# still prompt normally.
{
  security.sudo.extraConfig = lib.mkAfter ''
    ${config.system.primaryUser} ALL=(root) NOPASSWD: /run/current-system/sw/bin/nix run nix-darwin/master\#darwin-rebuild -- switch --flake * --impure
  '';
}
