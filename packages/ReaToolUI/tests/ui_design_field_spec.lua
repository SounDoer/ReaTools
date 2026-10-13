local field_shell_module = require("reaui.design_field_shell")
local text_field_module = require("reaui.design_text_field")

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

local function fake_dependencies()
  local calls = {
    text = {}, wrapped = {}, colors = {}, tokens = {}, dummies = {},
    popped_colors = 0, disabled_begin = 0, disabled_end = 0,
  }
  local ImGui = {
    Col_Text = 1,
    Col_FrameBg = 2,
    Col_FrameBgHovered = 3,
    Col_FrameBgActive = 4,
    Col_Border = 5,
    InputTextFlags_ReadOnly = 8,
  }
  function ImGui.TextColored(_, _, value) table.insert(calls.text, value) end
  function ImGui.TextWrapped(_, value) table.insert(calls.wrapped, value) end
  function ImGui.PushStyleColor(_, key, value)
    table.insert(calls.colors, { key = key, value = value })
  end
  function ImGui.PopStyleColor(_, count)
    calls.popped_colors = calls.popped_colors + (count or 1)
  end
  function ImGui.Dummy(_, width, height) table.insert(calls.dummies, { width, height }) end
  function ImGui.GetTextLineHeight() return 13 end
  function ImGui.SetNextItemWidth(_, width) calls.item_width = width end
  function ImGui.BeginDisabled() calls.disabled_begin = calls.disabled_begin + 1 end
  function ImGui.EndDisabled() calls.disabled_end = calls.disabled_end + 1 end
  function ImGui.InputText(_, id, value, flags)
    calls.input = { kind = "text", id = id, value = value, flags = flags }
    return calls.changed == true, calls.next_value or value
  end
  function ImGui.InputTextWithHint(_, id, hint, value, flags)
    calls.input = { kind = "hint", id = id, hint = hint, value = value, flags = flags }
    return calls.changed == true, calls.next_value or value
  end
  function ImGui.IsItemDeactivatedAfterEdit() return calls.committed == true end

  local adapter = {}
  function adapter.resolve(id)
    table.insert(calls.tokens, id)
    return 0x112233ff
  end
  return ImGui, adapter, calls
end

local tests = {}

function tests.field_shell_renders_structure_and_reserves_message_space()
  local ImGui, adapter, calls = fake_dependencies()
  local shell = field_shell_module.create(ImGui, "ctx", adapter)
  local result = shell.draw({
    id = "pattern", label = "Naming pattern", requirement = "required",
    description = "Use tokens to build names.",
  }, function(control_id)
    equal(control_id, "##field-pattern", "control id")
    return "control-result"
  end)
  equal(result, "control-result", "control result")
  equal(calls.text[1], "Naming pattern (required)", "field label")
  equal(calls.wrapped[1], "Use tokens to build names.", "description")
  equal(#calls.dummies, 1, "reserved message line")
  equal(calls.dummies[1][2], 13, "message line height")
end

function tests.field_shell_validates_requirement_and_invalid_message()
  local ImGui, adapter = fake_dependencies()
  local shell = field_shell_module.create(ImGui, "ctx", adapter)
  assert(not pcall(function()
    shell.draw({ id = "x", label = "X", requirement = "sometimes" }, function() end)
  end), "unknown requirement rejected")
  assert(not pcall(function()
    shell.draw({ id = "x", label = "X", validation = { state = "invalid" } }, function() end)
  end), "invalid state requires a message")
  assert(not pcall(function()
    shell.draw({ id = "x", label = "X", validation = { state = "warning" } }, function() end)
  end), "unknown validation state rejected")
end

function tests.text_field_emits_changed_then_committed_events()
  local ImGui, adapter, calls = fake_dependencies()
  calls.changed, calls.committed, calls.next_value = true, true, "Ambience_$track"
  local field = text_field_module.create(ImGui, "ctx", adapter)
  local result = field.draw({ id = "pattern", label = "Naming pattern", value = "Ambience" })
  equal(result.value, "Ambience_$track", "updated value")
  equal(result.changed, true, "changed")
  equal(result.committed, true, "committed")
  equal(result.events[1].type, "field.changed", "first event")
  equal(result.events[2].type, "field.committed", "second event")
  equal(result.events[2].id, "pattern", "event id")
  equal(calls.input.id, "##field-pattern", "native id")
  equal(calls.item_width, -1, "full available width")
end

function tests.text_field_routes_placeholder_to_native_hint()
  local ImGui, adapter, calls = fake_dependencies()
  local field = text_field_module.create(ImGui, "ctx", adapter)
  field.draw({
    id = "fallback", label = "Fallback name", value = "", placeholder = "Unnamed_01",
  })
  equal(calls.input.kind, "hint", "hint input")
  equal(calls.input.hint, "Unnamed_01", "placeholder")
end

function tests.disabled_and_read_only_fields_suppress_events()
  local ImGui, adapter, calls = fake_dependencies()
  calls.changed, calls.committed, calls.next_value = true, true, "changed"
  local field = text_field_module.create(ImGui, "ctx", adapter)
  local disabled = field.draw({ id = "disabled", label = "Disabled", value = "old", disabled = true })
  equal(#disabled.events, 0, "disabled events")
  equal(calls.disabled_begin, 1, "disabled scope opened")
  equal(calls.disabled_end, 1, "disabled scope closed")
  local read_only = field.draw({ id = "readonly", label = "Read only", value = "old", read_only = true })
  equal(#read_only.events, 0, "read-only events")
  equal(calls.input.flags, ImGui.InputTextFlags_ReadOnly, "read-only flag")
  assert(not pcall(function()
    field.draw({ id = "both", label = "Both", disabled = true, read_only = true })
  end), "disabled and read-only rejected")
end

function tests.invalid_field_uses_invalid_border_and_message_tokens()
  local ImGui, adapter, calls = fake_dependencies()
  local field = text_field_module.create(ImGui, "ctx", adapter)
  field.draw({
    id = "invalid", label = "Naming pattern", value = "$unknown",
    validation = { state = "invalid", message = "Use a supported token." },
  })
  assert(contains(calls.tokens, "component.input_control.border.invalid"),
    "invalid border token")
  assert(contains(calls.tokens, "component.field_shell.message.invalid.foreground.default"),
    "invalid message token")
  equal(calls.wrapped[#calls.wrapped], "Use a supported token.", "invalid message")
  equal(calls.popped_colors, #calls.colors, "style colors restored")
end

function tests.text_field_validates_value_type()
  local ImGui, adapter = fake_dependencies()
  local field = text_field_module.create(ImGui, "ctx", adapter)
  assert(not pcall(function()
    field.draw({ id = "bad", label = "Bad", value = 12 })
  end), "non-string value rejected")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
