-- @description ReaProjectLink [Dev]
-- @author ReaProjectLink contributors
-- @about
--   Runs ReaProjectLink directly from this development checkout.

local source = debug.getinfo(1, "S").source:sub(2)
local script_dir = source:match("^(.*)[/\\]")
if not script_dir then
  reaper.ShowMessageBox(
    "Could not resolve the development checkout path.",
    "ReaProjectLink [Dev]",
    0
  )
  return
end

REAPROJECTLINK_DEV = true
dofile(script_dir .. "/ReaProjectLink/ReaProjectLink.lua")
