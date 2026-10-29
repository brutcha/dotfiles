{ config, lib, ... }:
# NOPASSWD for the single darwin-rebuild switch invocation, so it can run
# from Claude Code / scripts without an OS prompt. All other sudo actions
# still prompt normally.
{
  security.sudo.extraConfig = lib.mkAfter ''
    Defaults env_keep += "SSL_CERT_FILE GIT_SSL_CAINFO NIX_SSL_CERT_FILE"
    ${config.system.primaryUser} ALL=(root) NOPASSWD: /run/current-system/sw/bin/nix run nix-darwin/master\#darwin-rebuild -- switch --flake *
  '';
}
