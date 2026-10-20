local view_models = require("reaprojectlink.ui.view_models")
local workflow = require("reaprojectlink.ui.workflow")

local M = {}

local function draw_contents(env, snapshot)
  local c, disclosure = env.c, env.design_system.components.disclosure
  local lanes = snapshot.lanes or {}
  local markers = snapshot.markers or {}
  local regions = snapshot.regions or {}
  disclosure.draw({ id = "reference-tracks", label = "Tracks", variant = "inset",
    detail = view_models.count(#lanes, "track") }, function()
    for _, lane in ipairs(lanes) do
      c.key_value(lane.displayName, view_models.count(#(lane.items or {}), "item"))
    end
  end)
  disclosure.draw({ id = "reference-markers", label = "Markers", variant = "inset",
    detail = view_models.count(#markers, "marker") }, function()
    for _, marker in ipairs(markers) do
      c.muted(marker.name ~= "" and marker.name or "Unnamed Marker")
    end
  end)
  disclosure.draw({ id = "reference-regions", label = "Regions", variant = "inset",
    detail = view_models.count(#regions, "region") }, function()
    for _, region in ipairs(regions) do
      c.muted(region.name ~= "" and region.name or "Unnamed Region")
    end
  end)
end

-- The full check hashes Reference media, so it only runs when the user opens
-- this Review.
function M.open(env)
  local status, err = env.services.reference_subscription.check(env.adapter, env.fs)
  if not status then
    env.app:notify(err, true)
    return
  end
  env.app.checks.reference = { state = "done", latest = status.latest_revision }
  env.app.media_error = not status.available and status.video_error or nil
  env.app:open_review("reference_update", { status = status, shift_entire_project = false })
end

function M.draw(env)
  local c, app = env.c, env.app
  local components, shell = env.design_system.components, env.design_system.patterns.review_shell
  local review = app.review
  local status = review.status
  local snapshot = status.snapshot or {}

  local pending = status.latest_revision ~= status.synchronized_revision
  local ready = status.available and pending
  local summary
  if not status.available then
    summary = view_models.blocked_summary(1, "synchronize")
  elseif pending then
    summary = string.format("Brings Reference r%d into this project", status.latest_revision)
  else
    summary = "Already up to date"
  end
  workflow.draw_notices(env)
  local flags = workflow.review_flags(shell.draw({
    id = "reference-update",
    header = {
      title = string.format("Update Reference to r%d", status.latest_revision),
      summary = string.format("Synchronized r%d", status.synchronized_revision),
    },
    footer = { summary = summary, role = status.available and "neutral" or "blocked",
      complete_label = "Synchronize", enabled = ready },
    render_body = function()
      if not status.available then
        shell.section({ id = "reference-update-issues", title = "Issues" }, function()
          components.issue_item.draw_list({ id = "reference-update-issues", items = {
            { id = "reference-media", role = "blocked", message = status.video_error },
          } })
        end)
      end
      if status.can_shift_entire_project then
        shell.section({ id = "reference-update-decision", title = "Decision" }, function()
          local label, note = view_models.shift_texts(status.shift_seconds)
          local result = components.checkbox.draw({
            id = "shift-entire-project",
            label = label,
            checked = review.shift_entire_project,
            description = note,
          })
          if result.changed then review.shift_entire_project = result.checked end
        end)
      end
      shell.section({ id = "reference-update-contents", title = "Contents" }, function()
        c.key_value("Alignment", status.alignment_mode == "relative" and
          "Relative to Reference Start" or "Mirror Master Timeline")
        draw_contents(env, snapshot)
      end)
    end,
  }))

  if flags.back then
    app:back()
  elseif flags.complete then
    local result, err = env.services.reference_subscription.synchronize(env.adapter, status, {
      shift_entire_project = review.shift_entire_project,
    })
    if result then
      app.media_error = nil
      app:back()
      app:notify(string.format("Synchronized Reference r%d.", status.latest_revision))
      app:request_check()
    else
      app:notify(err, true)
    end
  end
end

return M
