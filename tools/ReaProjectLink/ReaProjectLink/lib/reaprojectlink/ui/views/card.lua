-- Shared Card options and body for a card view model from ui/view_models.lua.
local view_models = require("reaprojectlink.ui.view_models")

local M = {}

function M.options(model, id, icon, title, highlighted)
  return {
    id = id, icon = icon, title = title,
    variant = highlighted and "emphasized" or nil,
    status = { role = model.level, text = model.status, detail = model.status_detail },
    selection = model.selection,
    footer = view_models.card_footer(model, highlighted),
  }
end

-- Card body: stats, then the note, then `extra`.
function M.body(env, id, model, extra)
  if model.stats then env.design_system.components.stat_group.draw({ id = id .. "-stats", stats = model.stats }) end
  if model.note then env.c.small(model.note) end
  if extra then extra() end
end

return M
