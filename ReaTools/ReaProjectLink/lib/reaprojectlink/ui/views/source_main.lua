local view_models = require("reaprojectlink.ui.view_models")
local workflow = require("reaprojectlink.ui.workflow")
local card = require("reaprojectlink.ui.views.card")
local header = require("reaprojectlink.ui.views.header")
local reference_update_review = require("reaprojectlink.ui.views.reference_update_review")
local delivery_publish_review = require("reaprojectlink.ui.views.delivery_publish_review")

local M = {}

local function input(env, state, lanes)
  return {
    subscribed = state.reference_manifest_path ~= nil and state.reference_manifest_path ~= "",
    synchronized = state.synchronized_reference_revision,
    check = env.app.checks.reference,
    media_error = env.app.media_error,
    track_count = #lanes,
    delivery_revision = state.delivery_revision,
  }
end

local function display_name(name, fallback)
  return name ~= nil and name ~= "" and name or fallback
end

local function reference_sections(env, surface)
  local items, lookup = view_models.reference_name_list(surface)
  return { card.section(env, "source-reference-synchronized", {
    id = "synchronized", heading = "Synchronized", items = items, lookup = lookup, empty = "Nothing synchronized",
  }) }
end

local function delivery_sections(env, lanes)
  local registered, selected = {}, {}
  for index, lane in ipairs(lanes) do
    registered[index] = { name = lane.display_name, item_count = lane.item_count }
  end
  for index, track in ipairs(env.services.project_service.selected_tracks(env.adapter)) do
    selected[index] = { name = track.display_name, registered = track.registered }
  end
  local selection = { tracks = selected }
  return {
    card.section(env, "source-delivery-registered", { id = "registered", heading = "Registered",
      items = view_models.registered_items({ tracks = registered }), empty = "Nothing registered" }),
    card.section(env, "source-delivery-selected", { id = "selected", heading = "Selected",
      items = view_models.selected_items(selection), empty = "Nothing selected",
      actions = view_models.selection_actions(selection) }),
  }
end

local function handle_detach(env, action)
  local subscription, adapter = env.services.reference_subscription, env.adapter
  local name = display_name(action.name, "this " .. (action.kind or "object"))
  if action.id == "detach_track" then
    env.c.request_confirmation({
      id = "detach-reference-track",
      title = "Detach Reference Track",
      message = string.format(
        "Detach %s and its Reference items? They stay in the project. Later updates won't change them, and the next synchronization adds a new managed copy.", name),
      confirm_label = "Detach Track",
      danger = true,
    }, function()
      local result, err = subscription.detach_reference_track(adapter, action.ref)
      workflow.apply(env, result, err)
    end)
  elseif action.id == "detach_entry" then
    env.c.request_confirmation({
      id = "detach-reference-entry",
      title = "Detach Reference " .. action.kind,
      message = string.format(
        "Detach %s? It stays in the project. Later updates won't change it, and the next synchronization adds a new managed copy.", name),
      confirm_label = "Detach " .. action.kind,
      danger = true,
    }, function()
      local result, err = subscription.detach_timeline_entry(adapter, action.entry_id)
      workflow.apply(env, result, err)
    end)
  end
end

local function handle(env, action)
  if type(action) == "table" then
    handle_detach(env, action)
    return
  end
  local services, adapter, app = env.services, env.adapter, env.app
  if action == "choose_reference" then
    workflow.choose_reference(env)
  elseif action == "retry" then
    app:request_check()
  elseif action == "review_update" then
    reference_update_review.open(env)
  elseif action == "review_publish" then
    delivery_publish_review.open(env)
  elseif action == "register_selected" then
    local result, err = services.project_service.register_selected_tracks(adapter)
    workflow.apply(env, result, err)
  elseif action == "unregister_selected" then
    local result, err = services.project_service.unregister_selected_tracks(adapter)
    workflow.apply(env, result, err)
  end
end

function M.draw(env, state)
  local lanes = env.services.project_service.delivery_tracks(env.adapter)
  local values = input(env, state, lanes)
  local cards = view_models.source_cards(values)
  header.draw(env, state, "Source")
  local synchronized = (values.synchronized or 0) > 0
  local result = env.design_system.components.card_row.draw({
    id = "source-cards",
    cards = {
      {
        options = card.options(cards.reference, "source-reference", "film", "Reference",
          cards.highlight == "reference",
          synchronized and reference_sections(env, env.services.reference_subscription.local_surface(env.adapter))
            or nil),
        render_body = card.body(env, cards.reference),
      },
      {
        options = card.options(cards.delivery, "source-delivery", "upload", "Delivery",
          cards.highlight == "delivery", delivery_sections(env, lanes)),
        render_body = card.body(env, cards.delivery),
      },
    },
  })
  local action = result.actions["source-reference"] or result.actions["source-delivery"]
  if action then handle(env, action) end
end

return M
