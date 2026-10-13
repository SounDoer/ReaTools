local view_models = require("reaprojectlink.ui.view_models")
local workflow = require("reaprojectlink.ui.workflow")
local card = require("reaprojectlink.ui.views.card")
local header = require("reaprojectlink.ui.views.header")
local reference_update_review = require("reaprojectlink.ui.views.reference_update_review")
local delivery_publish_review = require("reaprojectlink.ui.views.delivery_publish_review")

local M = {}

local function input(env, state, surface)
  local lanes = env.services.project_service.delivery_tracks(env.adapter)
  local items = 0
  for _, lane in ipairs(lanes) do items = items + lane.item_count end
  return {
    subscribed = state.reference_manifest_path ~= nil and state.reference_manifest_path ~= "",
    synchronized = state.synchronized_reference_revision,
    reference_counts = {
      tracks = #surface.tracks, markers = #surface.markers, regions = #surface.regions,
    },
    check = env.app.checks.reference,
    media_error = env.app.media_error,
    track_count = #lanes,
    item_count = items,
    delivery_revision = state.delivery_revision,
    selection_counts = env.services.project_service.selection_counts(env.adapter),
  }
end

local function display_name(name, fallback)
  return name ~= nil and name ~= "" and name or fallback
end

local function detach_row(env, id, label)
  local ImGui, ctx, c = env.ImGui, env.ctx, env.c
  ImGui.AlignTextToFramePadding(ctx)
  ImGui.Text(ctx, label)
  c.same_line_right(c.button_width("Detach..."))
  return c.button("Detach...##" .. id)
end

local function draw_entries(env, prefix, entries, fallback, action_for)
  if #entries == 0 then return nil end
  local ImGui, ctx = env.ImGui, env.ctx
  ImGui.Indent(ctx)
  local chosen
  for index, entry in ipairs(entries) do
    if detach_row(env, prefix .. "-" .. index, display_name(entry.name, fallback)) then
      chosen = action_for(entry)
    end
  end
  ImGui.Unindent(ctx)
  return chosen
end

local function draw_under_count(env, surface, row)
  local label = row.label or row[1]
  if label == "Tracks" then
    return draw_entries(env, "track", surface.tracks, "Unnamed Track", function(entry)
      return { id = "detach_track", ref = entry.ref, name = entry.name, kind = "Track" }
    end)
  elseif label == "Markers" then
    return draw_entries(env, "marker", surface.markers, "Unnamed Marker", function(entry)
      return { id = "detach_entry", entry_id = entry.entry_id, kind = "Marker", name = entry.name }
    end)
  elseif label == "Regions" then
    return draw_entries(env, "region", surface.regions, "Unnamed Region", function(entry)
      return { id = "detach_entry", entry_id = entry.entry_id, kind = "Region", name = entry.name }
    end)
  end
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
  local ImGui, ctx, c = env.ImGui, env.ctx, env.c
  local surface = env.services.reference_subscription.local_surface(env.adapter)
  local values = input(env, state, surface)
  local cards = view_models.source_cards(values)
  header.draw(env, state, "Source")
  local width, side_by_side = c.card_width()
  local reference_action = card.draw(env, "source-reference", "film", "Reference", cards.reference,
    cards.highlight == "reference", width, nil, nil, function(row)
      if (values.synchronized or 0) <= 0 then return nil end
      return draw_under_count(env, surface, row)
    end)
  if side_by_side then ImGui.SameLine(ctx, 0, 12) end
  local delivery_action = card.draw(env, "source-delivery", "upload", "Delivery", cards.delivery,
    cards.highlight == "delivery", width, nil)
  local action = reference_action or delivery_action
  if action then handle(env, action) end
end

return M
