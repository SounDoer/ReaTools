local view_models = require("reaprojectlink.ui.view_models")
local workflow = require("reaprojectlink.ui.workflow")

local M = {}

local function draw_contents(c, snapshot)
  local lanes = snapshot.lanes or {}
  local markers = snapshot.markers or {}
  local regions = snapshot.regions or {}
  c.section("Contents")
  if c.begin_group("reference-tracks", "Tracks", view_models.count(#lanes, "track"), "neutral", false) then
    for _, lane in ipairs(lanes) do
      c.key_value(lane.displayName, view_models.count(#(lane.items or {}), "item"))
    end
    c.end_group()
  end
  if c.begin_group("reference-markers", "Markers", view_models.count(#markers, "marker"), "neutral", false) then
    for _, marker in ipairs(markers) do
      c.muted(marker.name ~= "" and marker.name or "Unnamed Marker")
    end
    c.end_group()
  end
  if c.begin_group("reference-regions", "Regions", view_models.count(#regions, "region"), "neutral", false) then
    for _, region in ipairs(regions) do
      c.muted(region.name ~= "" and region.name or "Unnamed Region")
    end
    c.end_group()
  end
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
  local review = app.review
  local status = review.status
  local snapshot = status.snapshot or {}
  local back = false
  workflow.draw_notices(env)
  if c.begin_page("reference-update", true) then
    back = c.review_header(string.format("Update Reference to r%d", status.latest_revision),
      string.format("Synchronized r%d", status.synchronized_revision))
    if not status.available then c.notice("reference-media", "blocked", status.video_error) end
    if status.can_shift_entire_project then
      c.section("Decision")
      local label, note = view_models.shift_texts(status.shift_seconds)
      local result = env.design_system.components.checkbox.draw({
        id = "shift-entire-project",
        label = label,
        checked = review.shift_entire_project,
        description = note,
      })
      if result.changed then review.shift_entire_project = result.checked end
    end
    c.key_value("Alignment", status.alignment_mode == "relative" and
      "Relative to Reference Start" or "Mirror Master Timeline")
    draw_contents(c, snapshot)
  end
  local page = c.end_page()

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
  local synchronize = c.footer(page, summary, status.available and "neutral" or "blocked",
    "Synchronize", ready)

  if back then
    app:back()
  elseif synchronize then
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
