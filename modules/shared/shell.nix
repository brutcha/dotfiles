#
# Cross-platform zsh shell configuration
#
# This module is platform-agnostic and works with home-manager on macOS and Linux
#
{ pkgs, ... }:
{
  # Enable zsh as the default shell
  # https://nix-community.github.io/home-manager/options.xhtml#opt-home.shell.enableZshIntegration
  home.shell.enableZshIntegration.enable = true;

  # Atuin shell history
  # https://atuin.sh/
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.atuin.enable
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      sync.records = false; #disable syncing
      search.mode = "fuzzy";
      stats.common_subcommands_prefilter = true;  # Smart filtering
    };
  };

  # Configure zsh history
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.zsh.history
  programs.zsh.history = {
    size = 10000;
    save = 10000;
  };

  # Shell utilities and tools
  # Installs CLI tools that enhance shell productivity and provide modern alternatives to standard Unix commands.
  # https://nix-community.github.io/home-manager/options.html#opt-home.packages
  # https://search.nixos.org for package search
  home.packages = with pkgs; [  
    starship
    atuin
    zoxide
    eza
    ripgrep
    fd
    bottom
  ];

  # zsh plugins
  # Installs the pkgs from nixpkgs/github and activate them
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.zsh.plugins
  programs.zsh.plugins = with pkgs; [
    {
      name = "zsh-autosuggestions";
      src = zsh-autosuggestions;
    }
    {
      name = "zsh-syntax-highlighting";
      src = zsh-syntax-highlighting;
    }
    {
      name = "zsh-autocomplete";
      src = zsh-autocomplete;
    }
    {
      name = "zsh-fzf-tab";
      src = zsh-fzf-tab;
    }
  ];

  # https://nixos.org/manual/nixos/stable/options#opt-programs.starship.enable
  programs.starship.enable = true;

  # https://nixos.org/manual/nixos/stable/options#opt-programs.zoxide.enable
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # Shell command aliases
  # Maps common commands to their Nix-managed alternatives for improved functionality and performance.
  # https://github.com/nix-community/home-manager/blob/master/modules/programs/zsh.nix#L120
  programs.zsh.shellAliases = {
    cd = "z";
    ls = "eza";
    la = "eza --all";
    lla = "eza --long --all";
    llt = "eza --long --tree";
    find = "fd --color never";
    grep = "rg -uuu";
    top = "btm";
  };
}
