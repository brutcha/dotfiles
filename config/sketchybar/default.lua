#!/usr/bin/env lua

-- SketchyBar Default Item Properties
--
-- Sets default styling for all items unless explicitly overridden
-- Establishes consistent typography, spacing, and colors across the bar
--
-- APPLIED TO:
-- All items inherit these properties unless they specify their own
--
-- PROPERTIES:
-- - padding: space around items
-- - icon: icon-specific styling (font, color, padding)
-- - label: label-specific styling (font, color, padding)
--
-- DOCUMENTATION:
-- https://felixkratz.github.io/SketchyBar/config/items

local colors = require("colors")

sbar.default({
  padding_left = 4,
  padding_right = 4,

  icon = {
    font = {
      family = "JetBrainsMonoNL Nerd Font",
      style = "Bold",
      size = 14.0,
    },
    color = colors.icon,
    padding_left = 4,
    padding_right = 4,
    background = {
      drawing = false,
    },
  },

  label = {
    font = {
      family = "JetBrainsMonoNL Nerd Font",
      style = "Regular",
      size = 14.0,
    },
    color = colors.label,
    padding_left = 4,
    padding_right = 4,
    background = {
      drawing = false,
    },
  },

  background = {
    drawing = false,
    color = colors.transparent,
    border_width = 0,
    corner_radius = 0,
  },
})
