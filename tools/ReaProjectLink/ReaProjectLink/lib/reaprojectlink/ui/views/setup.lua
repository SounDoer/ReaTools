local workflow = require("reaprojectlink.ui.workflow")

local M = {}

local function choice(id, icon, title, description, label)
  return {
    options = {
      id = id, icon = icon, title = title, description = description,
      footer = { actions = { { id = "initialize", label = label, variant = "secondary" } } },
    },
  }
end

function M.draw(env, state)
  local c, app = env.c, env.app
  local components = env.design_system.components
  local service = env.services.project_service
  local actions = {}
  workflow.draw_notices(env, state)
  if c.begin_page("setup", false) then
    components.page_header.draw({
      id = "setup",
      title = "Set Up ReaProjectLink",
      summary = "Choose the type for this project.",
    })
    actions = components.card_row.draw({
      id = "setup",
      cards = {
        choice("setup-source", "upload", "Source Project",
          "An editing project that publishes Deliveries to the Master Project.",
          "Initialize Source Project"),
        choice("setup-master", "download", "Master Project",
          "An integration project that publishes the Reference and receives Deliveries.",
          "Initialize Master Project"),
      },
    }).actions
  end
  c.end_page()
  local source, master = actions["setup-source"] ~= nil, actions["setup-master"] ~= nil
  if source then
    local result, err = service.initialize_source(env.adapter)
    workflow.apply(env, result, err)
  elseif master then
    local result, err = service.initialize_master(env.adapter)
    workflow.apply(env, result, err)
  end
  if source or master then app:request_check() end
end

return M
