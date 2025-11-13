#!/usr/bin/env lua

-- SketchyBar Lock Item
--
-- Simple lock icon that triggers screen lock when clicked
-- Positioned at the leftmost edge of the bar
--
-- FUNCTIONALITY:
-- - Displays lock icon
-- - Click: Locks the screen immediately via osascript
--
-- USAGE:
-- require("items.lock")
--
-- INTEGRATION:
-- Uses osascript to trigger Control+Command+Q (macOS lock shortcut)

local colors = require("colors")
local icons = require("icons")

local lock = sbar.add("item", "lock", {
  position = "left",
  icon = {
    string = icons.lock,
    color = colors.icon_primary,
  },
  label = {
    drawing = false,
  },
  padding_left = 4,
  padding_right = 4,
})

lock:subscribe("mouse.clicked", function()
  sbar.exec(
    'osascript -e \'tell application "System Events" to keystroke "q" using {control down, command down}\''
  )
end)
