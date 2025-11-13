#!/usr/bin/env lua

-- SketchyBar Volume Control
--
-- Displays current volume level with icon
-- Supports mute toggle on click and volume adjustment via scroll
--
-- INTERACTIONS:
-- - Click: Toggle mute
-- - Scroll up: Increase volume by 6%
-- - Scroll down: Decrease volume by 6%
--
-- UPDATES:
-- - Subscribes to volume_change event (macOS native)
-- - Subscribes to mouse.scrolled for volume adjustment
-- - Subscribes to mouse.clicked for mute toggle

local colors = require("colors")
local icons = require("icons")

local volume = sbar.add("item", "volume", {
  position = "right",
  icon = {
    string = icons.volume.high,
    color = colors.icon,
  },
  label = {
    string = "100%",
    color = colors.label,
  },
  padding_left = 4,
  padding_right = 4,
})

local function get_volume_icon(volume_level, is_muted)
  if is_muted then
    return icons.volume.muted
  elseif volume_level >= 60 then
    return icons.volume.high
  elseif volume_level >= 30 then
    return icons.volume.medium
  elseif volume_level > 0 then
    return icons.volume.low
  else
    return icons.volume.muted
  end
end

local function update_volume()
  sbar.exec("osascript -e 'get volume settings'", function(result)
    local volume_level = result:match("output volume:(%d+)")
    local is_muted = result:match("output muted:(%w+)") == "true"

    if volume_level then
      volume_level = tonumber(volume_level)
      local icon = get_volume_icon(volume_level, is_muted)

      volume:set({
        icon = { string = icon },
        label = { string = volume_level .. "%" },
      })
    end
  end)
end

volume:subscribe("volume_change", function()
  update_volume()
end)

volume:subscribe("mouse.clicked", function()
  sbar.exec("osascript -e 'get volume settings'", function(result)
    local is_muted = result:match("output muted:(%w+)") == "true"
    local new_mute_state = not is_muted

    sbar.exec(
      "osascript -e 'set volume output muted "
        .. tostring(new_mute_state)
        .. "'",
      function()
        update_volume()
      end
    )
  end)
end)

volume:subscribe("mouse.scrolled", function(env)
  sbar.exec("osascript -e 'get volume settings'", function(result)
    local volume_level = tonumber(result:match("output volume:(%d+)"))

    if volume_level then
      local delta = tonumber(env.SCROLL_DELTA)
      local new_volume = volume_level + (delta > 0 and 6 or -6)
      new_volume = math.max(0, math.min(100, new_volume))

      sbar.exec(
        "osascript -e 'set volume output volume " .. new_volume .. "'",
        function()
          update_volume()
        end
      )
    end
  end)
end)

update_volume()
