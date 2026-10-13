local json = require("reaprojectlink.json")
local reference_subscription = require("reaprojectlink.reference_subscription")

local pointer_path = "C:/mix/_ReaProjectLink/CIN_030_MIX/reference.json"
local manifest_path = "C:/mix/_ReaProjectLink/CIN_030_MIX/history/reference-0003.json"
local video_path = "C:/mix/video.mov"
local function v2_snapshot(revision, item_start, reference_start)
  return {
    schemaVersion = 2,
    masterProjectId = "master-1",
    masterProjectName = "CIN_030_MASTER",
    referenceId = "reference-1",
    referenceRevision = revision,
    alignmentMode = "mirror",
    timeline = {
      sampleRate = 48000,
      projectTimecodeOffsetSamples = 0,
      referenceStartSamples = reference_start,
      referenceStartMarkerId = "reference-start-1",
      frameRate = { numerator = 24, denominator = 1, dropFrame = false },
    },
    lanes = {{
      laneId = "reference-lane-1", displayName = "Reference", order = 0,
      items = {{
        itemId = "reference-item-1", displayName = "Reference",
        videoFile = video_path, videoHash = "sha256:video-hash",
        startSamples = item_start, sourceOffsetSamples = 0,
        durationSamples = 144000, playbackRate = 1,
      }},
    }},
    markers = {{
      entryId = "reference-start-1", name = "FFOP", startSamples = reference_start,
      color = 0,
    }},
    regions = {},
  }
end

local pointer = {
  schemaVersion = 2,
  masterProjectId = "master-1",
  referenceId = "reference-1",
  latestReferenceRevision = 3,
  manifest = "history/reference-0003.json",
}
local snapshot = v2_snapshot(3, 96000, 96000)
local files = {
  [pointer_path] = json.encode(pointer),
  [manifest_path] = json.encode(snapshot),
  [video_path] = "video",
}
local fs = {}
function fs.read_file(path) return files[path] end
function fs.hash_file(path) if path == video_path then return "video-hash" end end
function fs.dirname(path) return path:match("^(.*)/[^/]+$") end
function fs.join(...) return table.concat({ ... }, "/"):gsub("/+", "/") end

local values = { project_type = "source", project_token = "source-project-1" }
local events = {}
local adapter = {}
function adapter.get_project_value(key) return values[key] end
function adapter.set_project_value(key, value) values[key] = tostring(value) end
function adapter.begin_undo(label) table.insert(events, "begin:" .. label) end
function adapter.end_undo(label) table.insert(events, "end:" .. label) end
function adapter.mark_project_dirty() table.insert(events, "dirty") end
function adapter.project_sample_rate() return 96000 end
function adapter.project_token() return values.project_token end
function adapter.sync_reference(value)
  table.insert(events, "sync:" .. value.referenceRevision)
  return { item_ref = "reference-item", created = true }
end
function adapter.shift_entire_project(seconds)
  table.insert(events, "shift:" .. tostring(seconds))
  return { shifted = true }
end

local subscribed, subscribe_error = reference_subscription.subscribe(adapter, fs, pointer_path)
assert(subscribed, subscribe_error)
assert(values.reference_manifest_path == pointer_path, "stable pointer path persisted")
assert(values.reference_id == "reference-1", "Reference identity persisted")
assert(values.reference_master_project_id == "master-1", "Master Project identity persisted")
assert(values.synchronized_reference_revision == nil, "subscription does not auto-sync")

local status, status_error = reference_subscription.check(adapter, fs)
assert(status, status_error)
assert(status.latest_revision == 3, "latest revision detected")
assert(status.synchronized_revision == 0, "not yet synchronized")
assert(status.reviewed_revision == 0, "not yet reviewed")
assert(status.available, "external video hash matches")

values.project_token = "source-project-2"
local wrong_project, wrong_project_error = reference_subscription.synchronize(adapter, status)
assert(not wrong_project and wrong_project_error:find("different REAPER project", 1, true),
  "Reference status cannot be applied to another project")
values.project_token = "source-project-1"

local synchronized, sync_error = reference_subscription.synchronize(adapter, status)
assert(synchronized, sync_error)
assert(values.synchronized_reference_revision == "3", "synchronized revision persisted")
assert(values.reference_start_samples == "192000", "Reference Start converted to the Source sample rate")
assert(values.reference_start_sample_rate == "96000", "Reference Start sample rate persisted")
assert(values.reviewed_reference_revision == nil, "sync does not imply review")

local revision_four_path =
  "C:/mix/_ReaProjectLink/CIN_030_MIX/history/reference-0004.json"
local revision_four = v2_snapshot(4, 144000, 144000)
pointer.latestReferenceRevision = 4
pointer.manifest = "history/reference-0004.json"
files[pointer_path] = json.encode(pointer)
files[revision_four_path] = json.encode(revision_four)

snapshot.referenceId = "foreign-reference"
files[manifest_path] = json.encode(snapshot)
local foreign_history, foreign_history_error = reference_subscription.check(adapter, fs)
assert(
  not foreign_history and foreign_history_error:find("Reference history", 1, true),
  "a synchronized history snapshot from another Reference is rejected"
)
snapshot.referenceId = "reference-1"
files[manifest_path] = json.encode(snapshot)

local shifted = assert(reference_subscription.check(adapter, fs))
assert(shifted.can_shift_entire_project, "uniform Reference shift is detected")
assert(math.abs(shifted.shift_seconds - 1) < 0.000001, "uniform shift delta is reported")
assert(reference_subscription.synchronize(adapter, shifted, { shift_entire_project = true }))
assert(events[#events - 3] == "shift:1.0", "explicit full-project shift is applied before sync")

local function publish_test_revision(revision, value)
  local path = string.format(
    "C:/mix/_ReaProjectLink/CIN_030_MIX/history/reference-%04d.json", revision
  )
  pointer.schemaVersion = 2
  pointer.latestReferenceRevision = revision
  pointer.manifest = string.format("history/reference-%04d.json", revision)
  files[pointer_path] = json.encode(pointer)
  files[path] = json.encode(value)
end

publish_test_revision(5, v2_snapshot(5, 144000, 144000))
local stationary = assert(reference_subscription.check(adapter, fs))
assert(not stationary.can_shift_entire_project,
  "an update without a timeline rebase does not offer a full-project shift")
assert(reference_subscription.synchronize(adapter, stationary))

publish_test_revision(6, v2_snapshot(6, 192000, 192000))
local uniform = assert(reference_subscription.check(adapter, fs))
assert(uniform.can_shift_entire_project and math.abs(uniform.shift_seconds - 1) < 0.000001,
  "all stable timeline elements moving together offers a full-project shift")
assert(reference_subscription.synchronize(adapter, uniform))

publish_test_revision(7, v2_snapshot(7, 192000, 240000))
local partial_move = assert(reference_subscription.check(adapter, fs))
assert(not partial_move.can_shift_entire_project,
  "a partial timeline move does not offer a full-project shift")

local function zero_anchor_shift(revision, start)
  local value = v2_snapshot(revision, start, 0)
  value.markers[1].startSamples = start
  value.timeline.referenceStartMarkerId = nil
  return value
end
publish_test_revision(8, zero_anchor_shift(8, 240000))
local zero_anchor = assert(reference_subscription.check(adapter, fs))
assert(zero_anchor.can_shift_entire_project and math.abs(zero_anchor.shift_seconds - 1) < 0.000001,
  "a uniform move is detected when Reference Start stays at project zero")

files[video_path] = "replaced bytes"
function fs.hash_file(path) if path == video_path then return "different-hash" end end
local mismatched = assert(reference_subscription.check(adapter, fs))
assert(not mismatched.available, "same-path replacement detected")
assert(mismatched.video_error:find("content does not match", 1, true),
  "content mismatch explained")

do
  local constants = require("reaprojectlink.constants")
  local values = {
    [constants.PROJECT_KEYS.reference_timeline_entries] = json.encode({
      { entryId = "marker-1", kind = "marker", number = 1 },
      { entryId = "region-1", kind = "region", number = 2 },
      { entryId = "region-2", kind = "region", number = 3 },
    }),
  }
  local counted_adapter = {}
  local managed_item = { item_id = "item-1", reference_id = "reference-1", name = "Picture" }
  local tracks = {
    { lane_id = "lane-1", reference_id = "reference-1", name = "Reference", items = { managed_item } },
    { lane_id = "", name = "Local", items = {} },
  }
  local events = {}
  function counted_adapter.all_tracks() return tracks end
  function counted_adapter.get_track_reference_lane_id(track) return track.lane_id end
  function counted_adapter.set_track_reference_lane_id(track, id) track.lane_id = id end
  function counted_adapter.set_track_reference_id(track, id) track.reference_id = id end
  function counted_adapter.track_name(track) return track.name end
  function counted_adapter.track_items(track) return track.items end
  function counted_adapter.get_item_reference_item_id(item) return item.item_id end
  function counted_adapter.set_item_reference_item_id(item, id) item.item_id = id end
  function counted_adapter.set_item_reference_id(item, id) item.reference_id = id end
  function counted_adapter.get_project_value(key) return values[key] end
  function counted_adapter.set_project_value(key, value) values[key] = value end
  function counted_adapter.timeline_entries()
    return {
      { kind = "marker", number = 1, name = "FFOP" },
      { kind = "region", number = 2, name = "Scene" },
      { kind = "region", number = 3, name = "Cue" },
    }
  end
  function counted_adapter.begin_undo(label) table.insert(events, "begin:" .. label) end
  function counted_adapter.end_undo(label) table.insert(events, "end:" .. label) end
  function counted_adapter.mark_project_dirty() table.insert(events, "dirty") end
  local surface = reference_subscription.local_surface(counted_adapter)
  assert(surface.tracks[1].name == "Reference", "synchronized Track is listed")
  assert(surface.markers[1].name == "FFOP" and surface.regions[2].name == "Cue",
    "synchronized Marker and Region names come from the project")
  local counts = reference_subscription.local_counts(counted_adapter)
  assert(counts.tracks == 1 and counts.markers == 1 and counts.regions == 2,
    "local counts follow synchronized Tracks, Markers, and Regions")

  local detached_marker = assert(reference_subscription.detach_timeline_entry(
    counted_adapter, "marker-1"
  ))
  assert(detached_marker.detached == 1, "detaching a Marker drops it from the sync list")
  local remaining = json.decode(values[constants.PROJECT_KEYS.reference_timeline_entries])
  assert(#remaining == 2 and remaining[1].entryId == "region-1",
    "the Marker stays out of the mapping and the Regions remain")

  local detached_track = assert(reference_subscription.detach_reference_track(
    counted_adapter, tracks[1]
  ))
  assert(detached_track.items == 1, "detaching a Track also detaches its Reference Items")
  assert(tracks[1].lane_id == "" and managed_item.item_id == "",
    "the Track and Item lose their Reference identities")
end

return 12
