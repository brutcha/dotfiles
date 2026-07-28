{ private, lib, pkgs, ... }:
#
# ~/.yarnrc.yml written at activation time so the narrow-scope PAT
# (corp/azure-devops-npmrc — Packaging: Read only) never enters /nix/store.
# Emits one block per project in private.projects that declares registry
# fields; adding/renaming a project doesn't require touching this file.
#
let
  projectsWithRegistry = lib.filterAttrs
    (_: p: (p ? registryFeed) && (p ? registryScope) && (p ? adoOrganization))
    (private.projects or { });

  mkRegistryUrl = p:
    "//pkgs.dev.azure.com/${p.adoOrganization}/_packaging/${p.registryFeed}/npm/registry/";

  npmRegistriesBlock = lib.concatStrings (lib.mapAttrsToList (_: p: ''
      ${mkRegistryUrl p}:
        npmAlwaysAuth: true
        npmAuthIdent: "${p.adoOrganization}:$CORP_AZURE_DEVOPS_NPMRC"
  '') projectsWithRegistry);

  npmScopesBlock = lib.concatStrings (lib.mapAttrsToList (_: p: ''
      ${p.registryScope}:
        npmRegistryServer: "https:${mkRegistryUrl p}"
  '') projectsWithRegistry);

  hasAnyRegistry = projectsWithRegistry != { };

  yarnrcTemplate = pkgs.writeText "yarnrc.yml.template" ''
    httpsCaFilePath: "/etc/nix/cert-bundle.pem"

    npmRegistries:
    ${npmRegistriesBlock}
    npmScopes:
    ${npmScopesBlock}
  '';
in
{
  home.file.".npmrc".text = ''
    cafile=/etc/nix/cert-bundle.pem
    registry=https://registry.npmjs.org/
  '';

  home.activation.yarnrcWithPat = lib.mkIf hasAnyRegistry
    (lib.hm.dag.entryAfter [ "keepassSecretsExtract" ] ''
      if [ -z "''${CORP_AZURE_DEVOPS_NPMRC:-}" ]; then
        echo "warn: CORP_AZURE_DEVOPS_NPMRC unset — .yarnrc.yml not written" >&2
      else
        yarnrc="$HOME/.yarnrc.yml"
        tmp="$(mktemp)"
        ${pkgs.gettext}/bin/envsubst '$CORP_AZURE_DEVOPS_NPMRC' \
          < ${yarnrcTemplate} > "$tmp"
        if [ -f "$yarnrc" ] && ${pkgs.diffutils}/bin/cmp -s "$tmp" "$yarnrc"; then
          chmod 0600 "$yarnrc" 2>/dev/null || true
        else
          $DRY_RUN_CMD install -m 0600 -T "$tmp" "$yarnrc"
        fi
        rm -f "$tmp"
      fi
    '');
}
