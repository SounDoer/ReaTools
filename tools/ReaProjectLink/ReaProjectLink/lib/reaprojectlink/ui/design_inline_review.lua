local status_module = require("reaprojectlink.ui.design_status")
local button_module = require("reaprojectlink.ui.design_button")

local M = {}
local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end
local function count(value, name)
  value = value or 0
  if type(value) ~= "number" or math.type(value) ~= "integer" or value < 0 then
    error(name .. " must be a non-negative integer")
  end
  return value
end

function M.create(ImGui, ctx, adapter, status, button)
  status = status or status_module.create(ImGui, ctx, adapter)
  button = button or button_module.create(ImGui, ctx, adapter)
  local pattern = {}
  function pattern.draw(options, render_content)
    options = options or {}
    required_string(options.id, "inline review id")
    required_string(options.title, "inline review title")
    required_string(options.message, "inline review message")
    required_string(options.confirm_label, "inline review confirm_label")
    if render_content ~= nil and type(render_content) ~= "function" then
      error("inline review content renderer must be a function")
    end
    local blockers = count(options.blocker_count, "inline review blocker_count")
    local warnings = count(options.warning_count, "inline review warning_count")
    local role = blockers > 0 and "blocked" or (warnings > 0 and "warning" or "ready")
    status.draw({ role = role, role_label = options.title, text = options.message })
    local content_result
    if render_content then content_result = render_content() end

    local available = ImGui.GetContentRegionAvail(ctx)
    local gap = adapter.resolve("semantic.space.control.gap")
    local padding = adapter.resolve("semantic.space.control.padding_x")
    local cancel_label = options.cancel_label or "Back to editing"
    local total = ImGui.CalcTextSize(ctx, cancel_label) + ImGui.CalcTextSize(ctx, options.confirm_label) +
      padding * 4 + gap
    local inline = total <= available
    local cancel = button.draw({
      id = options.id .. "-cancel", label = cancel_label,
      variant = "secondary", disabled = options.running, stretch = not inline,
    })
    if inline then ImGui.SameLine(ctx, 0, gap) end
    local confirm = button.draw({
      id = options.id .. "-confirm", label = options.confirm_label,
      variant = options.danger and "danger" or "primary",
      disabled = options.disabled or blockers > 0,
      running = options.running, running_label = options.running_label,
      stretch = not inline,
    })
    local events = {}
    for _, event in ipairs((content_result and content_result.events) or {}) do table.insert(events, event) end
    if cancel then table.insert(events, { type = "inline_review.cancelled", id = options.id }) end
    if confirm then table.insert(events, { type = "inline_review.confirmed", id = options.id }) end
    return {
      blocker_count = blockers, warning_count = warnings, role = role,
      content_result = content_result, events = events,
    }
  end
  return pattern
end
return M
