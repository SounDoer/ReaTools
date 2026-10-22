local view_models = require("reaprojectlink.ui.view_models")
local workflow = require("reaprojectlink.ui.workflow")

local M = {}

local function refresh(env, options)
  workflow.start_check(env, "reference_publish", { options = options }, function(fs)
    return env.services.reference_publish.review(env.adapter, fs, options)
  end, function(review, data)
    review.options = options
    review.data = data
  end)
end

function M.open(env)
  refresh(env, { publish_anyway = false })
end

local function publish(env, data)
  local app = env.app
  workflow.start_publish(env, {
    label = "Publishing",
    package_root = data.package_root,
    run = function(job_fs)
      return env.services.reference_publish.publish(data, env.adapter, job_fs, workflow.metadata())
    end,
    on_success = function(result)
      app:notify(workflow.publish_message("Reference", result.reference_revision, result))
      app:request_check()
    end,
  })
end

local function issue_items(data, options)
  local items = {}
  if data.save_as_blocker then
    table.insert(items, { id = "save-as", role = "blocked",
      message = "This project was moved or saved under a new name. Is this the same Reference?",
      actions = { { id = "continue", label = "Continue Existing" }, { id = "new", label = "Start New" } } })
  end
  if data.removed_blocker and not options.allow_removals then
    table.insert(items, { id = "removed", role = "blocked", message = data.removed_blocker,
      actions = { { id = "publish-without", label = "Publish Without Them..." } } })
  elseif data.removed and data.removed.total > 0 then
    table.insert(items, { id = "removed-accepted", role = "warning",
      message = "Removed content won't be part of this Reference." })
  end
  for index, blocker in ipairs(data.blockers or {}) do
    if blocker ~= data.save_as_blocker and blocker ~= data.removed_blocker then
      table.insert(items, { id = "blocker-" .. index, role = "blocked", message = blocker })
    end
  end
  if data.unchanged and not options.publish_anyway then
    table.insert(items, { id = "unchanged", role = "warning",
      message = string.format("This Reference is identical to Reference r%d.", data.base_revision),
      actions = { { id = "publish-anyway", label = "Publish Anyway..." } } })
  end
  return items
end

-- Returns true when a decision changed and the Review must be rebuilt.
local function handle_issue(env, action, options)
  local c = env.c
  if action.item == "save-as" then
    options.save_as_decision = action.id
    return true
  elseif action.item == "removed" then
    c.request_confirmation({
      id = "publish-reference-without-removed",
      title = "Publish Without Removed Content",
      message = "Source Projects will see them as removed, and registering again gives them new identities.",
      confirm_label = "Publish Without Them",
      danger = true,
    }, function()
      options.allow_removals = true
      refresh(env, options)
    end)
  elseif action.item == "unchanged" then
    c.request_confirmation({
      id = "publish-unchanged-reference",
      title = "Publish Unchanged Reference",
      message = "Publish a new unchanged Reference revision? Source projects will still need to synchronize it.",
      confirm_label = "Publish New Revision",
    }, function()
      options.publish_anyway = true
      refresh(env, options)
    end)
  end
  return false
end

function M.draw(env)
  local app = env.app
  local components, shell = env.design_system.components, env.design_system.patterns.review_shell
  local review = app.review
  local data = review.data
  if review.checking then
    workflow.draw_notices(env)
    local result = shell.draw({
      id = "reference-publish",
      header = { title = "Publish Reference" },
      footer = { summary = "Checking media...", role = "neutral", complete_label = "Publish", enabled = false },
      render_body = function() workflow.draw_job_status(env, "reference-publish", review) end,
    })
    if workflow.review_flags(result).back then app:back() end
    return
  end
  local options = {}
  for key, value in pairs(review.options) do options[key] = value end
  local publishing = review.job ~= nil
  local stale = not publishing and workflow.is_stale(env, data)

  local issues = data.blocker_count + (data.unchanged_blocker and 1 or 0)
  local summary, level = string.format("Publishes Reference r%d", data.reference_revision), "neutral"
  if stale then
    summary = "Refresh the review to continue"
  elseif issues > 0 then
    summary, level = view_models.blocked_summary(issues, "publish"), "blocked"
  end
  if publishing then
    summary, level = "Publishing Reference...", "neutral"
  end

  local issue_action, status_action
  workflow.draw_notices(env)
  local result = shell.draw({
    id = "reference-publish",
    header = workflow.job_header(review, {
      title = string.format("Publish Reference r%d", data.reference_revision),
      summary = view_models.count(#data.lanes, "track") .. " · " ..
        view_models.count(#data.markers + #data.regions, "marker"),
    }),
    footer = { summary = summary, role = level, complete_label = publishing and "Publishing..." or "Publish",
      enabled = not publishing and not stale and issues == 0 },
    stale = stale and workflow.STALE_REVIEW or nil,
    render_body = function()
      status_action = workflow.draw_job_status(env, "reference-publish", review)
      if publishing then env.ImGui.BeginDisabled(env.ctx, true) end
      components.stat_group.draw({ id = "reference-publish-scope", stats = {
        { label = "Tracks", value = #data.lanes },
        { label = "Markers", value = #data.markers },
        { label = "Regions", value = #data.regions },
      } })
      local items = issue_items(data, options)
      if #items > 0 then
        shell.section({ id = "reference-publish-issues", title = "Issues" }, function()
          issue_action = components.issue_item.draw_list({ id = "reference-publish-issues", items = items }).action
        end)
      end
      shell.section({ id = "reference-publish-contents", title = "Contents" }, function()
        workflow.draw_reference_contents(env, data.lanes, data.markers, data.regions)
      end)
      if publishing then env.ImGui.EndDisabled(env.ctx) end
    end,
  })
  local flags = workflow.review_flags(result)
  local changed = issue_action and handle_issue(env, issue_action, options)

  if flags.back then
    app:back()
  elseif flags.refresh or status_action == "retry" then
    refresh(env, review.options)
  elseif changed then
    refresh(env, options)
  elseif flags.complete then
    publish(env, data)
  end
end

return M
