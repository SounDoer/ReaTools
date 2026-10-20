local M = {}

function M.draw(c, ImGui, ctx)
  -- ImGui.SameLine(ctx, 0, 99) in a comment is ignored.
  c.text("Reference")
  ImGui.SameLine(ctx, 0, 8)
  ImGui.Separator(ctx)
  c.same_line_right(120)
end

return M
