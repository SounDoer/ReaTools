-- Helpers shared by views. `env` is the table built in ui/app.lua.
local view_models = require("reaprojectlink.ui.view_models")
local jobs = require("reaprojectlink.jobs")
local hash_prefetch = require("reaprojectlink.hash_prefetch")

local M = {}

function M.metadata()
  local user = os.getenv("USERNAME") or os.getenv("USER") or "unknown"
  local now = os.date("!%Y-%m-%dT%H:%M:%SZ")
  return {
    published_at = now,
    published_by = user,
    lock_metadata = {
      user = user,
      machine = os.getenv("COMPUTERNAME") or "unknown",
      started_at = now,
    },
  }
end

function M.choose_json(reaper_api, title)
  local ok, path = reaper_api.GetUserFileNameForRead("", title, "json")
  return ok and path or nil
end

function M.is_stale(env, data)
  return data.project_change_count ~= nil and
    data.project_change_count ~= env.adapter.project_change_count()
end

-- Shows a toast for a service result. `success` is a string or a function of
-- the result.
function M.report(env, result, err, success)
  if result then
    env.app:notify(type(success) == "function" and success(result) or success)
  else
    env.app:notify(err, true)
  end
  return result
end

-- Like M.report, but silent on success. Used for routine, selection-based
-- operations where a toast would just be noise; errors still notify.
function M.apply(env, result, err)
  if not result then env.app:notify(err, true) end
  return result
end

function M.publish_message(noun, revision, result)
  local message = string.format("Published %s r%d.", noun, revision)
  if result.project_save_error then message = message .. " " .. result.project_save_error end
  if result.lock_release_error then
    message = message .. " Publish lock cleanup failed: " .. result.lock_release_error
  end
  return message, result.project_save_error ~= nil or result.lock_release_error ~= nil
end

local PUBLISH_PHASES = {
  working = "Copying and verifying media",
  cancelling = "Cancelling after the current file",
  finishing = "Finishing",
}

function M.job_message(job)
  return PUBLISH_PHASES[job.phase] or PUBLISH_PHASES.working
end

-- Opens the review of `kind` (or keeps it open) and builds its data in a
-- background check; `build(fs)` is the service's review function.
function M.start_check(env, kind, fields, build, on_result)
  local app = env.app
  if not (app.review and app.review.kind == kind) then app:open_review(kind, fields) end
  local review = app.review
  if review.job then env.jobs:discard() end
  review.checking, review.outcome = true, nil
  review.job = env.jobs:start({
    kind = "check",
    label = "Checking media",
    run = function(job_fs) return hash_prefetch.run(job_fs, build) end,
    on_done = function(job)
      if app.review ~= review then return end
      review.checking, review.job = nil, nil
      env.jobs:dismiss()
      if job.state == "succeeded" then
        on_result(review, job.result)
      else
        if job.state == "failed" then app:notify(job.error, true) end
        if review.data == nil then app:back() end
      end
    end,
  })
end

-- spec: { label, total_bytes, package_root, run(job_fs), on_success(result) }.
-- The open review owns the job; on success it is closed before on_success.
function M.start_publish(env, spec)
  local app, review = env.app, env.app.review
  review.outcome = nil
  review.job = env.jobs:start({
    kind = "publish",
    label = spec.label,
    project = env.adapter.current_project(),
    project_name = env.adapter.project_path():match("([^/\\]+)%.[Rr][Pp][Pp]$") or "project",
    total_bytes = spec.total_bytes,
    run = spec.run,
    on_done = function(job)
      if job.state == "succeeded" then
        if app.review == review then app:back() end
        spec.on_success(job.result)
      elseif app.review == review then
        review.job = nil
        review.outcome = { state = job.state, message = job.error }
        env.jobs:dismiss()
        if job.state == "failed" then M.inspect_lock(env, spec.package_root) end
      end
    end,
  })
end

-- Status block for the review's job or its last outcome. Cancel is handled
-- here; returns the action so views can react to "retry".
function M.draw_job_status(env, id, review)
  local job, outcome = review.job, review.outcome
  if not job and not outcome then return nil end
  local options
  if job and job.kind == "check" then
    options = { label = "Checking media", message = "Hashing media files", state = "running",
      progress = jobs.progress(job), can_cancel = true }
  elseif job then
    options = { label = "Publishing", message = M.job_message(job), state = "running",
      progress = jobs.progress(job), can_cancel = job.phase ~= "finishing",
      detail = "Edits made now will be in the next revision. Cancel or wait for Publish to finish." }
  else
    options = { label = "Publishing", message = outcome.message or "Publish failed.", state = outcome.state,
      can_retry = true }
  end
  options.id = id
  local action = env.design_system.patterns.external_operation_status.draw(options).action
  if action == "cancel" and job.kind == "check" then
    env.jobs:discard()
    review.checking, review.job = nil, nil
    if review.data == nil then env.app:back() end
  elseif action == "cancel" then
    env.jobs:cancel()
  end
  return action
end

-- Review shell shown while a review's first check runs: the status block
-- and a disabled footer.
function M.draw_checking(env, id, title, complete_label)
  local review = env.app.review
  M.draw_notices(env)
  local result = env.design_system.patterns.review_shell.draw({
    id = id,
    header = { title = title },
    footer = { summary = "Checking media...", role = "neutral", complete_label = complete_label, enabled = false },
    render_body = function() M.draw_job_status(env, id, review) end,
  })
  if M.review_flags(result).back then env.app:back() end
end

function M.job_header(review, header)
  if review.job and review.job.kind == "publish" then header.disabled = true end
  return header
end

function M.inspect_lock(env, package_root)
  local info = env.fs.read_lock(package_root)
  env.app.lock = info and { info = info, package_root = package_root } or nil
end

function M.unlock(env)
  local app = env.app
  env.c.request_confirmation({
    id = "unlock-publishing",
    title = "Unlock Publishing",
    message = "Unlock publishing only if no other user or computer is publishing to this package.",
    confirm_label = "Unlock Publishing",
    danger = true,
  }, function()
    local removed, err = env.fs.remove_lock(app.lock.package_root, app.lock.info.token)
    if removed then app.lock = nil else app:notify(err, true) end
  end)
end

function M.choose_reference(env)
  local path = M.choose_json(env.reaper, "Select Published reference.json")
  if not path then return end
  local result, err = env.services.reference_subscription.subscribe(env.adapter, env.fs, path)
  if result then
    env.app:request_check()
  else
    env.app:notify(err, true)
  end
end

local REVIEW_FLAGS = {
  ["review.back_requested"] = "back",
  ["review.complete_requested"] = "complete",
  ["review.refresh_requested"] = "refresh",
}

-- Reads Review Shell events into { back, complete, refresh } booleans.
function M.review_flags(result)
  local flags = { back = false, complete = false, refresh = false }
  for _, event in ipairs(result.events or {}) do
    local flag = REVIEW_FLAGS[event.type]
    if flag then flags[flag] = true end
  end
  return flags
end

local function name_rows(prefix, entries, fallback)
  local rows = {}
  for index, entry in ipairs(entries) do
    rows[index] = { kind = "row", id = prefix .. "-" .. index, title = entry.name ~= "" and entry.name or fallback }
  end
  return rows
end

-- Reference Tracks, Markers, and Regions as inset Disclosures holding Lists.
function M.draw_reference_contents(env, lanes, markers, regions)
  local components = env.design_system.components
  local tracks = {}
  for index, lane in ipairs(lanes) do
    tracks[index] = { kind = "row", id = "track-" .. index, title = lane.displayName,
      detail = view_models.count(#(lane.items or {}), "item") }
  end
  local groups = {
    { id = "tracks", label = "Tracks", detail = view_models.count(#lanes, "track"), variant = "standard", rows = tracks },
    { id = "markers", label = "Markers", detail = view_models.count(#markers, "marker"), variant = "compact",
      rows = name_rows("marker", markers, "Unnamed Marker") },
    { id = "regions", label = "Regions", detail = view_models.count(#regions, "region"), variant = "compact",
      rows = name_rows("region", regions, "Unnamed Region") },
  }
  for _, group in ipairs(groups) do
    components.disclosure.draw({ id = "reference-" .. group.id, label = group.label, variant = "inset",
      detail = group.detail }, function()
      if #group.rows > 0 then
        components.list.draw({ id = "reference-" .. group.id .. "-list", variant = group.variant, items = group.rows })
      end
    end)
  end
end

M.STALE_REVIEW = {
  title = "Review Out of Date",
  message = "The project was edited after this review was made.",
  refresh_label = "Refresh Review",
}

-- Unsaved-project and lock banners. Views call this directly under their
-- header; the toast floats over the window and is drawn by the shell.
function M.draw_notices(env, state)
  local c, app = env.c, env.app
  local drawn = false
  if state and state.path == "" then
    c.notice("unsaved", "blocked", "Save this project in REAPER to use ReaProjectLink.")
    drawn = true
  end
  if app.lock then
    drawn = true
    local lock = app.lock.info
    local text = string.format("Publishing is locked by %s on %s since %s.",
      lock.user or "an unknown user", lock.machine or "an unknown computer",
      lock.started_at or "an unknown time")
    if c.notice("publish-lock", "blocked", text, { "Unlock Publishing..." }) == 1 then
      M.unlock(env)
    end
  end
  if drawn then c.block_gap() end
end

return M
