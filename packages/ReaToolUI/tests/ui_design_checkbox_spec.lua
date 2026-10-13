local checkbox_module = require("reaui.design_checkbox")

local function equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

local function contains(values, expected)
  for _, value in ipairs(values) do
    if value == expected then return true end
  end
  return false
end

local function dependencies()
  local calls = {
    tokens = {}, labels = {}, wrapped = {}, colors = {}, popped = 0,
    disabled_begin = 0, disabled_end = 0, dummies = {},
  }
  local ImGui = {
    Col_FrameBg = 1, Col_FrameBgHovered = 2, Col_FrameBgActive = 3,
    Col_Text = 4, Col_CheckMark = 5, Col_Border = 6,
  }
  function ImGui.PushStyleColor(_, key, value)
    table.insert(calls.colors, { key = key, value = value })
  end
  function ImGui.PopStyleColor(_, count) calls.popped = calls.popped + (count or 1) end
  function ImGui.BeginDisabled() calls.disabled_begin = calls.disabled_begin + 1 end
  function ImGui.EndDisabled() calls.disabled_end = calls.disabled_end + 1 end
  function ImGui.Checkbox(_, label, checked)
    table.insert(calls.labels, label)
    return calls.changed == true, calls.next_checked == nil and checked or calls.next_checked
  end
  function ImGui.TextWrapped(_, value) table.insert(calls.wrapped, value) end
  function ImGui.Dummy(_, width, height) table.insert(calls.dummies, { width, height }) end
  function ImGui.GetTextLineHeight() return 13 end
  local adapter = {}
  function adapter.resolve(id)
    table.insert(calls.tokens, id)
    return 0x112233ff
  end
  return ImGui, adapter, calls
end

local tests = {}

function tests.toggle_emits_semantic_event()
  local ImGui, adapter, calls = dependencies()
  calls.changed, calls.next_checked = true, true
  local checkbox = checkbox_module.create(ImGui, "ctx", adapter)
  local result = checkbox.draw({ id = "timeline", label = "Mirror the source timeline" })
  equal(result.checked, true, "checked")
  equal(result.changed, true, "changed")
  equal(result.events[1].type, "checkbox.changed", "event type")
  equal(result.events[1].id, "timeline", "event id")
  equal(result.events[1].checked, true, "event value")
  equal(calls.labels[1], "Mirror the source timeline##checkbox-timeline", "native label")
end

function tests.disabled_checkbox_suppresses_change()
  local ImGui, adapter, calls = dependencies()
  calls.changed, calls.next_checked = true, false
  local checkbox = checkbox_module.create(ImGui, "ctx", adapter)
  local result = checkbox.draw({
    id = "locked", label = "Locked option", checked = true, disabled = true,
  })
  equal(result.changed, false, "disabled changed")
  equal(#result.events, 0, "disabled events")
  equal(calls.disabled_begin, 1, "disabled opened")
  equal(calls.disabled_end, 1, "disabled closed")
end

function tests.description_and_invalid_message_wrap_with_tokens()
  local ImGui, adapter, calls = dependencies()
  local checkbox = checkbox_module.create(ImGui, "ctx", adapter)
  checkbox.draw({
    id = "invalid", label = "Mirror timeline",
    description = "Use the source project's timeline start.",
    validation = { state = "invalid", message = "Choose a source project first." },
  })
  equal(calls.wrapped[1], "Use the source project's timeline start.", "description")
  equal(calls.wrapped[2], "Choose a source project first.", "message")
  assert(contains(calls.tokens, "component.checkbox.border.invalid"), "invalid border")
  equal(calls.popped, #calls.colors, "style stack")
end

function tests.reserves_message_space_only_when_requested()
  local ImGui, adapter, calls = dependencies()
  local checkbox = checkbox_module.create(ImGui, "ctx", adapter)
  checkbox.draw({ id = "reserved", label = "Reserved", reserve_message = true })
  equal(#calls.dummies, 1, "reserved line")
  equal(calls.dummies[1][2], 13, "line height")
end

function tests.rejects_invalid_inputs()
  local ImGui, adapter = dependencies()
  local checkbox = checkbox_module.create(ImGui, "ctx", adapter)
  assert(not pcall(function() checkbox.draw({ id = "", label = "X" }) end), "id rejected")
  assert(not pcall(function() checkbox.draw({ id = "x", label = "" }) end), "label rejected")
  assert(not pcall(function()
    checkbox.draw({ id = "x", label = "X", checked = 1 })
  end), "checked type rejected")
  assert(not pcall(function()
    checkbox.draw({ id = "x", label = "X", validation = { state = "warning" } })
  end), "validation state rejected")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
