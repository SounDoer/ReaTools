local field_shell_module = require("reaui.design_field_shell")
local input_control_module = require("reaui.design_input_control")

local M = {}

function M.create(ImGui, ctx, adapter, field_shell, input_control)
  field_shell = field_shell or field_shell_module.create(ImGui, ctx, adapter)
  input_control = input_control or input_control_module.create(ImGui, ctx, adapter)
  local component = {}

  local function add_event(events, event_type, id, value)
    table.insert(events, { type = event_type, id = id, value = value })
  end

  function component.draw(options)
    options = options or {}
    if options.value ~= nil and type(options.value) ~= "string" then
      error("text field value must be a string")
    end
    if options.disabled and options.read_only then
      error("text field cannot be both disabled and read_only")
    end

    return field_shell.draw(options, function(control_id)
      local input = input_control.draw({
        id = control_id,
        value = options.value or "",
        placeholder = options.placeholder,
        disabled = options.disabled,
        read_only = options.read_only,
        invalid = options.validation and options.validation.state == "invalid",
      })
      local events = {}
      if input.changed then add_event(events, "field.changed", options.id, input.value) end
      if input.committed then add_event(events, "field.committed", options.id, input.value) end
      return {
        value = input.value,
        changed = input.changed,
        committed = input.committed,
        events = events,
      }
    end)
  end

  return component
end

return M
