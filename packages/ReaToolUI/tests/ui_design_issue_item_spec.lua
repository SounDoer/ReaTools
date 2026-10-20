local module = require("reaui.design_issue_item")

local function equal(actual, expected, label)
  if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local function fake(options)
  options = options or {}
  local calls = { colors = {}, popped_colors = 0, vars = {}, popped_vars = 0, children = {}, ended = 0,
    statuses = {}, bars = {} }
  local ImGui = {
    Col_ChildBg = 1, Col_Border = 2, StyleVar_ChildBorderSize = 3, StyleVar_ChildRounding = 4,
    StyleVar_WindowPadding = 5, StyleVar_ItemSpacing = 6, WindowFlags_NoScrollbar = 8,
  }
  function ImGui.PushStyleColor(_, slot, color) calls.colors[slot] = color end
  function ImGui.PopStyleColor(_, n) calls.popped_colors = calls.popped_colors + (n or 1) end
  function ImGui.PushStyleVar(_, var, x, y) calls.vars[var] = { x, y } end
  function ImGui.PopStyleVar(_, n) calls.popped_vars = calls.popped_vars + (n or 1) end
  function ImGui.GetStyleVar() return 8, 4 end
  function ImGui.GetCursorPosY() return 40 end
  function ImGui.SetCursorPosY(_, y) calls.set_y = y end
  function ImGui.BeginChild(_, id, w, h, child_flags)
    table.insert(calls.children, { id = id, w = w, h = h, flags = child_flags })
    return options.visible ~= false
  end
  function ImGui.EndChild() calls.ended = calls.ended + 1 end
  local adapter = { resolve = function(id) return id == "semantic.space.control.gap" and 8 or id end }
  local deps = {
    status = { draw = function(o) table.insert(calls.statuses, o) end },
    action_bar = { draw = function(o)
      table.insert(calls.bars, o)
      if options.choose then
        return { events = { { type = "action_bar.activated", id = o.id, action = options.choose } },
          action = options.choose }
      end
      return { events = {} }
    end },
  }
  return module.create(ImGui, "ctx", adapter, deps), calls, ImGui
end

local tests = {}

function tests.issue_item_uses_tint_tokens_per_role()
  for _, role in ipairs({ "warning", "blocked" }) do
    local item, calls, ImGui = fake()
    item.draw({ id = "missing", role = role, message = "Reference missing", detail = "Track 4" })
    equal(calls.colors[ImGui.Col_ChildBg], "component.issue_item." .. role .. ".background", role .. " background")
    equal(calls.colors[ImGui.Col_Border], "component.issue_item." .. role .. ".border", role .. " border")
    equal(calls.vars[ImGui.StyleVar_ChildBorderSize][1], "semantic.border.control.width", "border width")
    equal(calls.vars[ImGui.StyleVar_ChildRounding][1], "semantic.radius.control", "rounding")
    equal(calls.vars[ImGui.StyleVar_WindowPadding][1], "semantic.space.inset.padding_x", "padding x")
    equal(calls.vars[ImGui.StyleVar_WindowPadding][2], "semantic.space.inset.padding_y", "padding y")
    equal(calls.children[1].h, 0, "auto height")
    equal(calls.children[1].flags & (1 << 5), 1 << 5, "auto resize y")
    equal(calls.children[1].flags & 1, 1, "border")
    equal(calls.popped_colors, 2, "colors popped")
    equal(calls.popped_vars, 3, "vars popped")
    equal(calls.ended, 1, "child closed")
    local status = calls.statuses[1]
    equal(status.role, role, "status role")
    equal(status.text, "Reference missing", "status text")
    equal(status.detail, "Track 4", "status detail")
    equal(status.presentation, "inline", "inline status")
    equal(#calls.bars, 0, "no action bar without actions")
  end
end

function tests.issue_item_rejects_ready_role()
  for _, role in ipairs({ "ready", "neutral", "bogus" }) do
    local item = fake()
    assert(not pcall(function() item.draw({ id = "x", role = role, message = "Message" }) end), role .. " rejected")
  end
  local item = fake()
  assert(not pcall(function() item.draw({ id = "x", role = "warning" }) end), "message required")
end

function tests.issue_item_action_event()
  local item, calls = fake({ choose = "relink" })
  local result = item.draw({ id = "missing", role = "blocked", message = "Reference missing",
    actions = { { id = "relink", label = "Relink..." } } })
  equal(calls.set_y, 40 - 4 + 8, "control gap between message and actions")
  equal(calls.bars[1].id, "missing", "bar id")
  equal(calls.bars[1].actions[1].id, "relink", "bar actions")
  equal(result.action, "relink", "action")
  equal(result.events[1].type, "issue_item.action_selected", "event type")
  equal(result.events[1].id, "missing", "event id")
  equal(result.events[1].action, "relink", "event action")
end

function tests.issue_item_hidden_child_is_not_ended()
  local item, calls = fake({ visible = false })
  local result = item.draw({ id = "x", role = "warning", message = "Message" })
  equal(calls.ended, 0, "EndChild only when visible")
  equal(#calls.statuses, 0, "nothing drawn")
  equal(#result.events, 0, "no events")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
