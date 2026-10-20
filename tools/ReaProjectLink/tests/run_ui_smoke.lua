local source = debug.getinfo(1, "S").source:sub(2)
local tests_dir = assert(source:match("^(.*)[/\\]"))
local root = assert(tests_dir:match("^(.*)[/\\]tests$"))

-- Read by ReaProjectLink.lua only when REAPROJECTLINK_UI_SMOKE_RESULT is set.
REAPROJECTLINK_SMOKE_SCENARIOS = dofile(root .. "/tests/ui_smoke_scenarios.lua")

-- REAPROJECTLINK_UI_CAPTURE=<n> holds scenario n on screen for screenshots.
local capture = tonumber(os.getenv("REAPROJECTLINK_UI_CAPTURE") or "")
if capture then
  local scenario = assert(REAPROJECTLINK_SMOKE_SCENARIOS[capture], "no smoke scenario " .. capture)
  REAPROJECTLINK_SMOKE_SCENARIOS = {}
  for i = 1, 600 do REAPROJECTLINK_SMOKE_SCENARIOS[i] = scenario end
end

dofile(root .. "/ReaProjectLink/ReaProjectLink.lua")
