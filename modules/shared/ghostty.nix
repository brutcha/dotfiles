{ pkgs, config, rootDir, ... }:
{
  xdg.configFile."ghostty" = {
    source =
      config.lib.file.mkOutOfStoreSymlink
        "${rootDir}/config/ghostty";
    recursive = true;
  };
}
