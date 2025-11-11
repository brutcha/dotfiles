{ pkgs, lib, ... }:

# Tokyo Night Theme Module
#
# Extracts Tokyo Night color palette from tokyonight.nvim and exposes it as
# a Nix attribute set for use across all home-manager modules.
#
# RESPONSIBILITY:
# - Extract colors from tokyonight.nvim (night variant)
# - Parse colors into Nix attribute set
# - Export colors via config.theme option
#
# USAGE:
# Import this module in any home-manager module to access colors:
#
#   { config, ... }: {
#     imports = [ ./theme.nix ];
#     
#     # Use dark theme colors
#     programs.someApp.backgroundColor = config.theme.dark.bg;
#     programs.someApp.accentColor = config.theme.dark.blue;
#     
#     # Use light theme colors
#     programs.anotherApp.backgroundColor = config.theme.light.bg;
#     
#     # Generate app-specific color files if needed
#     xdg.configFile."myapp/colors.toml" = {
#       text = ''
#         [dark]
#         background = "${config.theme.dark.bg}"
#         foreground = "${config.theme.dark.fg}"
#         
#         [light]
#         background = "${config.theme.light.bg}"
#         foreground = "${config.theme.light.fg}"
#       '';
#     };
#   }
#
# AVAILABLE COLORS:
# - Base: bg, bg_dark, fg, fg_dark, comment, etc.
# - Accent: blue, cyan, green, magenta, purple, red, orange, yellow, teal
# - Semantic: error, warning, info, hint, todo
# - Git: git.add, git.change, git.delete, git.ignore
# - Terminal: terminal.black, terminal.red, terminal.green, etc.
# - Rainbow: rainbow (array of colors)
# - And many more - see tokyonight.nvim extras file for full list
#
# SOURCE:
# Colors are extracted from vimPlugins.tokyonight-nvim/extras/lua/ directory:
# - Dark: tokyonight_night.lua (https://github.com/folke/tokyonight.nvim/blob/main/extras/lua/tokyonight_night.lua)
# - Light: tokyonight_day.lua (https://github.com/folke/tokyonight.nvim/blob/main/extras/lua/tokyonight_day.lua)
# These files contain all pre-computed colors without vim dependencies.

let
  tokyonightPlugin = pkgs.vimPlugins.tokyonight-nvim;

  # Extract colors from a tokyonight variant (night, day, storm, moon)
  extractColors = variant:
    let
      extrasFile = "${tokyonightPlugin}/extras/lua/tokyonight_${variant}.lua";
      colorsJson = pkgs.runCommand "tokyonight-${variant}-colors.json"
        {
          buildInputs = [ pkgs.lua pkgs.luaPackages.cjson ];
        } ''
              ${pkgs.lua}/bin/lua << 'EOF' > $out
              local cjson = require("cjson")
      
              local file = io.open("${extrasFile}", "r")
              local content = file:read("*all")
              file:close()
      
              local colors = load(content .. "\nreturn colors")()
      
              -- Remove metadata fields
              colors._name = nil
              colors._style = nil
      
              print(cjson.encode(colors))
        EOF
      '';
    in
    builtins.fromJSON (builtins.readFile colorsJson);

  # Extract both dark and light variants
  darkColors = extractColors "night";
  lightColors = extractColors "day";
in
{
  # Export color palettes as read-only module options
  options.theme = {
    dark = lib.mkOption {
      type = lib.types.attrs;
      default = darkColors;
      readOnly = true;
      description = ''
        Tokyo Night color palette (night variant - dark theme).
        All colors are hex strings (e.g., "#1a1b26").
        Access via config.theme.dark.<color_name>.
      '';
    };

    light = lib.mkOption {
      type = lib.types.attrs;
      default = lightColors;
      readOnly = true;
      description = ''
        Tokyo Night color palette (day variant - light theme).
        All colors are hex strings (e.g., "#e1e2e7").
        Access via config.theme.light.<color_name>.
      '';
    };
  };

  config = {
    # Install tokyonight.nvim plugin (provides source colors)
    home.packages = [ tokyonightPlugin ];
  };
}
