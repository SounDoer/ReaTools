local number_field_module = require("reaui.design_number_field")

local function equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

local function dependencies()
  local calls = { buttons = {}, same_line = 0 }
  local ImGui = {}
  function ImGui.GetContentRegionAvail() return calls.available or 500 end
  function ImGui.SameLine() calls.same_line = calls.same_line + 1 end
  function ImGui.CalcTextSize() return 30 end
  local adapter = {}
  function adapter.resolve(id)
    local values = {
      ["semantic.size.control.medium"] = 32,
      ["semantic.space.control.gap"] = 8,
      ["semantic.space.control.padding_x"] = 12,
      ["component.number_field.layout.inline_min_width"] = 220,
      ["component.number_field.layout.minimum_input_width"] = 96,
    }
    return assert(values[id], id)
  end
  local shell = {}
  function shell.draw(options, renderer)
    calls.shell_options = options
    return renderer("##field-" .. options.id)
  end
  local input = {}
  function input.draw(options)
    calls.input_options = options
    return calls.input_result or {
      value = options.value, changed = false, committed = false,
    }
  end
  local button = {}
  function button.draw_icon(options)
    table.insert(calls.buttons, options)
    if options.id == calls.clicked and not options.disabled then
      return { type = "button.activated", id = options.id }
    end
    return nil
  end
  function button.draw(options)
    table.insert(calls.buttons, options)
    if options.id == calls.clicked then return { type = "button.activated", id = options.id } end
    return nil
  end
  return ImGui, adapter, shell, input, button, calls
end

local tests = {}

function tests.parses_valid_incomplete_invalid_and_range_states()
  local ImGui, adapter, shell, input, button = dependencies()
  local field = number_field_module.create(ImGui, "ctx", adapter, shell, input, button)
  local value, state = field.parse("+0012", 1, 20)
  equal(value, 12, "parsed value")
  equal(state, "valid", "valid state")
  equal(select(2, field.parse("-", nil, nil)), "incomplete", "incomplete state")
  equal(select(2, field.parse("1.5", nil, nil)), "invalid", "invalid state")
  equal(select(2, field.parse("21", 1, 20)), "out_of_range", "range state")
end

function tests.preserves_invalid_buffer_and_reports_commit()
  local ImGui, adapter, shell, input, button, calls = dependencies()
  calls.input_result = { value = "1.5", changed = true, committed = true }
  local field = number_field_module.create(ImGui, "ctx", adapter, shell, input, button)
  local result = field.draw({ id = "revision", label = "Target revision", buffer = "1" })
  equal(result.buffer, "1.5", "buffer")
  equal(result.value, nil, "parsed value")
  equal(result.parse_state, "invalid", "parse state")
  equal(result.events[1].type, "field.changed", "change event")
  equal(result.events[2].type, "field.committed", "commit event")
  equal(result.events[2].buffer, "1.5", "event buffer")
  equal(result.events[2].source, "input", "event source")
end

function tests.parse_message_is_opt_in_and_recovery_oriented()
  local ImGui, adapter, shell, input, button, calls = dependencies()
  local field = number_field_module.create(ImGui, "ctx", adapter, shell, input, button)
  field.draw({
    id = "revision", label = "Target revision", buffer = "99",
    minimum = 1, maximum = 12, show_parse_message = true,
  })
  equal(calls.shell_options.validation.state, "invalid", "validation state")
  equal(calls.shell_options.validation.message,
    "Enter a whole number from 1 to 12.", "range message")
end

function tests.step_clamps_and_emits_change_then_commit()
  local ImGui, adapter, shell, input, button, calls = dependencies()
  calls.clicked = "revision-increment"
  local field = number_field_module.create(ImGui, "ctx", adapter, shell, input, button)
  local result = field.draw({
    id = "revision", label = "Target revision", buffer = "9",
    minimum = 1, maximum = 10, step = 2,
  })
  equal(result.buffer, "10", "clamped buffer")
  equal(result.value, 10, "clamped value")
  equal(result.events[1].type, "field.changed", "step change")
  equal(result.events[2].type, "field.committed", "step commit")
  equal(result.events[2].source, "step", "step source")
end

function tests.invalid_and_boundary_states_disable_step_actions()
  local ImGui, adapter, shell, input, button, calls = dependencies()
  local field = number_field_module.create(ImGui, "ctx", adapter, shell, input, button)
  field.draw({ id = "invalid", label = "Invalid", buffer = "x", step = 1 })
  equal(calls.buttons[1].disabled, true, "invalid decrement")
  equal(calls.buttons[2].disabled, true, "invalid increment")
  calls.buttons = {}
  field.draw({ id = "minimum", label = "Minimum", buffer = "1", minimum = 1, step = 1 })
  equal(calls.buttons[1].disabled, true, "minimum decrement")
  equal(calls.buttons[2].disabled, false, "minimum increment")
end

function tests.narrow_layout_stacks_step_actions()
  local ImGui, adapter, shell, input, button, calls = dependencies()
  calls.available = 180
  local field = number_field_module.create(ImGui, "ctx", adapter, shell, input, button)
  field.draw({ id = "revision", label = "Target revision", buffer = "2", step = 1 })
  equal(calls.input_options.width, -1, "full-width input")
  equal(calls.same_line, 1, "only step actions share a line")
end

function tests.action_sits_inline_and_reports_activation()
  local ImGui, adapter, shell, input, button, calls = dependencies()
  calls.clicked = "revision-load"
  local field = number_field_module.create(ImGui, "ctx", adapter, shell, input, button)
  local result = field.draw({
    id = "revision", label = "Target revision", buffer = "2",
    action = { id = "load", label = "Load" },
  })
  equal(calls.input_options.width, 438, "input leaves room for the action")
  equal(calls.same_line, 1, "action shares the input line")
  equal(calls.buttons[1].label, "Load", "action label")
  equal(calls.buttons[1].stretch, false, "inline action keeps its width")
  equal(result.action, "load", "activated action")
end

function tests.narrow_layout_stacks_action()
  local ImGui, adapter, shell, input, button, calls = dependencies()
  calls.available = 180
  local field = number_field_module.create(ImGui, "ctx", adapter, shell, input, button)
  local result = field.draw({
    id = "revision", label = "Target revision", buffer = "2",
    action = { id = "load", label = "Load" },
  })
  equal(calls.input_options.width, -1, "full-width input")
  equal(calls.same_line, 0, "action moves below the input")
  equal(calls.buttons[1].stretch, true, "stacked action stretches")
  equal(result.action, nil, "no activation")
end

function tests.rejects_invalid_option_combinations()
  local ImGui, adapter, shell, input, button = dependencies()
  local field = number_field_module.create(ImGui, "ctx", adapter, shell, input, button)
  assert(not pcall(function()
    field.draw({ id = "x", label = "X", buffer = "1", value = 1 })
  end), "buffer and value rejected")
  assert(not pcall(function()
    field.draw({ id = "x", label = "X", value = 1.5 })
  end), "fraction rejected")
  assert(not pcall(function()
    field.draw({ id = "x", label = "X", minimum = 2, maximum = 1 })
  end), "inverted range rejected")
  assert(not pcall(function()
    field.draw({ id = "x", label = "X", step = 0 })
  end), "zero step rejected")
  assert(not pcall(function()
    field.draw({ id = "x", label = "X", step = 1, action = { id = "load", label = "Load" } })
  end), "step with action rejected")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
