{ pkgs, lib, inputs, project, private }:
#
# Sidecar dev shell for a corp project. Materializes flake.nix, .envrc,
# and .emdash.json under ~/.local/share/dev-shells/<projectId>/ and
# symlinks them into the checkout. Instantiated per entry in
# private.projects by ./default.nix; `private` is passed through only for
# programs.git.includes (user.name/email).
#
let
  projectId = project.projectId;
  adoOrganization = project.adoOrganization;
  flakePackages = project.packages;

  # Attribute keys can technically contain dots, but home-manager routes
  # activation names through a shell DAG — sanitize to be safe.
  attrSafeId = builtins.replaceStrings [ "." "-" ] [ "_" "_" ] projectId;

  # Per-project env vars (NODE_EXTRA_CA_CERTS, YARN_ENABLE_GLOBAL_CACHE, …).
  envExports = lib.concatStringsSep ""
    (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}\n")
      (project.env or {}));

  shellHook = ''
    ${envExports}if command -v claude >/dev/null 2>&1; then
      claude mcp get atlassian    >/dev/null 2>&1 || \
        claude mcp add atlassian -s local --transport http https://mcp.atlassian.com/v1/mcp
      claude mcp get azure-devops >/dev/null 2>&1 || \
        claude mcp add azure-devops -s local -- npx -y @azure-devops/mcp ${adoOrganization}
    fi
  '';

  flakeContent = pkgs.replaceVars ./templates/node-project.flake.nix {
    inherit shellHook;
    nixpkgsRev = inputs.nixpkgs.rev;
    system = pkgs.stdenv.hostPlatform.system;
    packages = lib.concatStringsSep " " flakePackages;
  };

  envrcContent = pkgs.writeText ".envrc"
    "use flake ~/.local/share/dev-shells/${projectId}\n";

  emdashConfig = pkgs.writeText ".emdash.json" (builtins.toJSON {
    preservePatterns = [
      ".env"
      ".env.local"
      ".envrc"
      ".claude/.custom/**"
      ".claude/.custom-autoload/**"
    ];
    shellSetup = "";
    scripts = {
      setup = "direnv allow . && direnv exec . yarn install --frozen-lockfile && direnv exec . yarn gitnexus-analyze --skip-agents-md";
      run = "";
      teardown = "";
    };
  });
in
{
  home.activation."corpSidecar_${attrSafeId}" = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD install -d -m 0755 "$HOME/.local/share/dev-shells/${projectId}"
    $DRY_RUN_CMD install -m 0644 -T ${flakeContent} "$HOME/.local/share/dev-shells/${projectId}/flake.nix"
    $DRY_RUN_CMD install -m 0644 -T ${emdashConfig} "$HOME/.local/share/dev-shells/${projectId}/.emdash.json"
    $DRY_RUN_CMD install -m 0644 -T ${envrcContent} "$HOME/.local/share/dev-shells/${projectId}/.envrc"

    # Materialize as real files in the checkout — emdash preservePatterns
    # copies files, not symlinks, so worktrees created from ~/git/${projectId}
    # inherit both. Idempotent overwrite on every activation.
    if [ -d "$HOME/git/${projectId}" ]; then
      for f in .emdash.json .envrc; do
        rm -f "$HOME/git/${projectId}/$f"
        $DRY_RUN_CMD install -m 0644 -T \
          "$HOME/.local/share/dev-shells/${projectId}/$f" \
          "$HOME/git/${projectId}/$f"
      done
    fi
  '';

  programs.git.includes = [
    {
      condition = "hasconfig:remote.*.url:**/${projectId}/**";
      contents.user = {
        name = private.user.name;
        email = private.user.email;
      };
    }
  ];
}
