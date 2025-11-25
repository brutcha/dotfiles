{ ... }:
{
  imports = [
    ./zen.nix
  ];

  programs.thunderbird = {
    enable = false;
  };
}
