local source = debug.getinfo(1, "S").source:sub(2)
local tests_dir = source:match("^(.*)[/\\]")
local package_root = tests_dir and tests_dir:match("^(.*)[/\\]tests$")

if not package_root then return end

package.path = package_root .. "/lib/?.lua;" .. package.path

local ok, result = xpcall(function()
  local passed = 0
  for _, spec in ipairs(dofile(tests_dir .. "/specs.lua")) do
    passed = passed + dofile(tests_dir .. "/" .. spec)
  end
  return passed
end, debug.traceback)

local result_path = tests_dir .. "/.last-result"
local file = io.open(result_path, "w")
if file then
  if ok then
    file:write(string.format("PASS %d ReaToolUI tests\n", result))
  else
    file:write("FAIL\n", tostring(result), "\n")
  end
  file:close()
end

reaper.Main_OnCommand(40004, 0)
