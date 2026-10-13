local field_shell_module = require("reaui.design_field_shell")

local M = {}

local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter, field_shell)
  field_shell = field_shell or field_shell_module.create(ImGui, ctx, adapter)
  local component = {}

  local function resolve(id) return adapter.resolve(id) end

  local function validate(options)
    required_string(options.id, "segmented control id")
    required_string(options.value, "segmented control value")
    if type(options.options) ~= "table" or #options.options < 2 then
      error("segmented control requires at least two options")
    end
    local ids, selected = {}, false
    for index, option in ipairs(options.options) do
      if type(option) ~= "table" then
        error("segmented control option " .. index .. " must be a table")
      end
      required_string(option.id, "segmented control option id")
      required_string(option.label, "segmented control option label")
      if ids[option.id] then error("duplicate segmented control option id " .. option.id) end
      ids[option.id] = true
      if option.id == options.value then selected = true end
    end
    if not selected then error("segmented control value must match an option") end
  end

  local function push_style(selected, invalid)
    local prefix = "component.segmented_control." .. (selected and "selected" or "unselected")
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, resolve(prefix .. ".background.default"))
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, resolve(prefix .. ".background.hover"))
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, resolve(prefix .. ".background.pressed"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, resolve(prefix .. ".foreground"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Border, resolve(invalid and
      "component.segmented_control.invalid.border" or prefix .. ".border"))
  end

  function component.draw(options)
    options = options or {}
    validate(options)
    local available = ImGui.GetContentRegionAvail(ctx)
    local padding = resolve("semantic.space.control.padding_x")
    local gap = resolve("semantic.space.control.compact_gap")
    local height = resolve("semantic.size.control.medium")
    local segment_width = 0
    for _, option in ipairs(options.options) do
      segment_width = math.max(segment_width, ImGui.CalcTextSize(ctx, option.label) + padding * 2)
    end
    local inline = segment_width * #options.options + gap * (#options.options - 1) <= available
    local invalid = options.validation and options.validation.state == "invalid"
    local chosen
    if options.disabled then ImGui.BeginDisabled(ctx, true) end
    for index, option in ipairs(options.options) do
      if inline and index > 1 then ImGui.SameLine(ctx, 0, gap) end
      local selected = option.id == options.value
      push_style(selected, invalid)
      local clicked = ImGui.Button(ctx,
        option.label .. "##segment-" .. options.id .. "-" .. index,
        inline and segment_width or -1, height)
      ImGui.PopStyleColor(ctx, 5)
      if clicked and not selected and not options.disabled then chosen = option end
    end
    if options.disabled then ImGui.EndDisabled(ctx) end

    local value = chosen and chosen.id or options.value
    local events = {}
    if chosen then
      table.insert(events, {
        type = "selection.changed",
        id = options.id,
        value = value,
        option = chosen,
      })
    end
    return {
      value = value,
      option = chosen,
      changed = chosen ~= nil,
      layout = inline and "inline" or "stacked",
      events = events,
    }
  end

  function component.draw_field(options)
    options = options or {}
    required_string(options.label, "segmented control field label")
    return field_shell.draw(options, function(control_id)
      local control_options = {}
      for key, value in pairs(options) do control_options[key] = value end
      control_options.id = control_id:sub(3)
      return component.draw(control_options)
    end)
  end

  return component
end

return M
