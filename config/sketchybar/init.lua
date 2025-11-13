#!/usr/bin/env lua

-- SketchyBar Main Configuration Entry Point
--
-- Lua-based configuration using SbarLua module
-- Integrated with Aerospace window manager and Tokyo Night theme

--------------------------------------------------------------------------------
-- Load Configuration Modules
--------------------------------------------------------------------------------

require("bar")
require("default")

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

sbar.subscribe("aerospace_workspace_change")

--------------------------------------------------------------------------------
-- Load Items
--------------------------------------------------------------------------------

-- Left side
require("items.lock")
require("items.spaces") -- Also loads front_app

-- Right side
require("items.clock")
require("items.volume")
require("items.battery")
require("items.network")
require("items.ram")
require("items.conditional")
