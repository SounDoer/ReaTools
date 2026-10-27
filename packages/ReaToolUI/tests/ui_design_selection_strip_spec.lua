local module = require("reaui.design_selection_strip")

local function equal(actual, expected, label)
  if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local ACTIONS = { { id = "register", label = "Register" }, { id = "unregister", label = "Unregister" } }
local KINDS = {
  { label = "Tracks", value = 4 }, { label = "Markers", value = 0 }, { label = "Regions", value = 2 },
}

-- Text is 7 units per character; heading lines are 20 high, other roles 16.
-- Text advances the cursor by its height plus 4 units of item spacing.
local function fake(options)
  options = options or {}
  local calls = { texts = {}, pushed = 0, popped = 0 }
  local cursor = { x = 10, y = 6 }
  local role = "body"
  local ImGui = { Col_Text = 1, StyleVar_ItemSpacing = 2 }
  function ImGui.PushStyleColor() calls.pushed = calls.pushed + 1 end
  function ImGui.PopStyleColor() calls.popped = calls.popped + 1 end
  function ImGui.GetStyleVar() return 8, 4 end
  function ImGui.GetContentRegionAvail() return options.available or 400, 100 end
  function ImGui.GetCursorPosX() return cursor.x end
  function ImGui.GetCursorPosY() return cursor.y end
  function ImGui.SetCursorPos(_, x, y) cursor.x, cursor.y = x, y end
  function ImGui.GetTextLineHeight() return role == "heading" and 20 or 16 end
  function ImGui.CalcTextSize(_, text) return #text * 7, 16 end
  function ImGui.Text(_, value)
    table.insert(calls.texts, { text = value, role = role, x = cursor.x, y = cursor.y, color = calls.color })
    cursor.x, cursor.y = 10, cursor.y + ImGui.GetTextLineHeight() + 4
  end
  local adapter = {
    resolve = function(id)
      if id == "semantic.space.control.gap" then return 8 end
      return id
    end,
    with_text = function(next_role, renderer)
      local previous = role
      role = next_role
      local a, b = renderer()
      role = previous
      return a, b
    end,
  }
  local push = ImGui.PushStyleColor
  function ImGui.PushStyleColor(_, _, color) calls.color = color; push() end
  local deps = {
    action_bar = { draw = function(bar_options)
      calls.bar = bar_options; calls.bar_x, calls.bar_y = cursor.x, cursor.y
      return { events = {}, action = options.bar_action }
    end },
  }
  return module.create(ImGui, "ctx", adapter, deps), calls
end

local function texts(calls)
  local values = {}
  for index, entry in ipairs(calls.texts) do values[index] = entry.text end
  return table.concat(values, "|")
end

local tests = {}

function tests.heading_sits_above_the_kinds_and_actions_get_their_own_row()
  local strip, calls = fake()
  strip.draw({ id = "s", heading = "Selected", parts = KINDS, actions = ACTIONS })
  equal(texts(calls), "Selected|Tracks |4| · |Markers |0| · |Regions |2", "pieces")
  equal(calls.texts[1].role, "metadata", "heading role")
  equal(calls.texts[1].color, "component.card.selection.heading", "heading color")
  local kinds_y = 6 + 16 + 4
  equal(calls.texts[2].y, kinds_y + 20 - 16, "label shares the value's bottom edge")
  equal(calls.texts[3].y, kinds_y, "value on the kinds line")
  equal(calls.texts[3].role, "heading", "value role")
  equal(calls.texts[3].x, 10 + 7 * 7, "value follows the label")
  equal(calls.bar.id, "s", "action bar id")
  equal(calls.bar.actions, ACTIONS, "action bar actions")
  equal(calls.bar_x, 10, "actions start at the left edge")
  equal(calls.bar_y, kinds_y + 20 + 8, "actions a control gap below the kinds")
  equal(calls.pushed, calls.popped, "color stack")
end

function tests.zero_counts_are_muted()
  local strip, calls = fake()
  strip.draw({ id = "s", heading = "Selected", parts = KINDS, actions = ACTIONS })
  equal(calls.texts[3].color, "component.card.selection.value", "nonzero value")
  equal(calls.texts[2].color, "component.card.selection.label", "nonzero label")
  equal(calls.texts[6].color, "component.card.selection.muted", "zero value")
  equal(calls.texts[5].color, "component.card.selection.muted", "zero label")
end

function tests.kinds_wrap_between_parts()
  local strip, calls = fake({ available = 120 })
  strip.draw({ id = "s", heading = "Selected", parts = KINDS, actions = ACTIONS })
  equal(calls.texts[5].text, "Markers ", "second kind label")
  equal(calls.texts[5].x, 10, "second kind starts a new line")
  local second_line = 6 + 16 + 4 + 20 + 4
  equal(calls.texts[6].y, second_line, "one heading line plus item spacing lower")
  equal(calls.bar_y, second_line + 20 + 4 + 20 + 8, "actions below the last line")
end

function tests.activation_returns_the_action()
  local strip = fake({ bar_action = "unregister" })
  local result = strip.draw({ id = "s", heading = "Selected", parts = KINDS, actions = ACTIONS })
  equal(result.action, "unregister", "action")
  equal(result.events[1].type, "selection_strip.activated", "event type")
  equal(result.events[1].id, "s", "event id")
  equal(#fake().draw({ id = "s", heading = "Selected", parts = KINDS, actions = ACTIONS }).events, 0, "no events")
end

function tests.rejects_invalid_inputs()
  local strip = fake()
  local function draw(options) return pcall(strip.draw, options) end
  assert(not draw({ id = "", heading = "Selected", parts = KINDS, actions = ACTIONS }), "id rejected")
  assert(not draw({ id = "s", parts = KINDS, actions = ACTIONS }), "heading required")
  assert(not draw({ id = "s", heading = "Selected", parts = {}, actions = ACTIONS }), "parts required")
  assert(not draw({ id = "s", heading = "Selected", parts = { { label = "Tracks" } }, actions = ACTIONS }),
    "value required")
  assert(not draw({ id = "s", heading = "Selected", parts = KINDS, actions = {} }), "empty actions rejected")
  assert(not draw({ id = "s", heading = "Selected", parts = KINDS,
    actions = { { id = "p", label = "P", variant = "primary" } } }), "primary rejected")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
