local view_models = require("reaprojectlink.ui.view_models")
local workflow = require("reaprojectlink.ui.workflow")

local M = {}

local PARENTS = {
  { id = "top", label = "Top Level" },
  { id = "selected", label = "Selected Folder Track" },
}

function M.open_import(env)
  local path = workflow.choose_json(env.reaper, "Select Source delivery.json")
  if not path then return end
  workflow.start_check(env, "delivery_import", { mappings = {}, row_errors = {}, allow_reference = false },
    function(fs) return env.services.delivery_import.review(env.adapter, fs, path) end,
    function(review, data) review.data = data end)
end

-- Load reuses the open Review: its current data stays visible while the new
-- revision is checked, and stays open if that check fails.
function M.open_update(env, source_project_id, target_revision)
  workflow.start_check(env, "delivery_update", {}, function(fs)
    return env.services.delivery_update.review(env.adapter, fs, source_project_id, target_revision)
  end, function(review, data)
    review.data, review.target_input = data, data.target_revision
    review.mappings, review.rebindings, review.row_errors, review.allow_reference = {}, {}, {}, false
  end)
end

-- Returns "Missing track" instead of crashing/misleading when a mapped or
-- re-bound track was deleted after the Review was built.
local function track_name(env, track_ref)
  if env.adapter.valid_track and not env.adapter.valid_track(track_ref) then
    return "Missing Track"
  end
  return env.adapter.track_name(track_ref)
end

local function draw_parent_choice(env, review)
  local c = env.c
  local current = review.parent and "selected" or "top"
  local chosen = env.design_system.components.segmented_control.draw_field({
    id = "parent", label = "New tracks go under", options = PARENTS, value = current,
  }).value
  if chosen ~= current then
    if chosen == "selected" then
      local selected = env.adapter.selected_tracks()
      if #selected == 1 then
        review.parent, review.parent_error = selected[1], nil
      else
        review.parent_error = "Select exactly one folder track in REAPER first."
      end
    elseif chosen == "top" then
      review.parent, review.parent_error = nil, nil
    end
  end
  if review.parent then
    c.small("Under " .. track_name(env, review.parent))
    if c.button("Use Current Selection##parent-repick") then
      local selected = env.adapter.selected_tracks()
      if #selected == 1 then
        review.parent, review.parent_error = selected[1], nil
      else
        review.parent_error = "Select exactly one folder track in REAPER first."
      end
    end
  end
  if review.parent_error then c.notice("parent-error", "warning", review.parent_error) end
end

-- A Lane the user previously chose not to import stays that way until they
-- map it; every other Lane defaults to `default_kind`.
local function lane_default(lane, default_kind)
  return lane.skipped and "unmapped" or default_kind
end

local function draw_mapping_table(env, lanes, review, default_kind)
  local c = env.c
  draw_parent_choice(env, review)
  for index, lane in ipairs(lanes) do
    if index > 1 then c.list_gap() end
    local mapping = review.mappings[lane.lane_id]
    local id = "lane-" .. lane.lane_id
    local chosen = c.mapping_row(id, lane.display_name, view_models.count(#lane.clips, "item"), function()
      return c.dropdown(id,
        view_models.lane_mapping_label(mapping, lane_default(lane, default_kind),
          function(ref) return track_name(env, ref) end),
        view_models.lane_mapping_options(lane))
    end)
    if chosen then
      local next_mapping, err = view_models.mapping_from_option(chosen, env.adapter.selected_tracks())
      if next_mapping then
        review.mappings[lane.lane_id] = next_mapping
        review.row_errors[lane.lane_id] = nil
      else
        review.row_errors[lane.lane_id] = err
      end
    end
    if lane.orphaned then c.small("Its target track was deleted. Map it again to restore its items.") end
    if review.row_errors[lane.lane_id] then
      c.colored(review.row_errors[lane.lane_id],
        env.design_system.adapter.resolve("component.status.warning.foreground"))
    end
  end
end

local function collect_mappings(lanes, review, default_kind)
  local mappings = {}
  for _, lane in ipairs(lanes) do
    mappings[lane.lane_id] = review.mappings[lane.lane_id] or { kind = lane_default(lane, default_kind) }
  end
  return view_models.with_parent(mappings, review.parent)
end

local function reference_issues(items, data, review)
  if data.reference_error then
    table.insert(items, { id = "reference-error", role = "blocked", message = data.reference_error })
  end
  if not data.reference_warning then return end
  if review.allow_reference then
    table.insert(items, { id = "reference-warning", role = "warning",
      message = "Made against a different Reference revision. Continuing anyway." })
  else
    table.insert(items, { id = "reference-warning", role = "warning",
      message = "This delivery was made against a different Reference revision.",
      actions = { { id = "allow", label = "Allow Difference" } } })
  end
end

local function clip_issue(items, id, lane_name, clip)
  if clip.blocked then
    table.insert(items, { id = id, role = "blocked", message = string.format("%s: %s", lane_name, clip.error) })
  end
end

-- Draws the Issues section when there are issues and applies its action.
local function draw_issues(env, id, items, review)
  if #items == 0 then return end
  local shell, issue_item = env.design_system.patterns.review_shell, env.design_system.components.issue_item
  local action
  shell.section({ id = id .. "-issues", title = "Issues" }, function()
    action = issue_item.draw_list({ id = id .. "-issues", items = items }).action
  end)
  if action and action.item == "reference-warning" and action.id == "allow" then review.allow_reference = true end
end

local function draw_import(env, review)
  local app = env.app
  local shell = env.design_system.patterns.review_shell
  local data = review.data

  local ready = data.blocker_count == 0 and (not data.reference_warning or review.allow_reference)
  local summary, level = view_models.mapping_summary(data.lanes, review.mappings, "create"), "neutral"
  if data.blocker_count > 0 then
    summary, level = view_models.blocked_summary(data.blocker_count, "import"), "blocked"
  end

  workflow.draw_notices(env)
  local flags = workflow.review_flags(shell.draw({
    id = "delivery-import",
    header = {
      title = "Add " .. data.snapshot.sourceProjectName,
      summary = string.format("Delivery r%d · made against Reference r%d",
        data.pointer.latestDeliveryRevision, data.snapshot.reference.reviewedRevision),
    },
    footer = { summary = summary, role = level, complete_label = "Import", enabled = ready },
    render_body = function()
      local items = {}
      reference_issues(items, data, review)
      for lane_index, lane in ipairs(data.lanes) do
        for clip_index, clip in ipairs(lane.clips) do
          clip_issue(items, "clip-" .. lane_index .. "-" .. clip_index, lane.display_name, clip)
        end
      end
      draw_issues(env, "delivery-import", items, review)
      shell.section({ id = "delivery-import-lanes", title = "Lanes" }, function()
        draw_mapping_table(env, data.lanes, review, "create")
      end)
    end,
  }))

  if flags.back then
    app:back()
  elseif flags.complete then
    local result, err = env.services.delivery_import.apply(data, env.adapter, {
      mappings = collect_mappings(data.lanes, review, "create"),
      allow_reference_revision_mismatch = review.allow_reference,
    })
    if result then
      app:back()
      app:notify(string.format("Imported %s on %s.",
        view_models.count(result.created_items, "item"),
        view_models.count(result.created_tracks, "new track")))
      app:request_check()
    else
      app:notify(err, true)
    end
  end
end

local function draw_target(env, review)
  local components = env.design_system.components
  local result = components.number_field.draw({
    id = "target-revision",
    label = "Target revision",
    description = string.format("Latest is r%d", review.data.latest_revision),
    value = review.target_input,
    minimum = 1,
    action = { id = "load", label = "Load" },
  })
  if result.changed and result.parse_state == "valid" then review.target_input = result.value end
  return result.action == "load"
end

local function draw_bound_lanes(env, review)
  local c = env.c
  local lanes = review.data.bound_lanes
  for index, lane in ipairs(lanes) do
    if index > 1 then c.list_gap() end
    local rebound = review.rebindings[lane.lane_id]
    local preview = rebound and track_name(env, rebound) or lane.track_name
    local id = "bound-" .. lane.lane_id
    local chosen = c.mapping_row(id, lane.display_name, nil, function()
      return c.dropdown(id, preview, {
        { id = "current", label = "Keep " .. lane.track_name },
        { id = "selected", label = "Selected Track" },
      })
    end)
    if chosen and chosen.id == "current" then
      review.rebindings[lane.lane_id] = nil
      review.row_errors[lane.lane_id] = nil
    elseif chosen then
      local mapping, err = view_models.mapping_from_option(chosen, env.adapter.selected_tracks())
      review.rebindings[lane.lane_id] = mapping and mapping.track_ref or rebound
      review.row_errors[lane.lane_id] = err
    end
    if review.row_errors[lane.lane_id] then
      c.colored(review.row_errors[lane.lane_id],
        env.design_system.adapter.resolve("component.status.warning.foreground"))
    end
  end
end

local function draw_update(env, review)
  local app = env.app
  local shell = env.design_system.patterns.review_shell
  local data = review.data

  local ready = not review.checking and data.blocker_count == 0 and
    (not data.reference_warning or review.allow_reference) and
    (data.pending_count > 0 or next(review.rebindings) ~= nil)
  local summary, level = string.format("Syncs Delivery r%d", data.target_revision), "neutral"
  if data.blocker_count > 0 then
    summary, level = view_models.blocked_summary(data.blocker_count, "sync"), "blocked"
  elseif data.pending_count == 0 and next(review.rebindings) == nil then
    summary = "Nothing to sync"
  end
  local load = false
  workflow.draw_notices(env)
  local flags = workflow.review_flags(shell.draw({
    id = "delivery-update",
    header = {
      title = string.format("Sync %s to r%d", data.target_snapshot.sourceProjectName, data.target_revision),
      summary = string.format("Replaces %s with %s",
        view_models.count(data.replacement_count, "item"),
        view_models.count(data.source_item_count, "item")),
    },
    footer = { summary = summary, role = level, complete_label = "Sync", enabled = ready },
    render_body = function()
      workflow.draw_job_status(env, "delivery-update", review)
      if review.checking then env.ImGui.BeginDisabled(env.ctx, true) end
      local items = {}
      reference_issues(items, data, review)
      for index, clip in ipairs(data.additions) do
        clip_issue(items, "addition-" .. index, clip.lane_display_name, clip)
      end
      for lane_index, lane in ipairs(data.unmapped_lanes) do
        for clip_index, clip in ipairs(lane.clips) do
          clip_issue(items, "unmapped-" .. lane_index .. "-" .. clip_index, lane.display_name, clip)
        end
      end
      draw_issues(env, "delivery-update", items, review)
      shell.section({ id = "delivery-update-revision", title = "Revision" }, function()
        load = draw_target(env, review)
      end)
      if #data.unmapped_lanes > 0 then
        shell.section({ id = "delivery-update-lanes", title = "Lanes" }, function()
          draw_mapping_table(env, data.unmapped_lanes, review, "create")
        end)
      end
      if #data.bound_lanes > 0 then
        shell.section({ id = "delivery-update-mapped", title = "Mapped Lanes" }, function()
          draw_bound_lanes(env, review)
        end)
      end
      if review.checking then env.ImGui.EndDisabled(env.ctx) end
    end,
  }))

  if flags.back then
    app:back()
  elseif load then
    M.open_update(env, data.source_project_id, review.target_input)
  elseif flags.complete then
    local result, err = env.services.delivery_update.apply(data, env.adapter, {
      lane_mappings = collect_mappings(data.unmapped_lanes, review, "create"),
      lane_rebindings = review.rebindings,
      allow_reference_revision_mismatch = review.allow_reference,
    })
    if result then
      app:back()
      app:notify(string.format("Synced Delivery r%d: replaced %s with %s.", data.target_revision,
        view_models.count(result.deleted_items, "item"), view_models.count(result.new_items, "item")))
      app:request_check()
    else
      app:notify(err, true)
    end
  end
end

function M.draw(env)
  local review = env.app.review
  if review.kind == "delivery_import" then
    if review.checking then
      workflow.draw_checking(env, "delivery-import", "Add Delivery", "Import")
    else
      draw_import(env, review)
    end
  elseif review.checking and not review.data then
    workflow.draw_checking(env, "delivery-update", "Sync Delivery", "Sync")
  else
    draw_update(env, review)
  end
end

return M
