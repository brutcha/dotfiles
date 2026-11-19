final: prev: {
  # Bun does not honor NIX_SSL_CERT_FILE when fetching OpenCode dependencies.
  # NB2123's corp CA bundle is passed through Nix's permitted impure variable.
  opencode = prev.opencode.overrideAttrs (old: {
    node_modules = old.node_modules.overrideAttrs (nodeModulesOld: {
      preBuild = (nodeModulesOld.preBuild or "") + ''
        export NODE_EXTRA_CA_CERTS="$NIX_SSL_CERT_FILE"
      '';
    });
  });
}
