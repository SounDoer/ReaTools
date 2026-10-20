-- Internal measurement and alignment helpers shared by layout components.
local M = {}

function M.create(ImGui, ctx, adapter)
  local layout = {}

  local function with_text(role, renderer)
    if adapter.with_text then return adapter.with_text(role, renderer) end
    return renderer()
  end

  function layout.button_width(label)
    local text_width = with_text("body", function() return ImGui.CalcTextSize(ctx, label) end)
    return text_width + adapter.resolve("semantic.space.control.padding_x") * 2
  end

  function layout.icon_button_width()
    return adapter.resolve("semantic.size.control.medium")
  end

  function layout.gap()
    return adapter.resolve("semantic.space.control.gap")
  end

  -- Call right after a left item. Returns true when the trailing item had to
  -- move to its own line.
  function layout.trailing(width)
    ImGui.SameLine(ctx)
    local available = ImGui.GetContentRegionAvail(ctx)
    local wrapped = width > available
    if wrapped then
      ImGui.NewLine(ctx)
      available = ImGui.GetContentRegionAvail(ctx)
    end
    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + math.max(0, available - width))
    return wrapped
  end

  -- A child window begun twice in one frame (ReaImGui does this once at
  -- startup) submits no item to its parent, so a container whose last action
  -- was SetCursorPos fails ImGui's boundary check. Call at the end of any
  -- component that may end with a child window; the cursor does not move.
  function layout.settle()
    local _, spacing_y = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
    ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) - spacing_y)
    ImGui.Dummy(ctx, 0, 0)
  end

  return layout
end

return M
