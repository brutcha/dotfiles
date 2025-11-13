#!/usr/bin/env lua

-- SketchyBar Front App Indicator
--
-- Displays the name of the currently focused application
-- Hides when the focused workspace has no windows
--
-- INTEGRATION:
-- Waits for workspaces_loaded event to ensure correct positioning
-- Subscribes to front_app_switched and aerospace_workspace_change events

local colors = require("colors")

return function()
  local front_app = sbar.add("item", "front_app", {
    position = "left",
    update_freq = 2,
    icon = {
      drawing = false,
    },
    label = {
      string = "",
      color = colors.label,
    },
    padding_left = 8,
    padding_right = 4,
  })

  local function update_front_app()
    sbar.exec(
      "aerospace list-windows --focused --format '%{app-name}' 2>&1",
      function(app_name)
        local trimmed = app_name and app_name:gsub("^%s*(.-)%s*$", "%1") or ""

        if trimmed ~= "" and not trimmed:match("^No window") then
          front_app:set({ label = trimmed })
        else
          front_app:set({ label = "" })
        end
      end
    )
  end

  front_app:subscribe(
    { "front_app_switched", "aerospace_workspace_change", "routine" },
    function()
      update_front_app()
    end
  )

  update_front_app()
end
