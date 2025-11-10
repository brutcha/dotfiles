#
# Cross-platform zsh shell configuration
#
# This module is platform-agnostic and works with home-manager on macOS and Linux
#
{ pkgs, lib, ... }:
{
  # Shell utilities and tools
  # Installs CLI tools that enhance shell productivity and provide modern alternatives to standard Unix commands.
  # https://nix-community.github.io/home-manager/options.html#opt-home.packages
  # https://search.nixos.org for package search
  home.packages = with pkgs; [
    starship
    fzf
    zoxide
    eza
    ripgrep
    fd
    bottom
    tldr
  ];

  programs = {
    # FZF fuzzy finder
    # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.fzf.enable
    fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultOptions = [
        "--height 40%"
        "--layout=reverse"
        "--border"
        "--no-mouse"
      ];
    };

    # https://nixos.org/manual/nixos/stable/options#opt-programs.starship.enable
    starship.enable = true;

    # https://nixos.org/manual/nixos/stable/options#opt-programs.zoxide.enable
    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.zsh.enable
    zsh = {
      # Enable zsh as the default shell
      enable = true;

      # Configure zsh history
      # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.zsh.history
      history = {
        size = 5000;
        save = 5000;
        path = "$HOME/.zsh_history";
        expireDuplicatesFirst = true;
        ignoreDups = true;
        ignoreAllDups = true;
        ignoreSpace = true;
        share = true;
      };

      # zsh-autocomplete requires have completion disabled
      enableCompletion = false;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      plugins = with pkgs; [
        {
          # Real-time type-ahead completion for inline history search
          # using older version with working a menu working when typing
          # https://github.com/marlonrichert/zsh-autocomplete
          name = "zsh-autocomplete";
          src = fetchFromGitHub {
            owner = "marlonrichert";
            repo = "zsh-autocomplete";
            rev = "23.07.13";
            sha256 = "sha256-0NW0TI//qFpUA2Hdx6NaYdQIIUpRSd0Y4NhwBbdssCs=";
          };
          file = "zsh-autocomplete.plugin.zsh";
        }
        {
          # Imrpoved completion sellection, zsh-autocomplete is used for history and live suggestion
          # https://github.com/Aloxaf/fzf-tab
          name = "zsh-fzf-tab";
          src = zsh-fzf-tab;
          file = "share/fzf-tab/fzf-tab.plugin.zsh";
        }
      ];

      initContent = ''
        # autosuggest options
        zstyle ':autocomplete:*' delay 0.3

        # fzf-tab options
        zstyle ':fzf-tab:*' show-group none
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
        zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'
      '';

      shellAliases = {
        cd = "z";
        ls = "eza";
        la = "eza --all";
        lla = "eza --long --all";
        llt = "eza --long --tree";
        find = "fd --color never";
        grep = "rg -uuu";
        top = "btm";
      };
    };
  };

  services = {
    # Automatic updates for tldr CLI cache
    # https://nix-community.github.io/home-manager/options.xhtml#opt-services.tldr-update.enable
    tldr-update = lib.mkIf pkgs.stdenv.isLinux {
      enable = true;
    };
  };
}
