#
# Cross-platform Neovim configuration
#
# Installs Neovim and language servers, formatters for development workflows
#
{
  pkgs,
  config,
  rootDir,
  ...
}:
{
  # Install Neovim and development tools
  # https://nix-community.github.io/home-manager/options.xhtml#opt-home.packages
  home.packages = with pkgs; [
    nodejs-slim
    tree-sitter

    # Language servers for intelligent code editing
    typescript-language-server
    basedpyright
    dockerfile-language-server
    yaml-language-server
    vscode-langservers-extracted
    eslint
    tailwindcss-language-server
    markdown-oxide       # marksman replacement — Rust, no dotnet
    bash-language-server
    lua-language-server
    nixd

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
    # Ruby provider: no plugins here use it.
    withRuby = false;
    # Python3 provider: bundles a Python interpreter into the nvim wrapper
    # (not on system PATH) so plugins using `:python3` keep working.
    withPython3 = true;
    # Pass the wrapper-generated init.lua (provider setup, plugin glue, …)
    # to nvim via `--cmd 'lua dofile(...)'` instead of writing it to
    # ~/.config/nvim/init.lua. Keeps that path free for the user's
    # recursive symlink below (otherwise both fight over the same file and
    # home-manager logs "init.lua conflicts with recursively symlinked file").
    sideloadInitLua = true;
  };

  # Link Neovim configuration from dotfiles to home directory
  # https://nix-community.github.io/home-manager/options.xhtml#opt-home.file
  xdg.configFile."nvim" = {
    source = config.lib.file.mkOutOfStoreSymlink "${rootDir}/config/nvim";
    recursive = true;
  };

  xdg.configFile."nvim/lazy-lock.json".enable = false;
}
