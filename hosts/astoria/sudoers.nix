{ lib, ... }:
# NOPASSWD for the single nixos-rebuild switch invocation, so it can run
# from Claude Code / scripts without an OS prompt. All other sudo actions
# still prompt normally.
{
  security.sudo.extraConfig = lib.mkAfter ''
    brutcha ALL=(root) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild switch *
  '';
}
