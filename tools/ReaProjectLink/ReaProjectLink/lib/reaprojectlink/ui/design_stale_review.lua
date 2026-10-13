local status_module = require("reaprojectlink.ui.design_status")
local button_module = require("reaprojectlink.ui.design_button")

local M = {}
local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter, status, button)
  status = status or status_module.create(ImGui, ctx, adapter)
  button = button or button_module.create(ImGui, ctx, adapter)
  local pattern = {}
  function pattern.draw(options)
    options = options or {}
    required_string(options.id, "stale review id")
    required_string(options.title, "stale review title")
    required_string(options.message, "stale review message")
    required_string(options.refresh_label, "stale review refresh_label")
    status.draw({ role = "warning", role_label = options.title, text = options.message })
    local event = button.draw({
      id = options.id .. "-refresh", label = options.refresh_label,
      variant = "primary", disabled = options.disabled,
    })
    local events = {}
    if event then table.insert(events, { type = "review.refresh_requested", id = options.id }) end
    return { events = events, refresh_requested = event ~= nil }
  end
  return pattern
end
return M
