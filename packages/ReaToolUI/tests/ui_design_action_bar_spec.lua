local module = require("reaui.design_action_bar")

local function equal(actual, expected, label)
  if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local function fake(options)
  options = options or {}
  local calls = { rows = {}, drawn = {}, text = {}, wrapped = {}, pushed = 0, popped = 0 }
  local ImGui = { Col_Text = 1 }
  function ImGui.GetContentRegionAvail() return options.available or 400, 100 end
  function ImGui.GetCursorPosX() return 0 end
  function ImGui.SetCursorPosX(_, x) table.insert(calls.rows, { x = x, actions = {} }) end
  function ImGui.SameLine(_, _, spacing) calls.spacing = spacing end
  function ImGui.CalcTextSize(_, text) return options.context_width or #text * 7, 13 end
  function ImGui.AlignTextToFramePadding() calls.aligned = true end
  function ImGui.Text(_, value) table.insert(calls.text, value) end
  function ImGui.TextWrapped(_, value) table.insert(calls.wrapped, value) end
  function ImGui.PushStyleColor() calls.pushed = calls.pushed + 1 end
  function ImGui.PopStyleColor() calls.popped = calls.popped + 1 end
  local adapter = {
    resolve = function(id) return id end,
    with_text = function(role, renderer) calls.text_role = role return renderer() end,
  }
  local button = {
    draw = function(button_options)
      table.insert(calls.drawn, button_options)
      local row = calls.rows[#calls.rows]
      if row then table.insert(row.actions, button_options.label) end
      if options.clicked == button_options.label and not button_options.disabled then
        return { type = "button.activated", id = button_options.id }
      end
    end,
  }
  local layout = {
    button_width = function(label) return (options.widths or {})[label] or 100 end,
    gap = function() return 8 end,
    trailing = function(width)
      calls.trailing = width
      table.insert(calls.rows, { x = "trailing", actions = {} })
      return false
    end,
  }
  return module.create(ImGui, "ctx", adapter, button, layout), calls
end

local ACTIONS = {
  { id = "one", label = "One" },
  { id = "two", label = "Two" },
  { id = "three", label = "Three", variant = "primary" },
}

local tests = {}

function tests.context_and_actions_share_a_line_when_they_fit()
  local bar, calls = fake({ available = 500, context_width = 120 })
  bar.draw({ id = "footer", context = "2 changes", actions = ACTIONS })
  equal(calls.text[1], "2 changes", "context text")
  equal(calls.text_role, "label", "context font")
  equal(calls.aligned, true, "aligned to frame padding")
  equal(calls.trailing, 316, "trailing width")
  equal(#calls.rows, 1, "one row")
  equal(#calls.rows[1].actions, 3, "all actions on the line")
  equal(calls.spacing, 8, "gap between actions")
  equal(calls.pushed, calls.popped, "style stack")
end

function tests.context_moves_above_when_actions_do_not_fit()
  local bar, calls = fake({ available = 400, context_width = 120 })
  bar.draw({ id = "footer", context = "2 changes", actions = ACTIONS })
  equal(calls.wrapped[1], "2 changes", "context wraps on its own line")
  equal(calls.trailing, nil, "no shared line")
  equal(calls.rows[1].x, 400 - 316, "actions right aligned below")
end

function tests.actions_wrap_greedily_with_each_row_right_aligned()
  local bar, calls = fake({ available = 230 })
  bar.draw({ id = "footer", actions = ACTIONS })
  equal(#calls.rows, 2, "two rows")
  equal(table.concat(calls.rows[1].actions, ","), "One,Two", "first row")
  equal(calls.rows[1].x, 230 - 208, "first row right aligned")
  equal(table.concat(calls.rows[2].actions, ","), "Three", "second row")
  equal(calls.rows[2].x, 130, "second row right aligned")
end

function tests.oversized_action_gets_its_own_row()
  local bar, calls = fake({ available = 300, widths = { Two = 400 } })
  bar.draw({ id = "footer", actions = ACTIONS })
  equal(#calls.drawn, 3, "each action drawn once")
  equal(#calls.rows, 3, "three rows")
  equal(table.concat(calls.rows[2].actions, ","), "Two", "oversized alone")
  equal(calls.rows[2].x, 0, "oversized starts at the left edge")
end

function tests.disabled_action_never_emits()
  local bar = fake({ clicked = "Three" })
  local result = bar.draw({ id = "footer", actions = {
    { id = "one", label = "One" },
    { id = "three", label = "Three", variant = "primary", disabled = true },
  } })
  equal(#result.events, 0, "no events")
  equal(result.action, nil, "no action")
end

function tests.emits_activated_event_with_action_id()
  local bar, calls = fake({ clicked = "Two" })
  local result = bar.draw({ id = "footer", actions = ACTIONS })
  equal(result.action, "two", "action")
  equal(result.events[1].type, "action_bar.activated", "event type")
  equal(result.events[1].id, "footer", "bar id")
  equal(result.events[1].action, "two", "event action")
  equal(calls.drawn[2].id, "footer-two", "scoped button id")
  equal(calls.drawn[3].variant, "primary", "variant forwarded")
end

function tests.rejects_primary_not_last_two_primaries_and_empty_bar()
  local bar = fake()
  assert(not pcall(function() bar.draw({ id = "f", actions = {
    { id = "a", label = "A", variant = "primary" }, { id = "b", label = "B" },
  } }) end), "primary not last")
  assert(not pcall(function() bar.draw({ id = "f", actions = {
    { id = "a", label = "A", variant = "primary" }, { id = "b", label = "B", variant = "primary" },
  } }) end), "two primaries")
  assert(not pcall(function() bar.draw({ id = "f", actions = {} }) end), "empty bar")
  assert(pcall(function() bar.draw({ id = "f", context = "Nothing to do", actions = {} }) end),
    "context only")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
