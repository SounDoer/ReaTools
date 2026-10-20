local function equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

local source = debug.getinfo(1, "S").source:sub(2)
local tests_dir = source:match("^(.*)[/\\]")
local root = tests_dir and tests_dir:match("^(.*)[/\\]tests$")

local tests = {}

function tests.dev_launcher_marks_and_loads_checkout()
  local original_dofile = dofile
  local original_dev = REAPROJECTLINK_DEV
  local loaded_path
  dofile = function(path) loaded_path = path end
  REAPROJECTLINK_DEV = nil

  local ok, err = pcall(original_dofile, root .. "/ReaProjectLink_Dev.lua")

  dofile = original_dofile
  local dev = REAPROJECTLINK_DEV
  REAPROJECTLINK_DEV = original_dev

  assert(ok, err)
  equal(dev, true, "development mode")
  equal(loaded_path, root .. "/ReaProjectLink/ReaProjectLink.lua", "checkout entry")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
