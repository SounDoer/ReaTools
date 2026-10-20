local dropdown_module = require("reaui.design_dropdown")

local function equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

local function dependencies()
  local calls = {
    previews = {}, selectables = {}, tooltips = {}, colors = 0, popped = 0,
    disabled_begin = 0, disabled_end = 0, pushed = {}, vars = 0, vars_popped = 0,
  }
  local ImGui = {
    Col_FrameBg = 1, Col_FrameBgHovered = 2, Col_FrameBgActive = 3,
    Col_Text = 4, Col_Border = 5, Col_Header = 6, Col_HeaderHovered = 7,
    Col_HeaderActive = 8, Col_Button = 9, Col_ButtonHovered = 10, Col_ButtonActive = 11,
    StyleVar_FramePadding = 1,
  }
  function ImGui.SetNextItemWidth(_, width) calls.width = width end
  function ImGui.PushStyleColor(_, index) calls.colors = calls.colors + 1; calls.pushed[index] = true end
  function ImGui.PopStyleColor(_, count) calls.popped = calls.popped + count end
  function ImGui.GetStyleVar() return 8, 4 end
  function ImGui.GetFontSize() return 14 end
  function ImGui.PushStyleVar(_, _, x, y) calls.vars = calls.vars + 1; calls.padding = { x, y } end
  function ImGui.PopStyleVar(_, count) calls.vars_popped = calls.vars_popped + (count or 1) end
  function ImGui.BeginDisabled() calls.disabled_begin = calls.disabled_begin + 1 end
  function ImGui.EndDisabled() calls.disabled_end = calls.disabled_end + 1 end
  function ImGui.BeginCombo(_, _, preview)
    table.insert(calls.previews, preview)
    return calls.open == true
  end
  function ImGui.EndCombo() calls.ended = true end
  function ImGui.Selectable(_, label, selected)
    table.insert(calls.selectables, { label = label, selected = selected })
    return calls.choose and label:find(calls.choose, 1, true) ~= nil
  end
  function ImGui.IsItemHovered() return calls.hovered == true end
  function ImGui.SetTooltip(_, value) table.insert(calls.tooltips, value) end
  function ImGui.SetItemDefaultFocus() calls.default_focus = true end
  local adapter = { resolve = function(id)
    if id == "semantic.size.control.medium" then return 32 end
    return 0x112233ff
  end }
  local shell = {}
  function shell.draw(options, renderer)
    calls.shell_options = options
    return renderer("##field-" .. options.id)
  end
  return ImGui, adapter, shell, calls
end

local OPTIONS = {
  { id = "replace", label = "Replace existing objects" },
  { id = "merge", label = "Merge with existing objects" },
}

local tests = {}

function tests.selected_option_and_change_event()
  local ImGui, adapter, shell, calls = dependencies()
  calls.open, calls.choose = true, "Merge"
  local dropdown = dropdown_module.create(ImGui, "ctx", adapter, shell)
  local result = dropdown.draw({ id = "policy", value = "replace", options = OPTIONS })
  equal(calls.previews[1], "Replace existing objects", "selected preview")
  equal(result.value, "merge", "changed value")
  equal(result.events[1].type, "selection.changed", "event type")
  equal(result.events[1].option.label, "Merge with existing objects", "event option")
  equal(calls.popped, calls.colors, "style stack")
end

function tests.arrow_button_and_height_match_inputs()
  local ImGui, adapter, shell, calls = dependencies()
  local dropdown = dropdown_module.create(ImGui, "ctx", adapter, shell)
  dropdown.draw({ id = "policy", value = "replace", options = OPTIONS })
  assert(calls.pushed[ImGui.Col_Button] and calls.pushed[ImGui.Col_ButtonHovered]
    and calls.pushed[ImGui.Col_ButtonActive], "arrow button colors are styled")
  equal(calls.padding[1], 8, "horizontal padding kept")
  equal(calls.padding[2], 9, "padding reaches the medium control height")
  equal(calls.popped, calls.colors, "color stack")
  equal(calls.vars_popped, calls.vars, "style var stack")
end

function tests.dynamic_states_are_visible_and_blocked()
  for _, fixture in ipairs({
    { state = "loading", preview = "Loading..." },
    { state = "empty", preview = "No options" },
    { state = "failed", preview = "Could not load options" },
  }) do
    local ImGui, adapter, shell, calls = dependencies()
    local dropdown = dropdown_module.create(ImGui, "ctx", adapter, shell)
    local options = fixture.state == "empty" and {} or OPTIONS
    local result = dropdown.draw({
      id = fixture.state, options = options, data_state = fixture.state,
    })
    equal(calls.previews[1], fixture.preview, fixture.state .. " preview")
    equal(calls.disabled_begin, 1, fixture.state .. " disabled")
    equal(result.changed, false, fixture.state .. " unchanged")
  end
end

function tests.stale_value_requires_visible_label_and_can_recover()
  local ImGui, adapter, shell, calls = dependencies()
  calls.open, calls.choose = true, "Replace"
  local dropdown = dropdown_module.create(ImGui, "ctx", adapter, shell)
  local result = dropdown.draw({
    id = "target", value = "missing", stale_label = "Old target (unavailable)",
    options = OPTIONS,
  })
  equal(calls.previews[1], "Old target (unavailable)", "stale preview")
  equal(result.value, "replace", "recovered value")
  equal(result.stale, false, "recovered stale state")
end

function tests.long_labels_are_exposed_as_tooltips()
  local ImGui, adapter, shell, calls = dependencies()
  calls.open, calls.hovered = true, true
  local dropdown = dropdown_module.create(ImGui, "ctx", adapter, shell)
  dropdown.draw({ id = "policy", value = "replace", options = OPTIONS })
  assert(#calls.tooltips >= #OPTIONS, "option and preview tooltips")
end

function tests.field_composition_uses_stable_control_id()
  local ImGui, adapter, shell, calls = dependencies()
  local dropdown = dropdown_module.create(ImGui, "ctx", adapter, shell)
  dropdown.draw_field({
    id = "lane", label = "Destination lane", options = OPTIONS,
  })
  equal(calls.shell_options.label, "Destination lane", "field label")
end

function tests.rejects_invalid_options_and_states()
  local ImGui, adapter, shell = dependencies()
  local dropdown = dropdown_module.create(ImGui, "ctx", adapter, shell)
  assert(not pcall(function()
    dropdown.draw({ id = "x", options = { { id = "a", label = "A" }, { id = "a", label = "B" } } })
  end), "duplicate IDs rejected")
  assert(not pcall(function()
    dropdown.draw({ id = "x", options = OPTIONS, data_state = "stale" })
  end), "unknown state rejected")
  assert(not pcall(function()
    dropdown.draw({ id = "x", options = OPTIONS, data_state = "empty" })
  end), "non-empty empty state rejected")
  assert(not pcall(function()
    dropdown.draw({ id = "x", value = "missing", options = OPTIONS })
  end), "invisible stale value rejected")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
