{ private, lib, pkgs, ... }:
#
# npm/yarn corporate registries. org/feed/scope from private.nix (non-secret);
# PAT injected at activation time from KeePassXC (see keepass module).
#
let
  registryUrl = "//pkgs.dev.azure.com/${private.projects.npaApp.adoOrganization}/_packaging/${private.projects.npaApp.registryFeed}/npm/registry/";
in
{
  home.file.".npmrc".text = ''
    cafile=/etc/nix/cert-bundle.pem
    registry=https://registry.npmjs.org/
  '';

  # .yarnrc.yml is written at activation time so the PAT never enters /nix/store.
  home.activation.yarnrcWithPat =
    lib.hm.dag.entryAfter [ "keepassSecretsExtract" ] ''
      if [ -z "''${CORP_AZURE_DEVOPS_PAT:-}" ]; then
        echo "warn: CORP_AZURE_DEVOPS_PAT unset — .yarnrc.yml not written" >&2
      else
      yarnrc="$HOME/.yarnrc.yml"
      tmp="$(mktemp)"
      cat > "$tmp" <<EOF
      httpsCaFilePath: "/etc/nix/cert-bundle.pem"

      npmRegistries:
        ${registryUrl}:
          npmAlwaysAuth: true
          npmAuthIdent: "${private.projects.npaApp.adoOrganization}:$CORP_AZURE_DEVOPS_PAT"

      npmScopes:
        ${private.projects.npaApp.registryScope}:
          npmRegistryServer: "https:${registryUrl}"
      EOF
      $DRY_RUN_CMD install -m 600 "$tmp" "$yarnrc"
      $DRY_RUN_CMD rm -f "$tmp"
      fi
    '';
}
