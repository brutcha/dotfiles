#
# Cross-platform Neovim configuration
#
# Installs Neovim and language servers, formatters for development workflows
#
{ pkgs, config, rootDir, ... }:
{
  # Install Neovim and development tools
  # https://nix-community.github.io/home-manager/options.xhtml#opt-home.packages
  home.packages = with pkgs; [
    nodejs-slim

    # Language servers for intelligent code editing
    typescript-language-server
    basedpyright  
    dockerfile-language-server
    yaml-language-server
    vscode-langservers-extracted
    eslint 
    tailwindcss-language-server
    marksman
    bash-language-server
    lua-language-server
    nil

    # Code formatters for automatic code style enforcement
    stylua 
    prettierd
    black
    isort
    shfmt
    taplo
    nixpkgs-fmt
  ];

  # https://nixos.org/manual/nixos/stable/options#opt-programs.neovim.enable
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
  };

  # Link Neovim configuration from dotfiles to home directory
  # https://nix-community.github.io/home-manager/options.xhtml#opt-home.file
  xdg.configFile."nvim" = {
    source =
      config.lib.file.mkOutOfStoreSymlink
      "${rootDir}/config/nvim";
    recursive = true;
  };

  xdg.configFile."nvim/lazy-lock.json".enable = false;
}
