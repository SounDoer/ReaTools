local module = require("reaui.design_layout")

local function equal(actual, expected, label)
  if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local TOKENS = {
  ["semantic.space.control.padding_x"] = 12,
  ["semantic.space.control.gap"] = 8,
  ["semantic.size.control.medium"] = 28,
}

local function fake(available_widths)
  local calls = { same = 0, new_line = 0, text_roles = {} }
  local index = 0
  local ImGui = {
    SameLine = function() calls.same = calls.same + 1 end,
    NewLine = function() calls.new_line = calls.new_line + 1 end,
    GetContentRegionAvail = function()
      index = index + 1
      return available_widths[index] or available_widths[#available_widths], 100
    end,
    GetCursorPosX = function() return 40 end,
    SetCursorPosX = function(_, x) calls.x = x end,
    CalcTextSize = function() return 50, 14 end,
    StyleVar_ItemSpacing = 14,
    GetStyleVar = function() return 8, 4 end,
    GetCursorPosY = function() return calls.y or 120 end,
    SetCursorPosY = function(_, y) calls.y = y end,
    Dummy = function(_, w, h)
      calls.dummy = { w, h, calls.y }
      calls.y = calls.y + h + 4
    end,
  }
  local adapter = {
    resolve = function(id) return TOKENS[id] end,
    with_text = function(role, renderer) table.insert(calls.text_roles, role) return renderer() end,
  }
  return module.create(ImGui, "ctx", adapter), calls
end

local tests = {}

function tests.trailing_right_aligns_when_it_fits()
  local layout, calls = fake({ 300 })
  local wrapped = layout.trailing(100)
  equal(wrapped, false, "wrapped")
  equal(calls.same, 1, "same line")
  equal(calls.new_line, 0, "no new line")
  equal(calls.x, 40 + 200, "right aligned")
end

function tests.trailing_wraps_when_it_does_not_fit()
  local layout, calls = fake({ 80, 320 })
  local wrapped = layout.trailing(100)
  equal(wrapped, true, "wrapped")
  equal(calls.new_line, 1, "new line")
  equal(calls.x, 40 + 220, "right aligned on the new line")
end

function tests.trailing_never_moves_left_when_wider_than_the_row()
  local layout, calls = fake({ 80, 60 })
  layout.trailing(100)
  equal(calls.x, 40, "left edge")
end

function tests.button_width_uses_body_font_and_padding()
  local layout, calls = fake({ 300 })
  equal(layout.button_width("Check Now"), 74, "width")
  equal(calls.text_roles[1], "body", "font role")
end

function tests.icon_button_width_and_gap_come_from_tokens()
  local layout = fake({ 300 })
  equal(layout.icon_button_width(), 28, "icon button")
  equal(layout.gap(), 8, "gap")
end

function tests.settle_submits_an_empty_item_without_moving_the_cursor()
  local layout, calls = fake({ 300 })
  calls.y = 120
  layout.settle()
  equal(calls.dummy[1], 0, "dummy width")
  equal(calls.dummy[2], 0, "dummy height")
  equal(calls.dummy[3], 116, "dummy sits on the last item bottom")
  equal(calls.y, 120, "cursor unchanged")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
