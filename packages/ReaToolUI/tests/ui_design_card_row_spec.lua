local module = require("reaui.design_card_row")

local function equal(actual, expected, label)
  if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local function fake(available)
  local calls = { drawn = {}, same = {}, set_y = {} }
  local naturals, actions = {}, {}
  local ImGui = { StyleVar_ItemSpacing = 1 }
  function ImGui.GetContentRegionAvail() return available, 400 end
  function ImGui.SameLine(_, _, spacing) table.insert(calls.same, spacing) end
  function ImGui.GetStyleVar() return 8, 8 end
  function ImGui.GetCursorPosY() return 100 end
  function ImGui.SetCursorPosY(_, y) table.insert(calls.set_y, y) end
  local adapter = { resolve = function(id)
    return ({
      ["semantic.layout.card_row.stack_below"] = 560,
      ["semantic.space.block.gap"] = 16,
    })[id]
  end }
  local card = { draw = function(options, render_body)
    table.insert(calls.drawn, { options = options, render_body = render_body })
    local events = {}
    if actions[options.id] then
      events[1] = { type = "card.action_selected", id = options.id, action = actions[options.id] }
    end
    return { events = events, action = actions[options.id], natural_height = naturals[options.id] or 100 }
  end }
  local row = module.create(ImGui, "ctx", adapter, card)
  return row, calls, naturals, actions
end

local CARDS = {
  { options = { id = "reference", title = "Reference" } },
  { options = { id = "delivery", title = "Delivery" } },
}

local function frame(row, calls)
  calls.drawn = {}
  return row.draw({ id = "main", cards = CARDS })
end

local tests = {}

function tests.side_by_side_at_or_above_560()
  local row, calls = fake(560)
  local result = frame(row, calls)
  equal(result.stacked, false, "side by side")
  equal(calls.drawn[1].options.width, 272, "first width")
  equal(calls.drawn[2].options.width, 272, "second width")
  equal(calls.same[1], 16, "block gap between cards")
  equal(#calls.same, 1, "one SameLine")
end

function tests.stacked_below_560()
  local row, calls = fake(559)
  local result = frame(row, calls)
  equal(result.stacked, true, "stacked")
  equal(calls.drawn[1].options.width, nil, "full width")
  equal(calls.drawn[2].options.min_height, nil, "no equal height when stacked")
  equal(#calls.same, 0, "no SameLine")
  equal(calls.set_y[1], 100 - 8 + 16, "block gap between stacked cards")
end

function tests.equal_height_uses_previous_frame_max()
  local row, calls, naturals = fake(720)
  naturals.reference, naturals.delivery = 300, 200
  frame(row, calls)
  equal(calls.drawn[1].options.min_height, nil, "first frame has no row height")
  frame(row, calls)
  equal(calls.drawn[1].options.min_height, 300, "first card")
  equal(calls.drawn[2].options.min_height, 300, "second card")
end

function tests.height_shrinks_when_content_shrinks()
  local row, calls, naturals = fake(720)
  naturals.reference, naturals.delivery = 300, 200
  frame(row, calls)
  naturals.reference = 180
  frame(row, calls)
  equal(calls.drawn[2].options.min_height, 300, "previous frame max")
  frame(row, calls)
  equal(calls.drawn[2].options.min_height, 200, "max recomputed, not carried")
end

function tests.actions_are_keyed_by_card_id_and_options_are_not_mutated()
  local row, calls, _, actions = fake(720)
  actions.delivery = "publish"
  local result = frame(row, calls)
  equal(result.actions.delivery, "publish", "keyed action")
  equal(result.actions.reference, nil, "no action")
  equal(result.events[1].action, "publish", "forwarded event")
  equal(CARDS[1].options.width, nil, "caller options untouched")
end

function tests.rejects_empty_row()
  local row = fake(720)
  assert(not pcall(function() row.draw({ id = "main", cards = {} }) end), "empty rejected")
  assert(not pcall(function() row.draw({ cards = CARDS }) end), "id required")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
