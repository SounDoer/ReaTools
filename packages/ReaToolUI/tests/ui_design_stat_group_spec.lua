local module = require("reaui.design_stat_group")

local function equal(actual, expected, label)
  if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local TOKENS = {
  ["semantic.space.list.gap"] = 8,
  ["semantic.space.inset.padding_x"] = 12,
  ["semantic.space.inset.padding_y"] = 8,
}
local LINE_HEIGHTS = { metric = 22, metadata = 12 }

local function fake()
  local calls = { rects = {}, texts = {}, dummies = {}, clips = 0, popped_clips = 0 }
  local role
  local ImGui = {}
  function ImGui.GetContentRegionAvail() return 300, 100 end
  function ImGui.GetCursorScreenPos() return 10, 20 end
  function ImGui.GetWindowDrawList() return "draw-list" end
  function ImGui.GetTextLineHeight() return LINE_HEIGHTS[role] or 14 end
  function ImGui.DrawList_AddRectFilled(_, x1, y1, x2, y2, color)
    table.insert(calls.rects, { x1 = x1, y1 = y1, x2 = x2, y2 = y2, color = color })
  end
  function ImGui.DrawList_AddText(_, x, y, color, text)
    table.insert(calls.texts, { x = x, y = y, color = color, text = text, role = role })
  end
  function ImGui.DrawList_PushClipRect() calls.clips = calls.clips + 1 end
  function ImGui.DrawList_PopClipRect() calls.popped_clips = calls.popped_clips + 1 end
  function ImGui.Dummy(_, w, h) table.insert(calls.dummies, { w = w, h = h }) end
  local adapter = {
    resolve = function(id) return TOKENS[id] or id end,
    with_text = function(next_role, renderer)
      local previous = role
      role = next_role
      local result = renderer()
      role = previous
      return result
    end,
  }
  return module.create(ImGui, "ctx", adapter), calls
end

local STATS = {
  { label = "Tracks", value = 4 },
  { label = "Markers", value = "12" },
  { label = "Regions", value = 2 },
}

local tests = {}

function tests.tiles_share_width_equally()
  local group, calls = fake()
  group.draw({ id = "scope", stats = STATS })
  equal(#calls.rects, 3, "three tiles")
  local width = (300 - 16) / 3
  for index, rect in ipairs(calls.rects) do
    assert(math.abs((rect.x2 - rect.x1) - width) < 0.001, "tile " .. index .. " width")
    assert(math.abs(rect.x1 - (10 + (index - 1) * (width + 8))) < 0.001, "tile " .. index .. " x")
    equal(rect.color, "component.stat_group.background", "tile color")
  end
end

function tests.uses_metric_and_metadata_fonts()
  local group, calls = fake()
  group.draw({ id = "scope", stats = STATS })
  equal(calls.texts[1].text, "4", "number value is text")
  equal(calls.texts[1].role, "metric", "value font")
  equal(calls.texts[1].x, 10 + 12, "value inset x")
  equal(calls.texts[1].y, 20 + 8, "value inset y")
  equal(calls.texts[2].text, "Tracks", "label")
  equal(calls.texts[2].role, "metadata", "label font")
  equal(calls.texts[2].y, 20 + 8 + 22, "label below value")
  equal(calls.texts[2].color, "component.stat_group.label", "label color")
  equal(calls.clips, 3, "values are clipped per tile")
  equal(calls.clips, calls.popped_clips, "clip stack")
end

function tests.reserves_one_row_with_dummy()
  local group, calls = fake()
  local result = group.draw({ id = "scope", stats = STATS })
  equal(#calls.dummies, 1, "one dummy")
  equal(calls.dummies[1].w, 300, "full width")
  equal(calls.dummies[1].h, 22 + 12 + 16, "tile height")
  equal(#result.events, 0, "no events")
end

function tests.rejects_fewer_than_two_or_more_than_four()
  local group = fake()
  assert(not pcall(function() group.draw({ id = "s", stats = { STATS[1] } }) end), "one rejected")
  assert(not pcall(function()
    group.draw({ id = "s", stats = { STATS[1], STATS[2], STATS[3], STATS[1], STATS[2] } })
  end), "five rejected")
  assert(not pcall(function() group.draw({ id = "s", stats = { STATS[1], { label = "", value = 1 } } }) end),
    "empty label rejected")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
