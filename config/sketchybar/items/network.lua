#!/usr/bin/env lua

-- SketchyBar Network Monitor
--
-- Displays network type (WiFi/Ethernet/Disconnected) with signal strength
-- Shows download speed calculated from netstat
--
-- ICONS:
-- - WiFi signal strength based on dBm:
--   * Excellent (>-70dBm): 󰤟
--   * Good (-70 to -60dBm): 󰤢
--   * Fair (-60 to -50dBm): 󰤥
--   * Weak (≤-50dBm): 󰤨
-- - Ethernet: 󰈀
-- - Disconnected: 󰌙
--
-- SPEED CALCULATION:
-- TODO: find out why is value diffetrent than in btm
-- - Uses netstat -ibn for en0 interface
-- - Caches previous RX bytes and timestamp
-- - Speed = (current_rx - prev_rx) / time_diff
-- - Display: MB/s (>1MB), KB/s (>1KB), or B/s
--
-- CACHING:
-- - Signal cached for 10s to reduce system_profiler calls
-- - Speed cache stored in /tmp/sketchybar_network_cache
--
-- UPDATE FREQUENCY: 5 seconds
-- ? wouldn't it make sense to create a rust/zig/c program to upate the widget?

local colors = require("colors")
local icons = require("icons")

local CACHE_FILE = "/tmp/sketchybar_network_cache"
local SIGNAL_CACHE_FILE = "/tmp/sketchybar_network_signal"
local SIGNAL_CACHE_DURATION = 10

local network = sbar.add("item", "network", {
  position = "right",
  update_freq = 5,
  icon = {
    string = icons.wifi.disconnected,
    color = colors.icon,
  },
  label = {
    string = "N/A",
    color = colors.label,
  },
  padding_left = 4,
  padding_right = 4,
})

local function get_wifi_icon(signal_strength)
  if signal_strength >= -70 then
    return icons.wifi.signal.high
  elseif signal_strength >= -60 then
    return icons.wifi.signal.good
  elseif signal_strength >= -50 then
    return icons.wifi.signal.fair
  else
    return icons.wifi.signal.weak
  end
end

local function format_speed(bytes_per_sec)
  if bytes_per_sec >= 1024 * 1024 then
    return string.format("%.1f MB/s", bytes_per_sec / (1024 * 1024))
  elseif bytes_per_sec >= 1024 then
    return string.format("%.1f KB/s", bytes_per_sec / 1024)
  else
    return string.format("%d B/s", bytes_per_sec)
  end
end

local function get_cached_signal()
  local cache_file = io.open(SIGNAL_CACHE_FILE, "r")
  if cache_file then
    local timestamp = tonumber(cache_file:read("*l"))
    local signal = tonumber(cache_file:read("*l"))
    cache_file:close()

    local current_time = os.time()
    if current_time - timestamp < SIGNAL_CACHE_DURATION then
      return signal
    end
  end
  return nil
end

local function cache_signal(signal)
  local cache_file = io.open(SIGNAL_CACHE_FILE, "w")
  if cache_file then
    cache_file:write(os.time() .. "\n")
    cache_file:write(signal .. "\n")
    cache_file:close()
  end
end

local function update_speed()
  sbar.exec(
    "netstat -ibn | grep -e 'en0' | head -1 | awk '{print $7}'",
    function(rx_bytes_str)
      local current_rx = tonumber(rx_bytes_str)
      local current_time = os.time()

      if not current_rx then
        return
      end

      -- Read previous cache
      local cache_file = io.open(CACHE_FILE, "r")
      if cache_file then
        local prev_time = tonumber(cache_file:read("*l"))
        local prev_rx = tonumber(cache_file:read("*l"))
        cache_file:close()

        if prev_time and prev_rx then
          local time_diff = current_time - prev_time
          if time_diff > 0 then
            local bytes_diff = current_rx - prev_rx
            local speed = bytes_diff / time_diff
            network:set({ label = { string = format_speed(speed) } })
          else
            network:set({ label = { string = "0 B/s" } })
          end
        else
          -- First run after cache exists but couldn't read properly
          network:set({ label = { string = "0 B/s" } })
        end
      else
        -- Very first run - show 0 and initialize cache
        network:set({ label = { string = "0 B/s" } })
      end

      -- Write current cache for next update
      cache_file = io.open(CACHE_FILE, "w")
      if cache_file then
        cache_file:write(current_time .. "\n")
        cache_file:write(current_rx .. "\n")
        cache_file:close()
      end
    end
  )
end

local function update_network()
  -- Use ipconfig to check if connected (more reliable than networksetup)
  sbar.exec("ipconfig getifaddr en0", function(ip)
    local connected = ip and ip ~= "" and not ip:match("^%s*$")

    if not connected then
      network:set({
        icon = { string = icons.wifi.disconnected },
        label = { string = "Disconnected" },
      })
      -- Clear cache when disconnected
      os.remove(CACHE_FILE)
      os.remove(SIGNAL_CACHE_FILE)
      return
    end

    -- Get WiFi signal strength
    sbar.exec(
      "system_profiler SPAirPortDataType 2>/dev/null | grep 'Signal / Noise' | head -1 | awk '{print $4}'",
      function(signal_str)
        local signal = tonumber(signal_str)

        if signal then
          -- WiFi is connected
          cache_signal(signal)
          local icon = get_wifi_icon(signal)
          network:set({ icon = { string = icon } })
        else
          -- Connected but no WiFi signal - must be Ethernet
          network:set({ icon = { string = icons.wifi.ethernet } })
        end

        update_speed()
      end
    )
  end)
end

network:subscribe("routine", function()
  update_network()
end)

network:subscribe("mouse.clicked", function()
  sbar.exec("open 'x-apple.systempreferences:com.apple.preference.network'")
end)

update_network()
