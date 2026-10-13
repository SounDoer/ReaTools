local notice_module = require("reaprojectlink.ui.design_notice")

local M = {}
local STATES = {
  idle = { role = "neutral", label = "Not started" },
  running = { role = "neutral", label = "Running" },
  succeeded = { role = "ready", label = "Completed" },
  failed = { role = "blocked", label = "Failed" },
  cancelled = { role = "warning", label = "Cancelled" },
  partial = { role = "warning", label = "Partially completed" },
}

local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter, notice)
  notice = notice or notice_module.create(ImGui, ctx, adapter)
  local pattern = {}

  function pattern.draw(options)
    options = options or {}
    required_string(options.id, "external operation status id")
    required_string(options.label, "external operation status label")
    required_string(options.message, "external operation status message")
    local definition = STATES[options.state]
    if not definition then error("unsupported external operation state " .. tostring(options.state)) end
    if options.progress ~= nil then
      if type(options.progress) ~= "number" or options.progress < 0 or options.progress > 100 then
        error("external operation progress must be between 0 and 100")
      end
      if options.state ~= "running" and options.state ~= "partial" then
        error("external operation progress is only valid while running or partially completed")
      end
    end
    if options.can_cancel and options.state ~= "running" then
      error("external operation cancel is only valid while running")
    end
    if options.can_retry and options.state ~= "failed" and options.state ~= "cancelled" and
        options.state ~= "partial" then
      error("external operation retry requires failed, cancelled, or partial state")
    end
    if options.can_dismiss and (options.state == "idle" or options.state == "running") then
      error("external operation dismiss is unavailable before an outcome")
    end

    local text = options.label .. ": " .. options.message
    if options.progress ~= nil then text = text .. " Progress: " .. math.floor(options.progress + 0.5) .. "%." end
    if options.detail and options.detail ~= "" then text = text .. " " .. options.detail end
    local actions = {}
    if options.can_cancel then table.insert(actions, { id = "cancel", label = options.cancel_label or "Cancel" }) end
    if options.can_retry then table.insert(actions, { id = "retry", label = options.retry_label or "Retry" }) end
    if options.can_dismiss then table.insert(actions, { id = "dismiss", label = options.dismiss_label or "Dismiss" }) end
    local result = notice.draw({
      id = options.id,
      role = definition.role,
      role_label = options.state_label or definition.label,
      text = text,
      actions = actions,
      disabled = options.disabled,
    })
    local events = {}
    if result.action then
      table.insert(events, {
        type = "operation." .. result.action .. "_requested",
        id = options.id,
        state = options.state,
      })
    end
    return { state = options.state, action = result.action, events = events }
  end

  return pattern
end

return M
