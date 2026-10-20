local module = require("reaui.design_section_heading")

local function equal(actual, expected, label)
  if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

-- Fake ImGui with a vertical cursor that starts at y = 16 inside a window at
-- screen y = 100. Each item advances by its height plus the item spacing 4.
local function fake(start_offset)
  local calls = { y = 16 + (start_offset or 0), set_y = {}, texts = {}, order = {} }
  local role = "body"
  local ImGui = { StyleVar_ItemSpacing = 1, Col_Text = 2 }
  function ImGui.GetStyleVar() return 8, 4 end
  function ImGui.GetCursorPosY() return calls.y end
  function ImGui.GetCursorScreenPos() return 0, 100 + calls.y end
  function ImGui.GetWindowPos() return 0, 100 end
  function ImGui.GetCursorStartPos() return 0, 16 end
  function ImGui.SetCursorPosY(_, y) calls.y = y; table.insert(calls.set_y, y); table.insert(calls.order, "set") end
  function ImGui.PushStyleColor(_, _, color) calls.color = color end
  function ImGui.PopStyleColor() end
  function ImGui.TextWrapped(_, text)
    table.insert(calls.texts, { text = text, role = role, color = calls.color, y = calls.y })
    table.insert(calls.order, "title")
    calls.y = calls.y + 20 + 4
  end
  function ImGui.Dummy(_, w, h) table.insert(calls.order, "dummy " .. w .. "x" .. h); calls.y = calls.y + h + 4 end
  local adapter = {
    resolve = function(id) return ({ ["semantic.space.section.loose"] = 24 })[id] or id end,
    with_text = function(next_role, renderer)
      local previous = role; role = next_role
      local result = renderer()
      role = previous
      return result
    end,
  }
  return module.create(ImGui, "ctx", adapter), calls
end

local tests = {}

function tests.first_heading_in_a_window_has_no_gap()
  local section, calls = fake()
  local result = section.draw({ id = "issues", title = "Issues" }, function() return "body" end)
  equal(result, "body", "returns the render result")
  equal(#calls.set_y, 1, "only the settle cursor move")
  equal(calls.texts[1].y, 16, "title at the window start")
  equal(calls.texts[1].text, "Issues", "title")
  equal(calls.texts[1].role, "heading", "heading font")
  equal(calls.texts[1].color, "semantic.color.text.primary", "primary color")
  equal(calls.order[#calls.order], "dummy 0x0", "ends with an item after the body")
end

function tests.heading_after_content_adds_section_loose()
  local section, calls = fake(40)
  section.draw({ id = "details", title = "Details" })
  equal(calls.set_y[1], 56 - 4 + 24, "section loose replaces item spacing")
  equal(calls.texts[1].y, 76, "title below the gap")
  equal(#calls.order, 2, "no settle without a body")
end

function tests.explicit_gap_overrides_the_window_position()
  local section, calls = fake(40)
  section.draw({ id = "a", title = "A", gap_above = false })
  equal(#calls.set_y, 0, "gap suppressed")
  local start_section, start_calls = fake()
  start_section.draw({ id = "b", title = "B", gap_above = true })
  equal(start_calls.set_y[1], 16 - 4 + 24, "gap forced at the window start")
end

function tests.invalid_options_are_rejected()
  local section = fake()
  assert(not pcall(section.draw, { title = "A" }), "id required")
  assert(not pcall(section.draw, { id = "a" }), "title required")
  assert(not pcall(section.draw, { id = "a", title = "A", gap_above = "yes" }), "gap_above boolean")
  assert(not pcall(section.draw, { id = "a", title = "A" }, "body"), "renderer function")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
