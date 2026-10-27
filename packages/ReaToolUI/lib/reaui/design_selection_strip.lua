local button_module = require("reaui.design_button")
local action_bar_module = require("reaui.design_action_bar")

local M = {}

local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter, deps)
  deps = deps or {}
  local button = deps.button or button_module.create(ImGui, ctx, adapter)
  local action_bar = deps.action_bar or action_bar_module.create(ImGui, ctx, adapter, button)
  local component = {}

  local function resolve(id) return adapter.resolve(id) end
  local function with_text(role, renderer)
    if adapter.with_text then return adapter.with_text(role, renderer) end
    return renderer()
  end

  local function validate(options)
    required_string(options.id, "selection strip id")
    required_string(options.heading, "selection strip heading")
    if type(options.parts) ~= "table" or #options.parts == 0 then error("selection strip needs parts") end
    for _, part in ipairs(options.parts) do
      required_string(part.label, "selection part label")
      if type(part.value) ~= "number" then error("selection part value must be a number") end
    end
    if type(options.actions) ~= "table" or #options.actions == 0 then
      error("selection strip needs actions")
    end
    for _, action in ipairs(options.actions) do
      if action.variant == "primary" then error("selection strip actions cannot be primary") end
    end
  end

  -- Units are runs of text pieces; a line only wraps between units.
  local function build_units(parts)
    local label_color = resolve("component.card.selection.label")
    local value_color = resolve("component.card.selection.value")
    local muted = resolve("component.card.selection.muted")
    local units = {}
    for index, part in ipairs(parts) do
      local zero = part.value == 0
      local unit = {
        { text = part.label .. " ", role = "body", color = zero and muted or label_color },
        { text = tostring(part.value), role = "heading", color = zero and muted or value_color },
      }
      if index < #parts then table.insert(unit, { text = " · ", role = "body", color = muted }) end
      unit.width = 0
      for _, piece in ipairs(unit) do
        piece.width, piece.height = with_text(piece.role, function()
          return ImGui.CalcTextSize(ctx, piece.text), ImGui.GetTextLineHeight(ctx)
        end)
        unit.width = unit.width + piece.width
      end
      units[index] = unit
    end
    return units
  end

  local function draw_text(role, color, text)
    with_text(role, function()
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, color)
      ImGui.Text(ctx, text)
      ImGui.PopStyleColor(ctx)
    end)
  end

  function component.draw(options)
    options = options or {}
    validate(options)
    local result = { events = {}, action = nil }
    local _, spacing_y = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
    local available = ImGui.GetContentRegionAvail(ctx)
    local line_height = with_text("heading", function() return ImGui.GetTextLineHeight(ctx) end)
    local x0 = ImGui.GetCursorPosX(ctx)

    draw_text("metadata", resolve("component.card.selection.heading"), options.heading)

    -- Pieces share a bottom edge so the smaller text sits on the value's baseline.
    local x, y = 0, ImGui.GetCursorPosY(ctx)
    for _, unit in ipairs(build_units(options.parts)) do
      if x > 0 and x + unit.width > available then x, y = 0, y + line_height + spacing_y end
      for _, piece in ipairs(unit) do
        ImGui.SetCursorPos(ctx, x0 + x, y + line_height - piece.height)
        draw_text(piece.role, piece.color, piece.text)
        x = x + piece.width
      end
    end

    ImGui.SetCursorPos(ctx, x0, y + line_height + resolve("semantic.space.control.gap"))
    local action = action_bar.draw({ id = options.id, actions = options.actions }).action
    if action then
      result.action = action
      table.insert(result.events, { type = "selection_strip.activated", id = options.id, action = action })
    end
    return result
  end

  return component
end

return M
