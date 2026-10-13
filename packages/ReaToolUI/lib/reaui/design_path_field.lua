local field_shell_module = require("reaui.design_field_shell")
local input_control_module = require("reaui.design_input_control")
local button_module = require("reaui.design_button")

local M = {}

local KINDS = { file = true, folder = true }

function M.create(ImGui, ctx, adapter, field_shell, input_control, button)
  field_shell = field_shell or field_shell_module.create(ImGui, ctx, adapter)
  input_control = input_control or input_control_module.create(ImGui, ctx, adapter)
  button = button or button_module.create(ImGui, ctx, adapter)
  local component = {}

  local function resolve(id) return adapter.resolve(id) end

  local function add_field_event(events, event_type, options, value)
    table.insert(events, {
      type = event_type,
      id = options.id,
      value = value,
      kind = options.kind,
    })
  end

  function component.draw(options)
    options = options or {}
    if not KINDS[options.kind] then
      error("path field kind must be file or folder")
    end
    if options.value ~= nil and type(options.value) ~= "string" then
      error("path field value must be a string")
    end
    if options.browse_label ~= nil and
        (type(options.browse_label) ~= "string" or options.browse_label == "") then
      error("path field browse_label must be a non-empty string")
    end
    if options.disabled and options.read_only then
      error("path field cannot be both disabled and read_only")
    end

    return field_shell.draw(options, function(control_id)
      local value = options.value or ""
      local browse_label = options.browse_label or "Browse..."
      local available = ImGui.GetContentRegionAvail(ctx)
      local gap = resolve("semantic.space.control.gap")
      local button_width = ImGui.CalcTextSize(ctx, browse_label) +
        resolve("semantic.space.control.padding_x") * 2
      local minimum_input = resolve("semantic.size.field.minimum_input")
      local inline = available >= resolve("component.path_field.layout.inline_min_width") and
        available - button_width - gap >= minimum_input
      local input = input_control.draw({
        id = control_id,
        value = value,
        placeholder = options.placeholder,
        disabled = options.disabled,
        read_only = options.read_only,
        invalid = options.validation and options.validation.state == "invalid",
        width = inline and (available - button_width - gap) or -1,
      })

      local events = {}
      if input.changed then add_field_event(events, "field.changed", options, input.value) end
      if input.committed then add_field_event(events, "field.committed", options, input.value) end
      if inline then ImGui.SameLine(ctx, 0, gap) end
      local browse = button.draw({
        id = options.id .. "-browse",
        label = browse_label,
        variant = "secondary",
        disabled = options.disabled == true or options.browse_disabled == true,
        stretch = not inline,
      })
      if browse then
        table.insert(events, {
          type = "path.browse_requested",
          id = options.id,
          value = input.value,
          kind = options.kind,
        })
      end

      return {
        value = input.value,
        changed = input.changed,
        committed = input.committed,
        browse_requested = browse ~= nil,
        events = events,
        layout = inline and "inline" or "stacked",
      }
    end)
  end

  return component
end

return M
