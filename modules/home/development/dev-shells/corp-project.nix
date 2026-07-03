{ pkgs, lib, inputs, project, private }:
# Per-project direnv sidecar. Instantiated from ./default.nix per private.projects entry.
let
  projectId = project.projectId;
  adoOrganization = project.adoOrganization;
  flakePackages = project.packages;

  # Sanitize dots/dashes for use as a home.activation attribute name.
  attrSafeId = builtins.replaceStrings [ "." "-" ] [ "_" "_" ] projectId;

  # env.sh written at activation (chmod 0600); values may reference $CORP_* from keepassSecretsExtract.
  envExports = lib.concatStringsSep ""
    (lib.mapAttrsToList (k: v: "export ${k}=\"${v}\"\n")
      (project.env or {}));

  shellHook = ''
    envFile="$HOME/.local/share/dev-shells/${projectId}/env.sh"
    [ -r "$envFile" ] && . "$envFile"
    if command -v claude >/dev/null 2>&1; then
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

    # Unquoted heredoc: $CORP_* refs in env values expand at write time. Add "keepassSecretsExtract" to entryAfter when using them.
    tmpEnv="$(mktemp)"
    cat > "$tmpEnv" <<ENV_EOF
    ${envExports}ENV_EOF
    $DRY_RUN_CMD install -m 0600 -T "$tmpEnv" "$HOME/.local/share/dev-shells/${projectId}/env.sh"
    $DRY_RUN_CMD rm -f "$tmpEnv"

    # Real files (not symlinks) so emdash preservePatterns copies them into worktrees.
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
