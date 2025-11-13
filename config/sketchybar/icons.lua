#!/usr/bin/env lua

-- SketchyBar Icon Definitions
--
-- Nerd Font icon mappings for consistent icon usage across all items
-- Requires: JetBrainsMonoNL Nerd Font (installed via nix)
--
-- USAGE:
-- local icons = require("icons")
-- item:set({ icon = { string = icons.lock } })
-- item:set({ icon = { string = icons.battery.charging } })
--
-- ICON REFERENCE:
-- Find more icons at: https://www.nerdfonts.com/cheat-sheet
-- Copy the icon character directly into this file

--------------------------------------------------------------------------------
-- System Icons
--------------------------------------------------------------------------------

return {
  -- System actions
  lock = "󰌾",
  power = "󰐥",

  -- Time
  clock = "",
  calendar = "",

  -- Battery icons (state-based)
  battery = {
    charging = "󰂄",
    [100] = "󰂂",
    [80] = "󰂂",
    [60] = "󰂀",
    [40] = "󰁾",
    [20] = "󰁻",
    [0] = "󰂎",
  },

  -- Volume icons (state-based)
  volume = {
    high = "󰕾",
    medium = "󰖀",
    low = "󰕿",
    muted = "󰖁",
  },

  -- Network icons
  wifi = {
    connected = "󰤨",
    disconnected = "󰌙",
    ethernet = "󰈀",
    signal = {
      high = "󰤨",
      good = "󰤥",
      fair = "󰤢",
      weak = "󰤟",
    },
  },

  -- System resources
  ram = "",
  cpu = "󰻠",
  disk = "󰋊",

  -- Applications (for conditional items)
  app = {
    docker = "󰡨",
    terminal = "",
    mail = "󰇰",
    cloud = "󰓦",
    light = "󱩎",
    watch = "󰈈",
  },

  -- Workspace/Space indicators
  space = {
    [1] = "1",
    [2] = "2",
    [3] = "3",
    [4] = "4",
    [5] = "5",
    [6] = "6",
    [7] = "7",
    [8] = "8",
    [9] = "9",
    [10] = "10",
  },

  -- UI elements
  divider = "",
  chevron = {
    left = "",
    right = "",
    up = "",
    down = "",
  },

  -- Status indicators
  status = {
    success = "",
    error = "",
    warning = "",
    info = "",
  },

  -- Media controls
  media = {
    play = "󰐊",
    pause = "󰏤",
    next = "󰒭",
    prev = "󰒮",
  },
}
