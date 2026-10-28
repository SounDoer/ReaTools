-- Shared Card options, body, and sections for a card view model from
-- ui/view_models.lua.
local view_models = require("reaprojectlink.ui.view_models")

local M = {}

function M.options(model, id, icon, title, highlighted, sections)
  return {
    id = id, icon = icon, title = title,
    variant = highlighted and "emphasized" or nil,
    status = { role = model.level, text = model.status, detail = model.status_detail },
    sections = sections,
    footer = view_models.card_footer(model, highlighted),
  }
end

-- Card body renderer for the note, or nil without one.
function M.body(env, model)
  if model.note then return function() env.c.small(model.note) end end
end

-- Card section listing `spec.items` (from view_models) in a compact List,
-- with the muted `spec.empty` when there are none and `spec.actions` below.
-- Group collapse state lives in `app.collapsed_groups` under
-- "<list id>/<group id>". `render` returns `spec.lookup[row]` for a row
-- action, or the chosen action id.
function M.section(env, list_id, spec)
  return { id = spec.id, heading = spec.heading, render = function()
    local components, collapsed = env.design_system.components, env.app.collapsed_groups
    local action
    if #spec.items > 0 then
      for _, item in ipairs(spec.items) do
        if item.kind == "group" then item.collapsed = collapsed[list_id .. "/" .. item.id] == true end
      end
      local result = components.list.draw({ id = list_id, variant = "compact", items = spec.items })
      if result.toggled_group then
        local key = list_id .. "/" .. result.toggled_group
        collapsed[key] = not collapsed[key]
      end
      if result.action and spec.lookup then action = spec.lookup[result.action.row] end
    elseif spec.empty then
      env.c.muted(spec.empty)
    end
    if spec.actions then
      action = components.action_bar.draw({ id = list_id .. "-actions", actions = spec.actions }).action or action
    end
    return action
  end }
end

return M
