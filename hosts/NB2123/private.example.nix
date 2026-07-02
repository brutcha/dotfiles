# Template — copy to ~/.config/dotfiles/private.nix and fill in real values.
# Consumed by flake.nix via `builtins.pathExists` under --impure.
{
  user = {
    name  = "Your Full Name";
    email = "you@corp.example";
  };

  npa = {
    projectId       = "MyOrg.Team.Project";
    adoOrganization = "myorg";
    registryFeed    = "feed-name%40Local";  # URL-encoded
    registryScope   = "myorg";              # npm scope prefix (@myorg/...)
  };

  secrets = {
    anthropicBaseUrl = "https://proxy.example.corp/v1/claude";
    anthropicJwt     = "<paste JWT here>";
    azureDevopsPat   = "<paste Azure DevOps PAT here>";

    # Full PEM including BEGIN/END lines. Multi-line ok.
    corpCaBundlePem  = ''
      -----BEGIN CERTIFICATE-----
      ...
      -----END CERTIFICATE-----
    '';
  };
}
