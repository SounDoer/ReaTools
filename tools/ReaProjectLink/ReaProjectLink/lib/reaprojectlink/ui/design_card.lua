local M = {}

local CHILD_BORDERS = 1 << 0
local CHILD_ALWAYS_USE_PADDING = 1 << 1
local CHILD_AUTO_RESIZE_Y = 1 << 5
local CARD_FLAGS = CHILD_BORDERS | CHILD_ALWAYS_USE_PADDING | CHILD_AUTO_RESIZE_Y

local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter)
  local component = {}
  local function resolve(id) return adapter.resolve(id) end
  local function with_text(role, renderer)
    if adapter.with_text then return adapter.with_text(role, renderer) end
    return renderer()
  end

  local function wrapped(token, value)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, resolve(token))
    ImGui.TextWrapped(ctx, value)
    ImGui.PopStyleColor(ctx)
  end

  function component.draw(options, render_content)
    options = options or {}
    required_string(options.id, "card id")
    if render_content ~= nil and type(render_content) ~= "function" then
      error("card content renderer must be a function")
    end
    if options.width ~= nil and (type(options.width) ~= "number" or options.width < 0) then
      error("card width must be a non-negative number")
    end
    local emphasized = options.variant == "emphasized"
    if options.variant ~= nil and options.variant ~= "default" and not emphasized then
      error("unsupported card variant " .. tostring(options.variant))
    end

    ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, resolve("component.card.background"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Border, resolve(
      "component.card.border." .. (emphasized and "emphasized" or "default")))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildBorderSize, resolve(
      emphasized and "semantic.border.emphasis.width" or "semantic.border.control.width"))
    local padding = resolve("semantic.space.container.padding")
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, padding, padding)
    local visible = ImGui.BeginChild(ctx, "##card-" .. options.id,
      options.width or 0, 0, CARD_FLAGS)
    ImGui.PopStyleVar(ctx, 2)
    ImGui.PopStyleColor(ctx, 2)

    local ok, result
    if visible then
      if options.title then
        required_string(options.title, "card title")
        with_text("heading", function()
          ImGui.TextColored(ctx, resolve("component.card.title"), options.title)
        end)
      end
      if options.description and options.description ~= "" then
        wrapped("component.card.description", options.description)
      end
      if render_content then ok, result = pcall(render_content) else ok = true end
    else
      ok = true
    end
    if visible then ImGui.EndChild(ctx) end
    if not ok then error(result, 0) end
    return result
  end

  return component
end

return M
