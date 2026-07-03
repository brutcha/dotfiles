# Template — copy to ~/.config/dotfiles/private.nix and fill in real values.
# Consumed by flake.nix via `import` under --impure. Non-secret host metadata
# only; secrets live in KeePassXC and are extracted at activation time (see
# home.activation.keepassSecretsExtract in hosts/NB2123/home.nix).
let
  corpCaBundle = "/etc/nix/cert-bundle.pem";
in
{
  user = {
    name  = "Your Full Name";
    email = "you@corp.example";
  };

  # Each entry becomes a per-project direnv sidecar via
  # modules/home/development/dev-shells/corp-project.nix. Every project
  # declares its own packages + env exports. `env` values are written to
  # $HOME/.local/share/dev-shells/<projectId>/env.sh at activation time
  # (chmod 0600) and shell-expanded, so a value of "$CORP_XYZ" resolves
  # against whatever keepassSecretsExtract has exported — same channel as
  # registries.nix. registries.nix currently consumes
  # `projects.npaApp.{adoOrganization,registryFeed,registryScope}` for the
  # .yarnrc.yml Azure Artifacts wiring.
  projects = {
    npaApp = {
      projectId       = "MyOrg.Team.Project";
      adoOrganization = "myorg";
      registryFeed    = "feed-name%40Local";  # URL-encoded
      registryScope   = "myorg";              # npm scope prefix (@myorg/...)
      packages        = [ "nodejs_22" "corepack" "python3" "gnumake" ];
      env = {
        NODE_EXTRA_CA_CERTS = corpCaBundle;
      };
    };
    # feApp = {
    #   projectId       = "MyOrg.Other.Project";
    #   adoOrganization = "myorg";
    #   packages        = [ "nodejs_22" "corepack" ];
    #   env = {
    #     NODE_EXTRA_CA_CERTS      = corpCaBundle;
    #     YARN_ENABLE_GLOBAL_CACHE = "1";
    #   };
    # };
  };
}
