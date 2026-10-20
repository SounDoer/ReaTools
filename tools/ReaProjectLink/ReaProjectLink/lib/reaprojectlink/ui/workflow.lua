-- Helpers shared by views. `env` is the table built in ui/app.lua.
local view_models = require("reaprojectlink.ui.view_models")

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
