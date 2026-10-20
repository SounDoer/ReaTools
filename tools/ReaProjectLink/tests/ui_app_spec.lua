local function equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

local function create_shell(display_name, observed)
  local ImGui = {
    CreateListClipper = function() return {} end,
    Attach = function() end,
    Cond_Always = function() return 1 end,
    Cond_FirstUseEver = function() return 2 end,
    SetNextWindowSize = function() end,
    Begin = function(_, title)
      observed.title = title
      return false, true
    end,
  }
  local adapter = {
    project_token = function() return "project" end,
  }
  local design_system = {
    adapter = {
      set_theme = function() end,
      push_base = function() end,
      pop_base = function() end,
    },
    components = {},
    patterns = {},
  }
  return require("reaprojectlink.ui.app").create({
    ImGui = ImGui,
    ctx = {},
    reaper = {
      GetExtState = function() return "dark" end,
      time_precise = function() return 0 end,
    },
    adapter = adapter,
    fs = {},
    services = {},
    version = "test",
    display_name = display_name,
    design_system = design_system,
  })
end

local tests = {}

function tests.panel_uses_runtime_display_name()
  local observed = {}
  local shell = create_shell("ReaProjectLink [Dev]", observed)
  shell.draw()
  equal(observed.title, "ReaProjectLink [Dev]", "panel title")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
