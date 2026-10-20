local view_models = require("reaprojectlink.ui.view_models")
local workflow = require("reaprojectlink.ui.workflow")

local M = {}

local function build(env, options)
  return env.services.delivery_publish.review(env.adapter, env.fs, options)
end

function M.open(env)
  local options = { publish_anyway = false }
  local review, err = build(env, options)
  if not review then
    env.app:notify(err, true)
    return
  end
  env.app:open_review("delivery_publish", { data = review, options = options })
end

local function refresh(env, options)
  local review, err = build(env, options)
  if review then
    local current = env.app.review
    current.options = options
    current.data = review
  else
    env.app:notify(err, true)
  end
end

local function item_count(data)
  local count = 0
  for _, lane in ipairs(data.lanes) do count = count + #lane.clips end
  return count
end

-- Issue items, plus the Item reference behind each `Select Item` action.
local function issue_items(data, options)
  local items, item_refs = {}, {}
  if data.reference_blocker then
    table.insert(items, { id = "reference-blocker", role = "blocked", message = data.reference_blocker })
  end
  if data.save_as_blocker then
    table.insert(items, { id = "save-as", role = "blocked",
      message = "This project was moved or saved under a new name. Is this the same delivery?",
      actions = { { id = "continue", label = "Continue Existing" }, { id = "new", label = "Start New" } } })
  end
  if data.removed_blocker and not options.allow_removals then
    table.insert(items, { id = "removed", role = "blocked", message = data.removed_blocker,
      actions = { { id = "publish-without", label = "Publish Without Them..." } } })
  elseif data.removed and data.removed.total > 0 then
    table.insert(items, { id = "removed-accepted", role = "warning",
      message = "Removed Lanes won't be part of this Delivery." })
  end
  if data.has_unprocessed_fx and not options.publish_anyway then
    table.insert(items, { id = "unprocessed-fx", role = "warning",
      message = "Track or Take FX were found. Published audio won't include them.",
      actions = { { id = "publish-unprocessed", label = "Publish Unprocessed Media..." } } })
  elseif data.has_unprocessed_fx then
    table.insert(items, { id = "unprocessed-fx-accepted", role = "warning",
      message = "Detected FX won't be included in the published audio." })
  end
  for _, lane in ipairs(data.lanes) do
    if lane.fx_blocked then
      table.insert(items, { id = "lane-fx-" .. lane.lane_id, role = "blocked",
        message = lane.display_name .. " has Track FX." })
    end
    for index, row in ipairs(lane.clips) do
      for blocker_index, blocker in ipairs(row.blockers) do
        local id = string.format("clip-%s-%d-%d", lane.lane_id, index, blocker_index)
        table.insert(items, { id = id, role = "blocked",
          message = string.format("%s: %s", row.display_name or "Unnamed Item", blocker),
          actions = { { id = "select-item", label = "Select Item" } } })
        item_refs[id] = row.clip.item_ref
      end
    end
  end
  return items, item_refs
end

-- Returns true when a decision changed and the Review must be rebuilt.
local function handle_issue(env, action, options, item_refs)
  local c = env.c
  if action.item == "save-as" then
    options.save_as_decision = action.id
    return true
  elseif action.item == "removed" then
    c.request_confirmation({
      id = "publish-delivery-without-removed",
      title = "Publish Without Removed Lanes",
      message = "The Master Project will see them as removed, and registering again gives them new identities.",
      confirm_label = "Publish Without Them",
      danger = true,
    }, function()
      options.allow_removals = true
      refresh(env, options)
    end)
  elseif action.item == "unprocessed-fx" then
    c.request_confirmation({
      id = "publish-unprocessed-media",
      title = "Publish Unprocessed Media",
      message = "Detected Track FX or Take FX will not be included in the published media.",
      confirm_label = "Publish Unprocessed Media",
    }, function()
      options.publish_anyway = true
      refresh(env, options)
    end)
  elseif action.id == "select-item" and item_refs[action.item] then
    env.adapter.select_items({ item_refs[action.item] })
  end
  return false
end

-- Writes the choice directly into the persistent review instead of
-- requesting a refresh, so changing it doesn't rebuild the whole Review
-- (which re-hashes all media). `delivery_publish.publish` reads
-- `review.reviewed_reference_revision` from `review.data`.
local function draw_declaration(env, review)
  local data = review.data
  if data.synchronized_reference_revision == 0 then return end
  local c = env.c
  local choices = view_models.reference_declaration_options(
    data.synchronized_reference_revision, data.last_declared_reference_revision
  )
  if #choices == 1 then
    env.design_system.components.list.draw({ id = "declared-reference", items = {
      { kind = "row", id = "revision", title = "Revision", detail = choices[1].label },
    } })
    return
  end
  local chosen = c.segmented("declared-reference", choices, data.reviewed_reference_revision)
  if chosen ~= data.reviewed_reference_revision then
    review.options.declared_reference_revision = chosen
    data.reviewed_reference_revision = chosen
  end
end

local function draw_details(env, data)
  local c, ImGui, ctx = env.c, env.ImGui, env.ctx
  local adapter = env.design_system.adapter
  for _, lane in ipairs(data.lanes) do
    local blocked = 0
    for _, row in ipairs(lane.clips) do
      if #row.blockers > 0 then blocked = blocked + 1 end
    end
    local detail = view_models.count(#lane.clips, "item")
    if blocked > 0 then detail = blocked .. " blocked · " .. detail end
    env.design_system.components.disclosure.draw({
      id = "lane-" .. lane.lane_id, label = lane.display_name, variant = "inset", detail = detail,
      role = (blocked > 0 or lane.fx_blocked) and "blocked" or nil,
    }, function()
      c.clipped(#lane.clips, function(index)
        local row = lane.clips[index]
        ImGui.TextColored(ctx, #row.blockers > 0 and
          adapter.resolve("component.status.blocked.foreground") or
          adapter.resolve("semantic.color.text.primary"),
          row.display_name or "Unnamed Item")
      end)
    end)
  end
end

function M.draw(env)
  local app = env.app
  local review = app.review
  local data = review.data
  if review.publish_ready then
    review.publish_ready = nil
    local result, err = env.services.delivery_publish.publish(
      data, env.adapter, env.fs, workflow.metadata()
    )
    if result then
      local message, is_error = workflow.publish_message("Delivery", result.delivery_revision, result)
      app:back()
      app:notify(message, is_error)
    else
      review.publishing = nil
      app:notify(err, true)
      workflow.inspect_lock(env, data.package_root)
    end
    return
  end
  local options = {}
  for key, value in pairs(review.options) do options[key] = value end
  local stale = workflow.is_stale(env, data)
  local components, shell = env.design_system.components, env.design_system.patterns.review_shell
  local items = item_count(data)

  local summary, level = string.format("Publishes %s as Delivery r%d",
    view_models.count(items, "item"), data.delivery_revision), "neutral"
  if stale then
    summary = "Refresh the review to continue"
  elseif data.blocker_count > 0 then
    summary, level = view_models.blocked_summary(data.blocker_count, "publish"), "blocked"
  end
  if review.publishing then
    summary, level = "Publishing Delivery...", "neutral"
  end

  local issue_action, item_refs
  workflow.draw_notices(env)
  local result = shell.draw({
    id = "delivery-publish",
    header = {
      title = string.format("Publish Delivery r%d", data.delivery_revision),
      summary = view_models.count(#data.lanes, "track") .. " · " .. view_models.count(items, "item"),
    },
    footer = { summary = summary, role = level, complete_label = review.publishing and "Publishing..." or "Publish",
      enabled = not review.publishing and not stale and data.blocker_count == 0 },
    stale = stale and workflow.STALE_REVIEW or nil,
    render_body = function()
      components.stat_group.draw({ id = "delivery-publish-scope", stats = {
        { label = "Tracks", value = #data.lanes },
        { label = "Items", value = items },
      } })
      local issues
      issues, item_refs = issue_items(data, options)
      if #issues > 0 then
        shell.section({ id = "delivery-publish-issues", title = "Issues" }, function()
          issue_action = components.issue_item.draw_list({ id = "delivery-publish-issues", items = issues }).action
        end)
      end
      if data.synchronized_reference_revision ~= 0 then
        shell.section({ id = "delivery-publish-reference", title = "Checked Against Reference" }, function()
          draw_declaration(env, review)
        end)
      end
      shell.section({ id = "delivery-publish-items", title = "Items" }, function()
        draw_details(env, data)
      end)
    end,
  })
  local flags = workflow.review_flags(result)
  local changed = issue_action and handle_issue(env, issue_action, options, item_refs)

  if flags.back then
    app:back()
  elseif flags.refresh then
    refresh(env, review.options)
  elseif changed then
    refresh(env, options)
  elseif review.publishing then
    review.publish_ready = true
  elseif flags.complete then
    review.publishing = true
  end
end

return M
