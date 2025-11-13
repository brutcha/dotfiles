#!/usr/bin/env lua

-- SketchyBar Conditional Items Manager
--
-- Manages dynamic items that appear/disappear based on app availability
-- Integrated into main config using routine events (no separate LaunchAgent)
--
-- ITEMS MANAGED:
-- - Docker Desktop (docker)
-- - Watchman (watchman)
-- - Insync (insync)
-- - Elgato Control Center (elgato)
-- - Proton Mail Bridge (protonmail)
-- - Separator (appears when first conditional item appears)
--
-- UPDATE FREQUENCY: 5 seconds

local icons = require("icons")
local colors = require("colors")

-- Track which items are currently visible
local visible_items = {}

-- Item configurations
local items = {
  docker = {
    process = "Docker Desktop",
    icon = icons.app.docker,
    check = "pgrep -x 'Docker Desktop' >/dev/null 2>&1",
    click = function()
      sbar.exec("open -a 'Docker Desktop'")
    end,
  },
  watchman = {
    process = "watchman",
    icon = icons.app.watch,
    color = colors.yellow,
    check = "pgrep -x 'watchman' >/dev/null 2>&1",
  },
  insync = {
    process = "Insync",
    icon = icons.app.cloud,
    check = "pgrep -x 'Insync' >/dev/null 2>&1",
    click = function()
      sbar.exec("open -a 'Insync'")
    end,
  },
  elgato = {
    process = "Control Center",
    icon = icons.app.light,
    check = "pgrep -f 'Control Center' >/dev/null 2>&1",
    click = function()
      sbar.exec("open -a 'Elgato Control Center'")
    end,
  },
  protonmail = {
    process = "Bridge",
    icon = icons.app.mail,
    check = "pgrep -x 'Bridge' >/dev/null 2>&1",
    click = function()
      sbar.exec("open -a 'Proton Mail Bridge'")
    end,
  },
}

-- Create divider (will be shown/hidden based on conditional items)
local divider = sbar.add("item", "conditional.divider", {
  position = "right",
  icon = { drawing = false },
  label = {
    string = icons.divider,
    color = colors.taskbar_divider,
  },
  padding_left = 2,
  padding_right = 8,
  drawing = false, -- Initially hidden
})

-- Create all conditional items (initially hidden)
for name, config in pairs(items) do
  local item = sbar.add("item", "conditional." .. name, {
    position = "right",
    icon = {
      string = config.icon,
      color = config.color or colors.icon,
    },
    label = { drawing = false },
    padding_left = 4,
    padding_right = 4,
    drawing = false, -- Initially hidden
  })

  -- Add click handler if defined
  if config.click then
    item:subscribe("mouse.clicked", config.click)
  end

  visible_items[name] = false
end

-- Update visibility of all conditional items
local function update_conditional_items()
  local any_visible = false
  local items_count = 0
  local items_processed = 0

  for name, config in pairs(items) do
    -- Count the items synchronously
    items_count = items_count + 1

    sbar.exec(config.check, function(_, exit_code)
      local should_show = exit_code == 0
      local currently_visible = visible_items[name]

      if should_show and not currently_visible then
        -- Show item
        sbar.set("conditional." .. name, { drawing = true })
        visible_items[name] = true
        any_visible = true
      elseif not should_show and currently_visible then
        -- Hide item
        sbar.set("conditional." .. name, { drawing = false })
        visible_items[name] = false
      elseif should_show then
        any_visible = true
      end

      -- Update asynchronously proccessed count
      items_processed = items_processed + 1

      if items_count == items_processed then
        -- Show/hide divider based on whether any conditional items are visible
        divider:set({ drawing = any_visible })
      end
    end)
  end
end

-- Create invisible timer item to trigger periodic checks
local timer = sbar.add("item", {
  position = "popup.conditional.divider",
  update_freq = 5,
  drawing = false,
})

timer:subscribe("routine", function()
  update_conditional_items()
end)

-- Run initial check
update_conditional_items()
