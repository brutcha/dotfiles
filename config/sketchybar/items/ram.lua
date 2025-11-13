#!/usr/bin/env lua

-- SketchyBar RAM Monitor
--
-- Displays used RAM in GB calculated from vm_stat
--
-- CALCULATION:
-- TODO: Find out why calue in btm is different than widget value
-- - Get page size from pagesize command
-- - Parse vm_stat for:
--   * Pages active
--   * Pages wired down
--   * Pages occupied by compressor
-- - Used = (active + wired + compressed) * page_size
-- - Display: X.XGB (used memory in GB)
--
-- UPDATE FREQUENCY: 5 seconds
--
-- CLICK ACTION:
-- - Open btm (bottom) in Ghostty

local colors = require("colors")
local icons = require("icons")

local ram = sbar.add("item", "ram", {
  position = "right",
  update_freq = 5,
  icon = {
    string = icons.ram,
    color = colors.icon,
  },
  label = {
    string = "0.0GB",
    color = colors.label,
  },
  padding_left = 4,
  padding_right = 4,
})

local function update_ram()
  sbar.exec("pagesize", function(page_size_str)
    local page_size = tonumber(page_size_str)

    if not page_size then
      return
    end

    sbar.exec("vm_stat", function(vm_output)
      local pages_active = tonumber(vm_output:match("Pages active:%s*(%d+)"))
      local pages_wired = tonumber(vm_output:match("Pages wired down:%s*(%d+)"))
      local pages_compressed =
        tonumber(vm_output:match("Pages occupied by compressor:%s*(%d+)"))

      if pages_active and pages_wired and pages_compressed then
        local used_bytes = (pages_active + pages_wired + pages_compressed)
          * page_size
        local used_gb = used_bytes / (1024 * 1024 * 1024)

        ram:set({
          label = { string = string.format("%.1fGB", used_gb) },
        })
      end
    end)
  end)
end

ram:subscribe("routine", function()
  update_ram()
end)

ram:subscribe("mouse.clicked", function()
  sbar.exec("open -a Ghostty -n --args --title=floating -e btm")
end)

update_ram()
