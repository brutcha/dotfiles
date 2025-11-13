#!/usr/bin/env lua

-- SketchyBar Clock Item
--
-- Displays current date and time, updates every 10 seconds
-- Click to open Thunderbird email client
--
-- FUNCTIONALITY:
-- - Updates every 10 seconds via "routine" event
-- - Format: DD/MM HH:MM (24-hour format)
-- - Click: Opens Thunderbird application
--
-- USAGE:
-- require("items.clock")
--

local colors = require("colors")
local icons = require("icons")

local clock = sbar.add("item", "clock", {
  position = "right",
  update_freq = 10,

  icon = {
    string = icons.calendar,
    color = colors.icon_primary,
  },

  label = {
    color = colors.label_primary,
    padding_right = 8,
  },

  click_script = "open -a 'Thunderbird'",
})

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

-- Update time display every 10 seconds
clock:subscribe({ "routine", "forced", "system_woke" }, function()
  clock:set({ label = os.date("%d/%m %H:%M") })
end)

--------------------------------------------------------------------------------
-- Initial Setup
--------------------------------------------------------------------------------

clock:set({ label = os.date("%d/%m %H:%M") })
