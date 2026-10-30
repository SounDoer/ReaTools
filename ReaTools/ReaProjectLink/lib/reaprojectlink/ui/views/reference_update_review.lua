local view_models = require("reaprojectlink.ui.view_models")
local workflow = require("reaprojectlink.ui.workflow")

local M = {}

-- The full check hashes Reference media, so it only runs when the user opens
-- this Review.
function M.open(env)
  workflow.start_check(env, "reference_update", { shift_entire_project = false }, function(fs)
    return env.services.reference_subscription.check(env.adapter, fs)
  end, function(review, status)
    env.app.checks.reference = { state = "done", latest = status.latest_revision }
    env.app.media_error = not status.available and status.video_error or nil
    review.status = status
  end)
end

function M.draw(env)
  local app = env.app
  local components, shell = env.design_system.components, env.design_system.patterns.review_shell
  local review = app.review
  if review.checking then
    workflow.draw_checking(env, "reference-update", "Update Reference", "Synchronize")
    return
  end
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
      summary = (status.synchronized_revision or 0) > 0
        and string.format("Synchronized r%d", status.synchronized_revision) or nil,
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
        components.list.draw({ id = "reference-update-alignment", items = {
          { kind = "row", id = "alignment", title = "Alignment", detail = status.alignment_mode == "relative" and
            "Relative to Reference Start" or "Mirror Master Timeline" },
        } })
        workflow.draw_reference_contents(env, snapshot.lanes or {}, snapshot.markers or {}, snapshot.regions or {})
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
