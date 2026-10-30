local field_shell_module = require("reaui.design_field_shell")

local M = {}

local DATA_STATES = { ready = true, loading = true, empty = true, failed = true }

local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter, field_shell)
  field_shell = field_shell or field_shell_module.create(ImGui, ctx, adapter)
  local component = {}

  local function resolve(id) return adapter.resolve(id) end

  local function validate(options)
    required_string(options.id, "dropdown id")
    if type(options.options) ~= "table" then error("dropdown options are required") end
    local ids = {}
    for index, option in ipairs(options.options) do
      if type(option) ~= "table" then error("dropdown option " .. index .. " must be a table") end
      required_string(option.id, "dropdown option id")
      required_string(option.label, "dropdown option label")
      if ids[option.id] then error("duplicate dropdown option id " .. option.id) end
      ids[option.id] = true
    end
    local data_state = options.data_state or "ready"
    if not DATA_STATES[data_state] then
      error("unsupported dropdown data_state " .. tostring(data_state))
    end
    if data_state == "empty" and #options.options > 0 then
      error("empty dropdown cannot contain options")
    end
    if options.value ~= nil and type(options.value) ~= "string" then
      error("dropdown value must be a string or nil")
    end
    return data_state
  end

  local function selection(options)
    for _, option in ipairs(options.options) do
      if option.id == options.value then return option end
    end
    return nil
  end

  local function preview(options, data_state, selected)
    if selected then return selected.label end
    if options.value ~= nil then
      required_string(options.stale_label, "dropdown stale_label")
      return options.stale_label
    end
    if data_state == "loading" then return options.loading_label or "Loading..." end
    if data_state == "empty" then return options.empty_label or "No options" end
    if data_state == "failed" then return options.failed_label or "Could not load options" end
    return options.placeholder or "Select..."
  end

  local function push_style(invalid)
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, resolve("component.dropdown.background.default"))
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered, resolve("component.dropdown.background.hover"))
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive, resolve("component.dropdown.background.pressed"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, resolve("component.dropdown.foreground.default"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Border, resolve(
      "component.dropdown.border." .. (invalid and "invalid" or "default")))
    ImGui.PushStyleColor(ctx, ImGui.Col_Header, resolve("component.dropdown.option.selected"))
    ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered, resolve("component.dropdown.option.hover"))
    ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive, resolve("component.dropdown.option.pressed"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, resolve("component.dropdown.background.default"))
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, resolve("component.dropdown.background.hover"))
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, resolve("component.dropdown.background.pressed"))
    local padding_x = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, padding_x,
      (resolve("semantic.size.control.medium") - ImGui.GetFontSize(ctx)) / 2)
    -- The option popup would otherwise inherit the page padding.
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,
      resolve("semantic.space.inset.padding_x"), resolve("semantic.space.inset.padding_y"))
  end

  function component.draw(options)
    options = options or {}
    local data_state = validate(options)
    local selected = selection(options)
    local visible = preview(options, data_state, selected)
    local blocked = options.disabled == true or data_state ~= "ready" or #options.options == 0
    local invalid = options.validation and options.validation.state == "invalid"

    ImGui.SetNextItemWidth(ctx, options.width or -1)
    push_style(invalid)
    if blocked then ImGui.BeginDisabled(ctx, true) end
    local opened = ImGui.BeginCombo(ctx, "##dropdown-" .. options.id, visible)
    local combo_hovered = ImGui.IsItemHovered(ctx)
    local chosen
    if opened then
      for index, option in ipairs(options.options) do
        local is_selected = option.id == options.value
        if ImGui.Selectable(ctx,
            option.label .. "##dropdown-" .. options.id .. "-" .. index,
            is_selected) then
          chosen = option
        end
        if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, option.label) end
        if is_selected then ImGui.SetItemDefaultFocus(ctx) end
      end
      ImGui.EndCombo(ctx)
    end
    if blocked then ImGui.EndDisabled(ctx) end
    ImGui.PopStyleVar(ctx, 2)
    ImGui.PopStyleColor(ctx, 11)
    if combo_hovered then ImGui.SetTooltip(ctx, visible) end

    local changed = chosen ~= nil and chosen.id ~= options.value and not blocked
    local value = changed and chosen.id or options.value
    local stale = value ~= nil and selected == nil
    if changed then stale = false end
    local events = {}
    if changed then
      table.insert(events, {
        type = "selection.changed",
        id = options.id,
        value = value,
        option = chosen,
      })
    end
    return {
      value = value,
      option = changed and chosen or selected,
      changed = changed,
      stale = stale,
      data_state = data_state,
      events = events,
    }
  end

  function component.draw_field(options)
    options = options or {}
    required_string(options.label, "dropdown field label")
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
