#!/usr/bin/env lua

-- SketchyBar Aerospace Workspace Indicators
--
-- Displays workspace numbers with dynamic colors based on state:
-- - Focused: Purple background with dark text
-- - Visible (on another monitor): Semi-transparent purple with dark text
-- - Inactive: Semi-transparent blue with light text
--
-- INTEGRATION:
-- Subscribes to aerospace_workspace_change event
-- Click handler switches to workspace
-- Triggers workspaces_loaded once initialized

local colors = require("colors")
local icons = require("icons")

sbar.exec("aerospace list-workspaces --all", function(workspaces)
  for workspace_id in workspaces:gmatch("[^\r\n]+") do
    -- Get icon from icons.space table
    local workspace_num = tonumber(workspace_id)
    local icon = (workspace_num and icons.space[workspace_num]) or workspace_id

    local space = sbar.add("item", "space." .. workspace_id, {
      position = "left",
      icon = {
        string = icon,
        padding_left = 6,
        padding_right = 6,
        font = { size = 12.0 },
      },
      label = { drawing = false },
      background = {
        color = colors.workspace_inactive_bg,
        corner_radius = 6,
        height = 20,
        drawing = true,
      },
      padding_left = 0,
      padding_right = 4,
    })

    -- Subscribe to workspace change event
    space:subscribe("aerospace_workspace_change", function(env)
      local focused_workspace = env.FOCUSED_WORKSPACE
      local is_focused = (focused_workspace == workspace_id)

      -- Update colors based on focus state
      if is_focused then
        space:set({
          background = { color = colors.workspace_active_bg },
          icon = { color = colors.workspace_active_fg },
        })
      else
        space:set({
          background = { color = colors.workspace_inactive_bg },
          icon = { color = colors.workspace_inactive_fg },
        })
      end
    end)

    -- Click handler to switch workspace
    space:subscribe("mouse.clicked", function()
      sbar.exec("aerospace workspace " .. workspace_id)
    end)
  end

  -- Load front_app after workspaces are created
  require("items.front_app")()

  -- Trigger initial workspace change to set correct colors
  sbar.exec("aerospace list-workspaces --focused", function(focused_ws)
    local focused = focused_ws:gsub("^%s*(.-)%s*$", "%1")
    sbar.exec(
      "sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE="
        .. focused
    )
  end)
end)
