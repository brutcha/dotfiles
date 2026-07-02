{ config, osConfig, pkgs, lib, inputs, private ? null, ... }:
#
# Per-project dev-shell direnv sidecars (https://direnv.net).
#
# Each sidecar is a plain function; add a new one to `sidecars` gated on
# the private-nix keys it needs. `mkIf direnv.enable` gates everything.
#
let
  args = { inherit osConfig pkgs lib inputs private; };
  sidecars =
    lib.optional (private != null && (private.npa or null) != null)
      (import ./corp-npa.nix args);
in
{
  config = lib.mkIf config.home.apps.development.direnv.enable (lib.mkMerge sidecars);
}
