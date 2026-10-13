local M = {}

function M.create(ImGui, ctx, adapter)
  local control = {}

  local function resolve(id) return adapter.resolve(id) end

  local function push_style(options)
    local background = options.read_only and "read_only" or "default"
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg,
      resolve("component.input_control.background." .. background))
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered,
      resolve("component.input_control.background.hover"))
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive,
      resolve("component.input_control.background.focused"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Text,
      resolve("component.input_control.foreground.default"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Border, resolve(
      "component.input_control.border." .. (options.invalid and "invalid" or "default")))
  end

  function control.draw(options)
    options = options or {}
    if type(options.id) ~= "string" or options.id == "" then
      error("input control id is required")
    end
    if type(options.value) ~= "string" then error("input control value must be a string") end
    if options.disabled and options.read_only then
      error("input control cannot be both disabled and read_only")
    end

    local blocked = options.disabled == true or options.read_only == true
    local flags = 0
    if options.read_only then flags = flags | ImGui.InputTextFlags_ReadOnly end
    ImGui.SetNextItemWidth(ctx, options.width or -1)
    push_style(options)
    if options.disabled then ImGui.BeginDisabled(ctx, true) end
    local changed, value
    if options.placeholder and options.placeholder ~= "" then
      changed, value = ImGui.InputTextWithHint(ctx, options.id,
        options.placeholder, options.value, flags)
    else
      changed, value = ImGui.InputText(ctx, options.id, options.value, flags)
    end
    local committed = ImGui.IsItemDeactivatedAfterEdit(ctx)
    if options.disabled then ImGui.EndDisabled(ctx) end
    ImGui.PopStyleColor(ctx, 5)

    return {
      value = value or options.value,
      changed = changed == true and not blocked,
      committed = committed == true and not blocked,
    }
  end

  return control
end

return M
