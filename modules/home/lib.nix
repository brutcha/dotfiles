{ utils, ... }:
#
# Home-manager library utilities
#
# Provides custom utility functions and helpers for home-manager configuration.
# These utilities are made available via the `config.lib` attribute.
#
# Available utilities:
# - lib.colors: Color manipulation functions (from utils.colors)
#   - toARGB: Convert hex color and alpha to ARGB format
#
# Usage in home-manager modules:
#   { config, ... }:
#   let
#     argbColor = config.lib.colors.toARGB "#ff0000" 0.8;
#   in { ... }
#
{
  config = {
    lib.colors = utils.colors;
  };
}
