local default_icons = require("reaui.icons")

local M = {}

local BUTTON_VARIANTS = { primary = true, secondary = true, quiet = true, danger = true }
local ICON_VARIANTS = { secondary = true, quiet = true, danger = true }
local SIZES = { medium = "semantic.size.control.medium", compact = "semantic.size.control.compact" }

local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

local function size_token(size)
  local token = SIZES[size or "medium"]
  if not token then error("unsupported button size " .. tostring(size)) end
  return token
end

function M.create(ImGui, ctx, adapter, icon_renderer)
  icon_renderer = icon_renderer or default_icons
  local component = {}

  local function resolve(id) return adapter.resolve(id) end
  local function with_text(role, renderer)
    if adapter.with_text then return adapter.with_text(role, renderer) end
    return renderer()
  end

  local function push_variant(variant)
    local prefix = "component.button." .. variant
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, resolve(prefix .. ".background.default"))
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, resolve(prefix .. ".background.hover"))
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, resolve(prefix .. ".background.pressed"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, resolve(prefix .. ".foreground.default"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Border, resolve(prefix .. ".border.default"))
  end

  local function finish_variant() ImGui.PopStyleColor(ctx, 5) end

  local function event(clicked, blocked, id)
    if clicked and not blocked then return { type = "button.activated", id = id } end
    return nil
  end

  function component.draw(options)
    options = options or {}
    required_string(options.id, "button id")
    required_string(options.label, "button label")
    local variant = options.variant or "secondary"
    if not BUTTON_VARIANTS[variant] then error("unsupported button variant " .. tostring(variant)) end
    if options.running and (type(options.running_label) ~= "string" or options.running_label == "") then
      error("running_label is required while a button is running")
    end
    local height_token = size_token(options.size)

    return with_text("body", function()
      local visible_label = options.running and options.running_label or options.label
      local label_width = ImGui.CalcTextSize(ctx, options.label)
      if options.running_label then
        local running_width = ImGui.CalcTextSize(ctx, options.running_label)
        label_width = math.max(label_width, running_width)
      end
      local width = label_width + resolve("semantic.space.control.padding_x") * 2
      if options.stretch then width = ImGui.GetContentRegionAvail(ctx) end
      local height = resolve(height_token)
      local blocked = options.disabled == true or options.running == true

      push_variant(variant)
      if blocked then ImGui.BeginDisabled(ctx, true) end
      local clicked = ImGui.Button(ctx, visible_label .. "##" .. options.id, width, height)
      if blocked then ImGui.EndDisabled(ctx) end
      finish_variant()
      return event(clicked, blocked, options.id)
    end)
  end

  function component.draw_icon(options)
    options = options or {}
    required_string(options.id, "icon button id")
    required_string(options.icon, "icon button icon")
    required_string(options.accessible_label, "icon button accessible_label")
    if options.running then error("icon button does not support running") end
    local variant = options.variant or "quiet"
    if not ICON_VARIANTS[variant] then
      error("unsupported icon button variant " .. tostring(variant))
    end

    local control_size = resolve(size_token(options.size))
    local icon_size = resolve("semantic.size.icon.medium")
    local x, y = ImGui.GetCursorScreenPos(ctx)
    push_variant(variant)
    if options.disabled then ImGui.BeginDisabled(ctx, true) end
    local clicked = ImGui.Button(ctx, "##" .. options.id, control_size, control_size)
    if options.disabled then ImGui.EndDisabled(ctx) end
    finish_variant()

    local foreground = options.disabled and resolve("semantic.color.text.disabled") or
      resolve("component.button." .. variant .. ".foreground.default")
    local inset = (control_size - icon_size) / 2
    local known = icon_renderer.draw(ImGui, ImGui.GetWindowDrawList(ctx), options.icon,
      x + inset, y + inset, icon_size, foreground)
    if not known then error("unsupported icon " .. options.icon) end
    if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, options.accessible_label) end
    return event(clicked, options.disabled == true, options.id)
  end

  return component
end

return M
