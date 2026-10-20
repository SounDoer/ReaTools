local layout_module = require("reaui.design_layout")

local M = {}

local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter, layout)
  layout = layout or layout_module.create(ImGui, ctx, adapter)
  local component = {}

  local function title(text)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, adapter.resolve("semantic.color.text.primary"))
    ImGui.TextWrapped(ctx, text)
    ImGui.PopStyleColor(ctx)
  end

  function component.draw(options, render)
    options = options or {}
    required_string(options.id, "section heading id")
    required_string(options.title, "section heading title")
    if options.gap_above ~= nil and type(options.gap_above) ~= "boolean" then
      error("section heading gap_above must be a boolean")
    end
    if render ~= nil and type(render) ~= "function" then
      error("section heading renderer must be a function")
    end

    local gap = options.gap_above
    if gap == nil then
      -- Screen coordinates, because the local start position moves with scrolling.
      local _, cursor_y = ImGui.GetCursorScreenPos(ctx)
      local _, window_y = ImGui.GetWindowPos(ctx)
      local _, start_y = ImGui.GetCursorStartPos(ctx)
      gap = cursor_y > window_y + start_y
    end
    if gap then
      local _, spacing_y = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
      ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) - spacing_y + adapter.resolve("semantic.space.section.loose"))
    end
    if adapter.with_text then
      adapter.with_text("heading", function() title(options.title) end)
    else
      title(options.title)
    end

    if not render then return nil end
    local result = render()
    layout.settle()
    return result
  end

  return component
end

return M
