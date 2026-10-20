local view_models = require("reaprojectlink.ui.view_models")
local workflow = require("reaprojectlink.ui.workflow")
local checks = require("reaprojectlink.ui.checks")
local card = require("reaprojectlink.ui.views.card")
local header = require("reaprojectlink.ui.views.header")
local reference_publish_review = require("reaprojectlink.ui.views.reference_publish_review")
local delivery_sync_review = require("reaprojectlink.ui.views.delivery_sync_review")

local M = {}

local ROW_MENU = {
  { id = "sync_other", label = "Sync to Another Revision..." },
  { id = "remove", label = "Remove Subscription..." },
}

local function input(env, state)
  local services, adapter, app = env.services, env.adapter, env.app
  local tracks = services.reference_publish.reference_tracks(adapter)
  local timeline_entries, marker_error = services.reference_publish.timeline_entries(adapter)
  local markers, regions = 0, 0
  for _, entry in ipairs(timeline_entries or {}) do
    if entry.registered then
      if entry.kind == "region" then regions = regions + 1
      else markers = markers + 1 end
    end
  end
  local rows = {}
  for _, entry in ipairs(checks.subscriptions(adapter)) do
    local unmapped = 0
    for _, binding in ipairs(entry.lanes or {}) do
      if binding.unmapped then unmapped = unmapped + 1 end
    end
    table.insert(rows, {
      id = entry.sourceProjectId,
      name = view_models.subscription_name(entry),
      accepted = entry.acceptedDeliveryRevision or 0,
      unmapped_count = unmapped,
      check = app.checks.deliveries[entry.sourceProjectId],
    })
  end
  return {
    track_count = #tracks,
    marker_count = markers,
    region_count = regions,
    marker_error = marker_error,
    reference_revision = state.reference_revision,
    package_check = app.checks.reference,
    selection_counts = services.reference_publish.selection_counts(adapter),
    rows = rows,
  }
end

-- Moving a managed Item away from its bound Track prompts once (D083). The
-- app shell calls this once per frame for every Master view (main panel,
-- Reviews, Settings).
function M.confirm_moved_items(env)
  local adapter, app = env.adapter, env.app
  local change_count = adapter.project_change_count()
  if change_count == app.moved_items_change_count then return end
  app.moved_items_change_count = change_count
  env.services.reference_publish.separate_copied_identities(adapter)
  local moved = env.services.delivery_update.moved_instances(adapter)
  if #moved == 0 then return end
  local queued = env.c.request_confirmation({
    id = "keep-moved-items-local",
    title = "Keep Moved Items as Local",
    message = string.format(
      "%d synchronized Item(s) were moved out of their mapped Track.\n\n" ..
      "Keep them as local Master content? They will no longer be updated from the Source.\n\n" ..
      "Cancel to keep them Source-managed; the next synchronization will replace them.", #moved),
    confirm_label = "Keep as Local",
  }, function()
    local result, err = env.services.delivery_update.detach_many(adapter, moved)
    workflow.report(env, result, err, function(value)
      return string.format("Kept %s as local content.", view_models.count(value.detached, "moved item"))
    end)
    app.moved_items_change_count = adapter.project_change_count()
  end)
  if not queued then
    app.moved_items_change_count = nil
    return
  end
  app.moved_items_change_count = adapter.project_change_count()
end

local function handle_reference(env, action)
  local publish, adapter = env.services.reference_publish, env.adapter
  if action == "review_publish" then
    reference_publish_review.open(env)
  elseif action == "register_selected" then
    local result, err = publish.register_selected(adapter)
    workflow.apply(env, result, err)
  elseif action == "unregister_selected" then
    local result, err = publish.unregister_selected(adapter)
    workflow.apply(env, result, err)
  end
end

local function handle_delivery(env, action)
  local app = env.app
  if action.id == "add_delivery" then
    delivery_sync_review.open_import(env)
  elseif action.id == "sync" or action.id == "map_lanes" or action.id == "sync_other" then
    delivery_sync_review.open_update(env, action.row.id)
  elseif action.id == "retry" then
    app:request_check()
  elseif action.id == "remove" then
    env.c.request_confirmation({
      id = "remove-subscription",
      title = "Remove Subscription",
      message = string.format("Stop following %s? Its tracks and items stay in this project.", action.row.name),
      confirm_label = "Remove Subscription",
      danger = true,
    }, function()
      local result, err = env.services.delivery_import.remove_subscription(env.adapter, action.row.id)
      workflow.apply(env, result, err)
      app:request_check()
    end)
  end
end

-- Only the first row needing attention gets the primary button.
local function list_items(cards, highlighted)
  local items, by_id, primary_used = {}, {}, false
  for _, row in ipairs(cards.rows) do
    local primary = highlighted and row.attention and not primary_used
    primary_used = primary_used or primary
    by_id[row.id] = row
    table.insert(items, {
      kind = "row", id = row.id, title = row.name, detail = row.note,
      status = { role = row.level, text = row.status },
      action = row.action and { id = row.action.id, label = row.action.label,
        variant = primary and "primary" or nil },
      menu = { accessible_label = "Subscription actions", items = ROW_MENU },
    })
  end
  return items, by_id
end

local function deliveries_entry(env, cards, chosen)
  local highlighted = cards.highlight == "deliveries"
  local options = {
    id = "master-deliveries", icon = "download", title = "Deliveries",
    variant = highlighted and "emphasized" or nil,
    trailing = { kind = "icon_button", id = "add", icon = "plus", accessible_label = "Add Delivery" },
  }
  if #cards.rows == 0 then
    local empty = cards.deliveries_empty
    options.status = { role = empty.level, text = empty.status }
    options.footer = { actions = { { id = empty.action.id, label = empty.action.label,
      variant = highlighted and "primary" or nil } } }
    return { options = options, render_body = function() env.c.small(empty.note) end }
  end
  options.status = view_models.deliveries_status(cards.rows)
  local items, by_id = list_items(cards, highlighted)
  return {
    options = options,
    render_body = function()
      local result = env.design_system.components.list.draw({ id = "master-deliveries-list",
        variant = "standard", items = items })
      if result.action then chosen.row_action = { id = result.action.id, row = by_id[result.action.row] } end
    end,
  }
end

function M.draw(env, state)
  local values = input(env, state)
  local cards = view_models.master_cards(values)
  if cards.reference and values.marker_error then cards.reference.note = values.marker_error end
  header.draw(env, state, "Master", cards.all_current and "All Up to Date" or nil)
  local chosen = {}
  local result = env.design_system.components.card_row.draw({
    id = "master-cards",
    cards = {
      {
        options = card.options(cards.reference, "master-reference", "film", "Reference",
          cards.highlight == "reference"),
        render_body = function() card.body(env, "master-reference", cards.reference) end,
      },
      deliveries_entry(env, cards, chosen),
    },
  })
  local reference_action = result.actions["master-reference"]
  local deliveries_action = result.actions["master-deliveries"]
  if reference_action then handle_reference(env, reference_action) end
  if deliveries_action then handle_delivery(env, { id = "add_delivery" }) end
  if chosen.row_action then handle_delivery(env, chosen.row_action) end
end

return M
