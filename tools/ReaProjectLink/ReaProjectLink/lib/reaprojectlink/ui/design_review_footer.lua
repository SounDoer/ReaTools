local button_module = require("reaprojectlink.ui.design_button")
local status_module = require("reaprojectlink.ui.design_status")

local M = {}
local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter, button, status)
  button = button or button_module.create(ImGui, ctx, adapter)
  status = status or status_module.create(ImGui, ctx, adapter)
  local pattern = {}
  function pattern.draw(options)
    options = options or {}
    required_string(options.id, "review footer id")
    required_string(options.summary, "review footer summary")
    required_string(options.complete_label, "review footer complete_label")
    ImGui.Separator(ctx)
    local available = ImGui.GetContentRegionAvail(ctx)
    local inline = available >= adapter.resolve("semantic.size.field.inline_wide")
    status.draw({ role = options.role or "neutral", text = options.summary })
    if inline then
      local visible_label = options.running and options.running_label or options.complete_label
      local width = ImGui.CalcTextSize(ctx, visible_label) +
        adapter.resolve("semantic.space.control.padding_x") * 2
      ImGui.SameLine(ctx)
      ImGui.SetCursorPosX(ctx, math.max(ImGui.GetCursorPosX(ctx),
        ImGui.GetCursorPosX(ctx) + ImGui.GetContentRegionAvail(ctx) - width))
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
