#!/usr/bin/env lua

-- SketchyBar Bar Configuration
--
-- Configures the main bar appearance and behavior
-- Uses Tokyo Night theme colors for consistent visual design
--
-- CONFIGURATION OPTIONS:
-- - position: top/bottom
-- - height: bar height in pixels
-- - color: background color (Tokyo Night bg)
-- - topmost: whether bar stays above other windows
-- - sticky: whether bar appears on all spaces
-- - display: which display to show bar on
-- - padding: left/right padding in pixels
-- - shadow: enable/disable bar shadow
-- - blur_radius: background blur effect (0 = disabled)
--
-- DOCUMENTATION:
-- https://felixkratz.github.io/SketchyBar/config/bar

local colors = require("colors")

sbar.bar({
  position = "top",
  height = 32,
  color = colors.bar_bg,
  border_color = colors.transparent,
  border_width = 0,
  sticky = true,
  display = "main",
  padding_left = 12,
  padding_right = 12,
  shadow = false,
  blur_radius = 0,
  y_offset = 0,
  margin = 0,
  corner_radius = 0,
})
