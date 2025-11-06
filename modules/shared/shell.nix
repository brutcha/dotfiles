#
# Cross-platform zsh shell configuration
#
# This module is platform-agnostic and works with home-manager on macOS and Linux
#
{ pkgs, lib, ... }:
{
  # Enable zsh as the default shell
  programs.zsh.enable = true;
  # https://nix-community.github.io/home-manager/options.xhtml#opt-home.shell.enableZshIntegration
  # home.shell.enableZshIntegration.enable = true;

  # Configure zsh history
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.zsh.history
  programs.zsh.history = {
    size = 5000;
    save = 5000;
    path = "$HOME/.zsh_history";
    expireDuplicatesFirst = true;
    ignoreDups = true;
    ignoreAllDups = true;
    ignoreSpace = true;
    share = true;
  };

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
  ];

  # FZF fuzzy finder
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.fzf.enable
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--no-mouse"
    ];
  };

  # Zsh completion system with fzf-tab and zsh-autocomplete
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.zsh.enableCompletion
  programs.zsh.enableCompletion = true;

  # Completion initialization with styling and plugin configuration
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.zsh.completionInit
  programs.zsh.completionInit = ''
    autoload -U compinit && compinit
    
    zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
    
    # fzf-tab: https://github.com/Aloxaf/fzf-tab
    zstyle ':fzf-tab:*' fzf-min-height 15
    zstyle ':fzf-tab:*' query-string prefix input first
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --color=always $realpath'
    zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza --color=always $realpath'
    
    # zsh-autocomplete: https://github.com/marlonrichert/zsh-autocomplete
    zstyle ':autocomplete:*' list-lines 10
    zstyle ':autocomplete:*' min-delay 0.05
    zstyle ':autocomplete:history-search-backward:*' list-lines 10
  '';

  # Fish-like autosuggestions
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.zsh.autosuggestion.enable
  programs.zsh.autosuggestion.enable = true;

  # Syntax highlighting
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.zsh.syntaxHighlighting.enable
  programs.zsh.syntaxHighlighting.enable = true;

  # Additional zsh plugins
  # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.zsh.plugins
  programs.zsh.plugins = [
    {
      # Real-time type-ahead completion for inline history search
      # https://github.com/marlonrichert/zsh-autocomplete
      name = "zsh-autocomplete";
      src = pkgs.fetchFromGitHub {
        owner = "marlonrichert";
        repo = "zsh-autocomplete";
        rev = "24.09.04";
        sha256 = "sha256-o8IQszQ4/PLX1FlUvJpowR2Tev59N8lI20VymZ+Hp4w=";
      };
    }
    {
      # Replace default completion menu with fzf
      # https://github.com/Aloxaf/fzf-tab
      name = "zsh-fzf-tab";
      src = pkgs.zsh-fzf-tab;
      file = "share/fzf-tab/fzf-tab.plugin.zsh";
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
