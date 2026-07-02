{ osConfig, pkgs, lib, inputs, private }:
#
# Sidecar dev shell for the NPA project. Materializes flake.nix, .envrc,
# and .emdash.json under ~/.local/share/dev-shells/<projectId>/ and
# symlinks them into the checkout. Project identity from private.nix.
#
let
  projectId = private.npa.projectId;
  adoOrganization = private.npa.adoOrganization;

  # CA bundle path comes from the host's cert-bundle.nix
  # (`nix.settings.ssl-cert-file`). If the host doesn't set it, the export
  # line is just omitted from shellHook.
  caBundle = osConfig.nix.settings.ssl-cert-file or null;
  caExport = lib.optionalString (caBundle != null && caBundle != "")
    "export NODE_EXTRA_CA_CERTS=${caBundle}\n";

  shellHook = ''
    ${caExport}if command -v claude >/dev/null 2>&1; then
      claude mcp get atlassian    >/dev/null 2>&1 || \
        claude mcp add atlassian -s local --transport http https://mcp.atlassian.com/v1/mcp
      claude mcp get azure-devops >/dev/null 2>&1 || \
        claude mcp add azure-devops -s local -- npx -y @azure-devops/mcp ${adoOrganization}
    fi
  '';

  # node-gyp needs python + make to build native modules.
  flakePackages = [ "nodejs_22" "corepack" "python3" "gnumake" ];

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
  home.activation.corpNpaSidecar = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD install -d -m 0755 "$HOME/.local/share/dev-shells/${projectId}"
    $DRY_RUN_CMD install -m 0644 -T ${flakeContent} "$HOME/.local/share/dev-shells/${projectId}/flake.nix"
    $DRY_RUN_CMD install -m 0644 -T ${emdashConfig} "$HOME/.local/share/dev-shells/${projectId}/.emdash.json"
    $DRY_RUN_CMD install -m 0644 -T ${envrcContent} "$HOME/.local/share/dev-shells/${projectId}/.envrc"

    # Auto-symlink sidecar files into the checkout at the conventional path.
    # Skips per-file if the checkout is missing or a target already exists.
    if [ -d "$HOME/git/${projectId}" ]; then
      for f in .emdash.json .envrc; do
        # -L catches dangling symlinks that -e follows into non-existence.
        { [ -e "$HOME/git/${projectId}/$f" ] || [ -L "$HOME/git/${projectId}/$f" ]; } && continue
        $DRY_RUN_CMD ln -s "$HOME/.local/share/dev-shells/${projectId}/$f" \
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
