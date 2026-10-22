local field_shell_module = require("reaui.design_field_shell")
local input_control_module = require("reaui.design_input_control")
local button_module = require("reaui.design_button")

local M = {}

local function is_integer(value)
  return type(value) == "number" and value == value and
    value ~= math.huge and value ~= -math.huge and value % 1 == 0
end

local function parse(buffer, minimum, maximum)
  if buffer == "" or buffer == "+" or buffer == "-" then
    return nil, "incomplete"
  end
  if not buffer:match("^[+-]?%d+$") then return nil, "invalid" end
  local value = tonumber(buffer)
  if not is_integer(value) then return nil, "invalid" end
  if (minimum and value < minimum) or (maximum and value > maximum) then
    return value, "out_of_range"
  end
  return value, "valid"
end

local function range_message(minimum, maximum)
  if minimum and maximum then
    return string.format("Enter a whole number from %d to %d.", minimum, maximum)
  elseif minimum then
    return string.format("Enter a whole number of %d or greater.", minimum)
  end
  return string.format("Enter a whole number of %d or less.", maximum)
end

function M.create(ImGui, ctx, adapter, field_shell, input_control, button)
  field_shell = field_shell or field_shell_module.create(ImGui, ctx, adapter)
  input_control = input_control or input_control_module.create(ImGui, ctx, adapter)
  button = button or button_module.create(ImGui, ctx, adapter)
  local component = {}

  local function resolve(id) return adapter.resolve(id) end

  local function validate_options(options)
    if options.buffer ~= nil and type(options.buffer) ~= "string" then
      error("number field buffer must be a string")
    end
    if options.value ~= nil and not is_integer(options.value) then
      error("number field value must be an integer")
    end
    if options.buffer ~= nil and options.value ~= nil then
      error("number field accepts buffer or value, not both")
    end
    for name, value in pairs({ minimum = options.minimum, maximum = options.maximum }) do
      if value ~= nil and not is_integer(value) then
        error("number field " .. name .. " must be an integer")
      end
    end
    if options.minimum and options.maximum and options.minimum > options.maximum then
      error("number field minimum cannot exceed maximum")
    end
    if options.step ~= nil and (not is_integer(options.step) or options.step <= 0) then
      error("number field step must be a positive integer")
    end
    if options.disabled and options.read_only then
      error("number field cannot be both disabled and read_only")
    end
    if options.action ~= nil then
      if type(options.action) ~= "table" or type(options.action.id) ~= "string" or
          type(options.action.label) ~= "string" or options.action.label == "" then
        error("number field action needs an id and label")
      end
      if options.step ~= nil then error("number field accepts step or action, not both") end
    end
  end

  local function parse_validation(options, state)
    if options.validation or not options.show_parse_message or state == "valid" then
      return options.validation
    end
    local message
    if state == "incomplete" then
      message = options.incomplete_message or "Enter a whole number."
    elseif state == "out_of_range" then
      message = options.out_of_range_message or
        range_message(options.minimum, options.maximum)
    else
      message = options.invalid_message or
        "Use digits only, with an optional leading minus sign."
    end
    return { state = "invalid", message = message }
  end

  local function add_event(events, event_type, id, buffer, value, state, source)
    table.insert(events, {
      type = event_type,
      id = id,
      buffer = buffer,
      value = value,
      parse_state = state,
      source = source,
    })
  end

  function component.draw(options)
    options = options or {}
    validate_options(options)
    local buffer = options.buffer
    if buffer == nil then buffer = options.value == nil and "" or tostring(options.value) end
    local initial_value, initial_state = parse(buffer, options.minimum, options.maximum)
    local shell_options = {}
    for key, value in pairs(options) do shell_options[key] = value end
    shell_options.validation = parse_validation(options, initial_state)

    return field_shell.draw(shell_options, function(control_id)
      local available = ImGui.GetContentRegionAvail(ctx)
      local step = options.step
      local control_size = resolve("semantic.size.control.medium")
      local gap = resolve("semantic.space.control.gap")
      local inline = step and available >= resolve(
        "component.number_field.layout.inline_min_width")
      local width = -1
      if inline then
        width = math.max(resolve("component.number_field.layout.minimum_input_width"),
          available - control_size * 2 - gap * 2)
      end
      local action_width
      if options.action then
        local function label_width() return (ImGui.CalcTextSize(ctx, options.action.label)) end
        action_width = (adapter.with_text and adapter.with_text("body", label_width) or label_width()) +
          resolve("semantic.space.control.padding_x") * 2
        inline = available >= resolve("component.number_field.layout.inline_min_width") and
          available - action_width - gap >= resolve("component.number_field.layout.minimum_input_width")
        width = inline and (available - action_width - gap) or -1
      end
      local input = input_control.draw({
        id = control_id,
        value = buffer,
        placeholder = options.placeholder,
        disabled = options.disabled,
        read_only = options.read_only,
        invalid = shell_options.validation and shell_options.validation.state == "invalid",
        width = width,
      })

      local value, state = parse(input.value, options.minimum, options.maximum)
      local events = {}
      local stepped = false
      if input.changed then
        add_event(events, "field.changed", options.id, input.value, value, state, "input")
      end
      if input.committed then
        add_event(events, "field.committed", options.id, input.value, value, state, "input")
      end

      if step then
        if inline then ImGui.SameLine(ctx, 0, gap) end
        local blocked = options.disabled or options.read_only or state ~= "valid"
        local decrement_disabled = blocked or
          (options.minimum ~= nil and value <= options.minimum)
        local decrement = button.draw_icon({
          id = options.id .. "-decrement",
          icon = "minus",
          accessible_label = "Decrease by " .. tostring(step),
          variant = "secondary",
          disabled = decrement_disabled,
        })
        ImGui.SameLine(ctx, 0, gap)
        local increment_disabled = blocked or
          (options.maximum ~= nil and value >= options.maximum)
        local increment = button.draw_icon({
          id = options.id .. "-increment",
          icon = "plus",
          accessible_label = "Increase by " .. tostring(step),
          variant = "secondary",
          disabled = increment_disabled,
        })
        if decrement or increment then
          stepped = true
          local delta = decrement and -step or step
          local next_value = value + delta
          if options.minimum then next_value = math.max(options.minimum, next_value) end
          if options.maximum then next_value = math.min(options.maximum, next_value) end
          input.value, value, state = tostring(next_value), next_value, "valid"
          add_event(events, "field.changed", options.id, input.value, value, state, "step")
          add_event(events, "field.committed", options.id, input.value, value, state, "step")
        end
      end

      local action
      if options.action then
        if inline then ImGui.SameLine(ctx, 0, gap) end
        if button.draw({
          id = options.id .. "-" .. options.action.id,
          label = options.action.label,
          variant = "secondary",
          disabled = options.disabled == true,
          stretch = not inline,
        }) then
          action = options.action.id
        end
      end

      return {
        action = action,
        buffer = input.value,
        value = value,
        parse_state = state,
        changed = input.changed or stepped,
        committed = input.committed or stepped,
        events = events,
      }
    end)
  end

  component.parse = parse
  return component
end

return M
