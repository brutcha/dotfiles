# Template — copy to ~/.config/dotfiles/private.nix and fill in real values.
# Consumed by flake.nix via `import` under --impure. Non-secret host metadata
# only; secrets live in KeePassXC and are extracted at activation time (see
# home.activation.keepassSecretsExtract in hosts/NB2123/home.nix).
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
}
