#!/usr/bin/env lua

-- SketchyBar Battery Monitor
--
-- Displays battery percentage with icon based on charge level
-- Icon changes when charging vs discharging
--
-- ICONS:
-- - 90-100%: 󰂂
-- - 60-89%:  󰂀
-- - 30-59%:  󰁾
-- - 10-29%:  󰁻
-- - <10%:    󰂎
-- - Charging: 󰂄 (overrides percentage icon)
--
-- UPDATES:
-- - Polls every 120 seconds
-- - Subscribes to system_woke (after sleep/wake)
-- - Subscribes to power_source_change (plugged/unplugged)
--
-- CLICK ACTION:
-- - Try to open AlDente.app, fallback to System Settings Energy

local colors = require("colors")
local icons = require("icons")

local battery = sbar.add("item", "battery", {
  position = "right",
  update_freq = 120,
  icon = {
    string = icons.battery[100],
    color = colors.icon,
  },
  label = {
    string = "100%",
    color = colors.label,
  },
  padding_left = 4,
  padding_right = 4,
})

local function get_battery_icon(percentage, is_charging)
  if is_charging then
    return icons.battery.charging
  elseif percentage >= 90 then
    return icons.battery[100]
  elseif percentage >= 60 then
    return icons.battery[60]
  elseif percentage >= 30 then
    return icons.battery[40]
  elseif percentage >= 10 then
    return icons.battery[20]
  else
    return icons.battery[0]
  end
end

local function update_battery()
  sbar.exec("pmset -g batt", function(result)
    local percentage = result:match("(%d+)%%")
    local is_charging = result:match("AC Power") ~= nil

    if percentage then
      percentage = tonumber(percentage)
      local icon = get_battery_icon(percentage, is_charging)

      battery:set({
        icon = { string = icon },
        label = { string = percentage .. "%" },
      })
    end
  end)
end

battery:subscribe(
  { "routine", "system_woke", "power_source_change" },
  function()
    update_battery()
  end
)

battery:subscribe("mouse.clicked", function()
  sbar.exec(
    "open -a 'AlDente' 2>/dev/null || open 'x-apple.systempreferences:com.apple.preference.battery'"
  )
end)

update_battery()
