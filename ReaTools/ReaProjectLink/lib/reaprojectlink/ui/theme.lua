-- ReaProjectLink owns only the user's theme preference. ReaToolUI owns all
-- visual tokens, fonts, and style application.
local M = {}

M.PREFERENCES = { "auto", "light", "dark" }
M.EXT_SECTION = "ReaProjectLink"
M.EXT_KEY = "theme"

function M.resolve(preference, background)
  if preference == "light" or preference == "dark" then return preference end
  if background then
    local luminance = (0.2126 * background[1] + 0.7152 * background[2] +
      0.0722 * background[3]) / 255
    if luminance >= 0.5 then return "light" end
  end
  return "dark"
end

function M.load_preference(reaper_api)
  local value = reaper_api.GetExtState(M.EXT_SECTION, M.EXT_KEY)
  for _, name in ipairs(M.PREFERENCES) do
    if name == value then return value end
  end
  return "auto"
end

function M.save_preference(reaper_api, value)
  reaper_api.SetExtState(M.EXT_SECTION, M.EXT_KEY, value, true)
end

function M.reaper_background(reaper_api)
  if not reaper_api.GetThemeColor then return nil end
  local native = reaper_api.GetThemeColor("col_main_bg2", 0)
  if not native or native < 0 then return nil end
  local r, g, b = reaper_api.ColorFromNative(native)
  return { r, g, b }
end

function M.create(_, _, reaper_api)
  local self = {
    preference = M.load_preference(reaper_api),
    mode = "dark",
  }

  function self:refresh()
    self.mode = M.resolve(self.preference, M.reaper_background(reaper_api))
  end

  function self:set_preference(value)
    self.preference = value
    M.save_preference(reaper_api, value)
    self:refresh()
  end

  -- Used by the UI smoke test: changes the mode without touching ExtState.
  function self:use(value)
    self.preference = value
    self:refresh()
  end

  self:refresh()
  return self
end

return M
