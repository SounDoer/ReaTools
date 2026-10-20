local view_models = require("reaprojectlink.ui.view_models")
local workflow = require("reaprojectlink.ui.workflow")

local M = {}

function M.draw(env, state, badge, status_text)
  local app = env.app
  local meta = app.check_phase and "Checking..." or
    view_models.checked_text(app:seconds_since_check()) or "Not checked yet"
  if status_text then meta = status_text .. "  ·  " .. meta end
  local result = env.design_system.components.page_header.draw({
    id = "main-header",
    title = view_models.project_name(state.path),
    badge = badge,
    meta = meta,
    actions = {
      { id = "check", label = "Check Now", icon = "refresh" },
      { id = "settings", label = "Settings", icon = "gear", icon_only = true, variant = "quiet" },
    },
  })
  if result.action == "check" then app:request_check()
  elseif result.action == "settings" then app:open_settings() end
  workflow.draw_notices(env, state)
end

return M
