local function equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

local identity = require("reaprojectlink.runtime_identity")
local tests = {}

function tests.production_uses_product_name()
  equal(identity.display_name(false), "ReaProjectLink", "production name")
end

function tests.development_is_visibly_distinct()
  equal(identity.display_name(true), "ReaProjectLink [Dev]", "development name")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
