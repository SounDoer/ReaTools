local button_module = require("reaui.design_button")
local status_module = require("reaui.design_status")
local layout_module = require("reaui.design_layout")

local M = {}
local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter, button, status, layout)
  button = button or button_module.create(ImGui, ctx, adapter)
  status = status or status_module.create(ImGui, ctx, adapter)
  layout = layout or layout_module.create(ImGui, ctx, adapter)
  local pattern = {}
  local function line_height(role)
    if adapter.with_text then return adapter.with_text(role, function() return ImGui.GetTextLineHeight(ctx) end) end
    return ImGui.GetTextLineHeight(ctx)
  end
  function pattern.draw(options)
    options = options or {}
    required_string(options.id, "review footer id")
    required_string(options.summary, "review footer summary")
    required_string(options.complete_label, "review footer complete_label")
    local _, spacing_y = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
    ImGui.Separator(ctx)
    local top = ImGui.GetCursorPosY(ctx) - spacing_y + adapter.resolve("semantic.space.footer.padding_y")
    ImGui.SetCursorPosY(ctx, top)
    local available = ImGui.GetContentRegionAvail(ctx)
    local inline = available >= adapter.resolve("semantic.size.field.inline_wide")
    local status_options = { role = options.role or "neutral", text = options.summary, presentation = "inline" }
    if inline then
      local control_height = adapter.resolve("semantic.size.control.medium")
      ImGui.SetCursorPosY(ctx, top + (control_height - line_height("body")) / 2)
      status.draw(status_options)
      local width = layout.button_width(options.complete_label)
      if options.running_label then width = math.max(width, layout.button_width(options.running_label)) end
      local moved = layout.trailing(width)
      ImGui.SetCursorPosY(ctx, moved and ImGui.GetCursorPosY(ctx) or top)
    else
      status.draw(status_options)
    end
    local event = button.draw({
      id = options.id .. "-complete", label = options.complete_label,
      variant = options.variant or "primary",
      disabled = options.disabled or options.enabled == false,
      running = options.running,
      running_label = options.running_label,
      stretch = not inline,
    })
    local events = {}
    if event then table.insert(events, { type = "review.complete_requested", id = options.id }) end
    return { events = events, complete_requested = event ~= nil }
  end
  return pattern
end
return M
