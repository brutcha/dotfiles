# Placeholders below are injected by pkgs.replaceVars at materialization time:
#   "@nixpkgsRev@" → inputs.nixpkgs.rev from the dotfiles flake
#   "@system@"     → pkgs.stdenv.hostPlatform.system from the activating host
#   "@packages@"   → whitespace-separated attribute names into `pkgsFor`
#                    (e.g. "nodejs_22 corepack python3 gnumake")
#
{
  description = "Dev shell for a Node-based project (generated from node-project.flake.nix)";

  inputs.nixpkgs.url = "github:NixOs/nixpkgs/@nixpkgsRev@";

  outputs = { nixpkgs, ... }:
    let
      system = "@system@";
      pkgsFor = import nixpkgs { inherit system; };
    in {
      devShells.${system}.default = pkgsFor.mkShell {
        packages = with pkgsFor; [ @packages@ ];
        shellHook = ''@shellHook@'';
      };
    };
}
