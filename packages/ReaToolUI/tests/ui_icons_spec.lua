local icons = require("reaui.icons")

local function equal(actual, expected, label)
  if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local tests = {}

function tests.icons_include_refresh()
  local found = false
  for _, name in ipairs(icons.NAMES) do found = found or name == "refresh" end
  equal(found, true, "refresh listed")
  local calls = { arcs = 0, strokes = 0, lines = 0 }
  local ImGui = {
    DrawList_PathArcTo = function() calls.arcs = calls.arcs + 1 end,
    DrawList_PathStroke = function() calls.strokes = calls.strokes + 1 end,
    DrawList_AddLine = function() calls.lines = calls.lines + 1 end,
  }
  equal(icons.draw(ImGui, "dl", "refresh", 0, 0, 16, 0xffffffff), true, "drawn")
  equal(calls.arcs, 1, "one arc")
  equal(calls.strokes, 1, "arc stroked")
  assert(calls.lines >= 1, "arrowhead")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
