{ private, ... }:
#
# npm/yarn corporate registries. PAT + org + feed come from private.nix.
#
let
  registryUrl = "//pkgs.dev.azure.com/${private.npa.adoOrganization}/_packaging/${private.npa.registryFeed}/npm/registry/";
in
{
  home.file.".npmrc".text = ''
    cafile=/etc/nix/cert-bundle.pem
    registry=https://registry.npmjs.org/
  '';

  home.file.".yarnrc.yml".text = ''
    httpsCaFilePath: "/etc/nix/cert-bundle.pem"

    npmRegistries:
      ${registryUrl}:
        npmAlwaysAuth: true
        npmAuthIdent: "${private.npa.adoOrganization}:${private.secrets.azureDevopsPat}"

    npmScopes:
      ${private.npa.registryScope}:
        npmRegistryServer: "https:${registryUrl}"
  '';
}
