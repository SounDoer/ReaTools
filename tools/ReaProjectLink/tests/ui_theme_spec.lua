local theme = require("reaprojectlink.ui.theme")

local function equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

local tests = {}

function tests.resolves_explicit_and_automatic_modes()
  equal(theme.resolve("light", nil), "light", "explicit light")
  equal(theme.resolve("dark", { 255, 255, 255 }), "dark", "explicit dark wins")
  equal(theme.resolve("auto", { 240, 240, 240 }), "light", "bright REAPER theme")
  equal(theme.resolve("auto", { 30, 30, 30 }), "dark", "dark REAPER theme")
  equal(theme.resolve("auto", nil), "dark", "unknown REAPER theme")
end

function tests.stores_the_preference_globally()
  local stored = {}
  local reaper_api = {}
  function reaper_api.GetExtState(section, key) return stored[section .. "/" .. key] or "" end
  function reaper_api.SetExtState(section, key, value, persist)
    assert(persist, "preference persists across sessions")
    stored[section .. "/" .. key] = value
  end
  equal(theme.load_preference(reaper_api), "auto", "default preference")
  stored["ReaProjectLink/theme"] = "purple"
  equal(theme.load_preference(reaper_api), "auto", "invalid preference")
  theme.save_preference(reaper_api, "light")
  equal(theme.load_preference(reaper_api), "light", "saved preference")
end

function tests.reads_the_reaper_background()
  local reaper_api = {}
  function reaper_api.GetThemeColor() return -1 end
  function reaper_api.ColorFromNative() error("not called for a missing color") end
  equal(theme.reaper_background(reaper_api), nil, "missing theme color")
  function reaper_api.GetThemeColor(name)
    equal(name, "col_main_bg2", "theme color name")
    return 1234
  end
  function reaper_api.ColorFromNative(value)
    equal(value, 1234, "native color")
    return 10, 20, 30
  end
  local rgb = theme.reaper_background(reaper_api)
  equal(rgb[1] .. "," .. rgb[2] .. "," .. rgb[3], "10,20,30", "rgb")
end

local function theme_api(background)
  local stored = "auto"
  return {
    GetExtState = function() return stored end,
    SetExtState = function(_, _, value) stored = value end,
    GetThemeColor = function() return 1 end,
    ColorFromNative = function() return table.unpack(background) end,
  }
end

function tests.runtime_theme_owns_preference_not_visual_tokens()
  local instance = theme.create({}, {}, theme_api({ 20, 20, 20 }))
  equal(instance.mode, "dark", "dark host mode")
  equal(instance.colors, nil, "no product palette")
  equal(instance.fonts, nil, "no product fonts")
  equal(instance.push, nil, "no product style stack")
end

function tests.runtime_theme_follows_auto_host_mode()
  local instance = theme.create({}, {}, theme_api({ 245, 245, 245 }))
  equal(instance.mode, "light", "light host mode")
end

function tests.runtime_theme_persists_explicit_mode()
  local reaper_api = theme_api({ 245, 245, 245 })
  local instance = theme.create({}, {}, reaper_api)
  instance:set_preference("dark")
  equal(instance.preference, "dark", "stored preference")
  equal(instance.mode, "dark", "explicit mode")
  equal(theme.load_preference(reaper_api), "dark", "persisted preference")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
