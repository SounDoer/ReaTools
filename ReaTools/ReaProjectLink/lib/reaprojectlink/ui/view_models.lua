-- Pure presentation decisions. Nothing here calls ImGui or REAPER.
local M = {}

function M.count(value, noun)
  return string.format("%d %s", value, value == 1 and noun or noun .. "s")
end

function M.project_name(path)
  local name = (path or ""):match("([^/\\]+)$")
  if not name or name == "" then return "Untitled Project" end
  return (name:gsub("%.[Rr][Pp][Pp]$", ""))
end

-- Subscriptions created before the name was stored still carry the package
-- path, whose last directory is the Source project name.
function M.subscription_name(entry)
  if entry.sourceProjectName and entry.sourceProjectName ~= "" then
    return entry.sourceProjectName
  end
  return (entry.pointerPath or ""):match("[/\\]([^/\\]+)[/\\][^/\\]+$") or "Unnamed Source"
end

function M.checked_text(seconds)
  if not seconds then return nil end
  if seconds < 60 then return "Checked just now" end
  if seconds < 3600 then return string.format("Checked %d min ago", seconds // 60) end
  return string.format("Checked %d h ago", seconds // 3600)
end

function M.blocked_summary(count, verb)
  return string.format("Fix %s to %s", M.count(count, "issue"), verb)
end

local SELECTION_ORDER = { "tracks", "markers", "regions" }
local SELECTION_NOUNS = { tracks = "Track", markers = "Marker", regions = "Region" }
local SELECTION_ACTIONS = {
  { id = "register_selected", label = "Register" },
  { id = "unregister_selected", label = "Unregister" },
}

local function join_list(parts)
  if #parts == 1 then return parts[1] end
  return table.concat(parts, ", ", 1, #parts - 1) .. " and " .. parts[#parts]
end

-- "Selected: 2 Tracks, 1 Region" style summary of what's selected in REAPER,
-- read from the `.selected` counts of the shape reference_publish/project_service
-- `selection_counts` return.
function M.selection_text(counts)
  local parts = {}
  for _, key in ipairs(SELECTION_ORDER) do
    local bucket = counts[key]
    local n = bucket and bucket.selected or 0
    if n > 0 then table.insert(parts, M.count(n, SELECTION_NOUNS[key])) end
  end
  if #parts == 0 then return "Nothing selected in REAPER" end
  return "Selected: " .. join_list(parts)
end

local function count_stats(tracks, middle_label, middle, last_label, last)
  local stats = { { label = "Tracks", value = tracks or 0 }, { label = middle_label, value = middle or 0 } }
  if last_label then table.insert(stats, { label = last_label, value = last or 0 }) end
  return stats
end

function M.source_reference(input)
  local check = input.check or { state = "idle" }
  local synchronized = input.synchronized or 0
  local stats, detail
  if synchronized > 0 then
    local counts = input.reference_counts or {}
    stats = count_stats(counts.tracks, "Markers", counts.markers, "Regions", counts.regions)
    detail = "Synchronized r" .. synchronized
  end
  if not input.subscribed then
    return {
      state = "unsubscribed", status = "Not Connected", level = "warning",
      note = "Choose the reference.json the Master Project published.",
      action = { id = "choose_reference", label = "Choose reference.json" },
      attention = true,
    }
  end
  if check.state == "unreachable" then
    return {
      state = "unreachable", status = "Couldn't Reach Shared Storage", level = "blocked",
      status_detail = detail, stats = stats, action = { id = "retry", label = "Retry" }, attention = true,
    }
  end
  if check.state == "invalid" then
    return {
      state = "invalid", status = "Couldn't Read the Reference", level = "blocked", note = check.error,
      status_detail = detail, stats = stats, action = { id = "retry", label = "Retry" }, attention = true,
    }
  end
  if input.media_error then
    return {
      state = "blocked", status = input.media_error, level = "blocked", status_detail = detail, stats = stats,
      action = { id = "review_update", label = "Review Update" }, attention = true,
    }
  end
  if check.state ~= "done" then
    return { state = "checking", status = "Checking...", level = "neutral", status_detail = detail, stats = stats,
      attention = false }
  end
  if check.latest > synchronized then
    return {
      state = "newer", status = string.format("Reference r%d Available", check.latest),
      level = "warning", status_detail = detail, stats = stats,
      action = { id = "review_update", label = "Review Update" }, attention = true,
    }
  end
  return {
    state = "current", status = "Up to Date", level = "ready",
    status_detail = synchronized > 0 and ("Reference r" .. synchronized) or nil, stats = stats,
    attention = false,
  }
end

function M.source_delivery(input, pending_reference)
  local track_count = input.track_count or 0
  local stats = count_stats(track_count, "Items", input.item_count)
  local selection_note = M.selection_text(input.selection_counts or {})
  if track_count == 0 then
    return {
      state = "unconfigured", status = "No Delivery Tracks", level = "warning",
      note = "Select tracks in REAPER first.",
      stats = stats,
      selection_note = selection_note, selection_actions = SELECTION_ACTIONS,
      attention = true,
    }
  end
  local revision = input.delivery_revision or 0
  return {
    state = revision > 0 and "published" or "unpublished",
    status = revision > 0 and ("Last Published r" .. revision) or "Not Published Yet",
    level = revision > 0 and "ready" or "neutral",
    stats = stats,
    note = pending_reference and string.format("Will record Reference r%d", pending_reference) or nil,
    selection_note = selection_note, selection_actions = SELECTION_ACTIONS,
    action = { id = "review_publish", label = "Review and Publish" },
    attention = true,
  }
end

function M.source_cards(input)
  local reference = M.source_reference(input)
  local synchronized = input.synchronized or 0
  local pending = reference.state == "newer" and synchronized > 0 and synchronized or nil
  return {
    reference = reference,
    delivery = M.source_delivery(input, pending),
    highlight = reference.attention and "reference" or "delivery",
  }
end

function M.master_reference(input)
  local track_count = input.track_count or 0
  local marker_count = input.marker_count or 0
  local region_count = input.region_count or 0
  local stats = count_stats(track_count, "Markers", marker_count, "Regions", region_count)
  local selection_note = M.selection_text(input.selection_counts or {})
  if track_count == 0 and marker_count == 0 and region_count == 0 then
    return {
      state = "unregistered", status = "Nothing Registered", level = "warning", stats = stats,
      note = "Select Tracks, Markers, or Regions in REAPER, then register them.",
      selection_note = selection_note, selection_actions = SELECTION_ACTIONS,
      attention = true,
    }
  end
  local revision = input.reference_revision or 0
  if revision == 0 then
    return {
      state = "unpublished", status = "Not Published Yet", level = "warning", stats = stats,
      selection_note = selection_note, selection_actions = SELECTION_ACTIONS,
      action = { id = "review_publish", label = "Review and Publish" }, attention = true,
    }
  end
  local package_check = input.package_check
  if package_check and package_check.state == "missing" then
    return {
      state = "package_missing", status = "Package Missing", level = "blocked", stats = stats,
      note = string.format(
        "Published files for Reference r%d weren't found. Publish again to restore them.", revision
      ),
      selection_note = selection_note, selection_actions = SELECTION_ACTIONS,
      action = { id = "review_publish", label = "Review and Publish" }, attention = true,
    }
  end
  return {
    state = "published", status = "Published r" .. revision, level = "neutral", stats = stats,
    selection_note = selection_note, selection_actions = SELECTION_ACTIONS,
    action = { id = "review_publish", label = "Review and Publish" }, attention = false,
  }
end

function M.delivery_row(row, master_reference_revision)
  local check = row.check or { state = "idle" }
  local accepted = row.accepted or 0
  if check.state == "unreachable" then
    return { state = "unreachable", status = "Couldn't Reach", level = "blocked",
      action = { id = "retry", label = "Retry" }, attention = true }
  end
  if check.state == "invalid" then
    return { state = "invalid", status = "Couldn't Read Delivery", level = "blocked", note = check.error,
      action = { id = "retry", label = "Retry" }, attention = true }
  end
  if check.state ~= "done" then
    return { state = "checking", status = "Checking...", level = "neutral", attention = false }
  end
  if check.latest > accepted then
    return { state = "newer", status = string.format("r%d Available · Have r%d", check.latest, accepted),
      level = "warning", action = { id = "sync", label = "Sync" }, attention = true }
  end
  if (row.unmapped_count or 0) > 0 then
    local n = row.unmapped_count
    return { state = "unmapped", status = string.format("%d %s Not Imported", n, n == 1 and "Lane" or "Lanes"),
      level = "neutral", action = { id = "map_lanes", label = "Map Lanes" }, attention = true }
  end
  if check.reviewed_reference and check.reviewed_reference < master_reference_revision then
    return { state = "older_reference",
      status = string.format("Made Against Reference r%d", check.reviewed_reference),
      level = "warning", attention = false }
  end
  return { state = "current", status = string.format("Up to Date · r%d", accepted),
    level = "ready", attention = false }
end

function M.master_cards(input)
  local reference = M.master_reference(input)
  local rows, row_attention, checking = {}, false, false
  for index, source in ipairs(input.rows or {}) do
    local row = M.delivery_row(source, input.reference_revision or 0)
    row.id, row.name = source.id, source.name
    rows[index] = row
    row_attention = row_attention or row.attention
    checking = checking or row.state == "checking"
  end
  local highlight
  if reference.attention then
    highlight = "reference"
  elseif #rows == 0 or row_attention then
    highlight = "deliveries"
  end
  return {
    reference = reference,
    rows = rows,
    highlight = highlight,
    all_current = highlight == nil and not checking,
    deliveries_empty = {
      status = "No Deliveries Yet", level = "warning",
      note = "Add the delivery.json a Source Project published.",
      action = { id = "add_delivery", label = "Add Delivery" },
    },
  }
end

-- Card footer for the Action Bar: selection actions first, then the card
-- action, which is the view's primary button on the highlighted card.
function M.card_footer(card, highlighted)
  local actions = {}
  for _, action in ipairs(card.selection_actions or {}) do
    table.insert(actions, { id = action.id, label = action.label })
  end
  if card.action then
    table.insert(actions, { id = card.action.id, label = card.action.label,
      variant = highlighted and "primary" or nil })
  end
  if #actions == 0 and not card.selection_note then return nil end
  return { context = card.selection_note, actions = actions }
end

function M.deliveries_status(rows)
  local attention, blocked, checking = 0, false, false
  for _, row in ipairs(rows) do
    if row.attention then
      attention = attention + 1
      blocked = blocked or row.level == "blocked"
    end
    checking = checking or row.state == "checking"
  end
  if attention > 0 then
    return { role = blocked and "blocked" or "warning",
      text = string.format(attention == 1 and "%d Needs Attention" or "%d Need Attention", attention) }
  end
  if checking then return { role = "neutral", text = "Checking..." } end
  return { role = "ready", text = "All Up to Date" }
end

M.REFERENCE_NAME_LIMIT = 5

local NAME_KINDS = {
  { key = "tracks", prefix = "track", group = "Tracks", fallback = "Unnamed Track" },
  { key = "markers", prefix = "marker", group = "Markers", fallback = "Unnamed Marker" },
  { key = "regions", prefix = "region", group = "Regions", fallback = "Unnamed Region" },
}

local function detach_action(kind, entry)
  if kind.key == "tracks" then
    return { id = "detach_track", ref = entry.ref, name = entry.name, kind = "Track" }
  end
  local noun = kind.key == "markers" and "Marker" or "Region"
  return { id = "detach_entry", entry_id = entry.entry_id, kind = noun, name = entry.name }
end

-- List items for the Source Reference names (D093): Tracks, Markers, then
-- Regions, the first REFERENCE_NAME_LIMIT in total unless expanded.
function M.reference_name_list(surface, expanded)
  local items, lookup, total, shown = {}, {}, 0, 0
  for _, kind in ipairs(NAME_KINDS) do total = total + #(surface[kind.key] or {}) end
  local limit = expanded and total or M.REFERENCE_NAME_LIMIT
  for _, kind in ipairs(NAME_KINDS) do
    local grouped = false
    for index, entry in ipairs(surface[kind.key] or {}) do
      if shown >= limit then break end
      if not grouped then
        table.insert(items, { kind = "group", label = kind.group })
        grouped = true
      end
      local id = kind.prefix .. "-" .. index
      local name = entry.name ~= nil and entry.name ~= "" and entry.name or kind.fallback
      table.insert(items, { kind = "row", id = id, title = name, action = { id = "detach", label = "Detach..." } })
      lookup[id] = detach_action(kind, entry)
      shown = shown + 1
    end
  end
  local overflow
  if total > M.REFERENCE_NAME_LIMIT then
    overflow = expanded and { label = string.format("Showing all %d", total), expanded = true }
      or { label = string.format("+ %d more", total - shown), expanded = false }
  end
  return items, overflow, lookup
end

function M.lane_mapping_options(lane)
  local options = {}
  local suggestions = lane.suggestions or {}
  if #suggestions > 0 then
    table.insert(options, { header = "Suggested" })
    for _, suggestion in ipairs(suggestions) do
      table.insert(options, { id = "suggestion", label = suggestion.display_name, track_ref = suggestion.track_ref })
    end
    table.insert(options, { separator = true })
  end
  table.insert(options, { id = "create", label = "New Track" })
  table.insert(options, { id = "selected", label = "Selected Track" })
  table.insert(options, { separator = true })
  table.insert(options, { id = "unmapped", label = "Don't Import" })
  return options
end

function M.mapping_from_option(option, selected_tracks)
  if option.id == "suggestion" then return { kind = "existing", track_ref = option.track_ref } end
  if option.id == "create" then return { kind = "create" } end
  if option.id == "unmapped" then return { kind = "unmapped" } end
  if option.id == "selected" then
    if #selected_tracks ~= 1 then return nil, "Select exactly one track in REAPER first." end
    return { kind = "existing", track_ref = selected_tracks[1] }
  end
  return nil, "Unknown mapping option."
end

function M.lane_mapping_label(mapping, default_kind, track_name)
  local kind = mapping and mapping.kind or default_kind
  if kind == "unmapped" then return "Don't Import" end
  if kind == "existing" then return track_name(mapping.track_ref) end
  return "New Track"
end

function M.mapping_summary(lanes, mappings, default_kind)
  local new_tracks, items = 0, 0
  for _, lane in ipairs(lanes) do
    local kind = mappings[lane.lane_id] and mappings[lane.lane_id].kind or default_kind
    if kind == "create" then new_tracks = new_tracks + 1 end
    if kind ~= "unmapped" then items = items + #lane.clips end
  end
  return M.count(new_tracks, "new track") .. " · " .. M.count(items, "item")
end

function M.with_parent(mappings, parent_track_ref)
  local result = {}
  for lane_id, mapping in pairs(mappings) do
    local copy = {}
    for key, value in pairs(mapping) do copy[key] = value end
    if copy.kind == "create" then copy.parent_track_ref = parent_track_ref end
    result[lane_id] = copy
  end
  return result
end

-- Label and explanation for the whole-project shift (D065); a negative delta
-- means the Reference moved earlier.
function M.shift_texts(seconds)
  local amount = string.format("%.3f s", math.abs(seconds))
  local direction = seconds < 0 and "earlier" or "later"
  local label = string.format("Move All Project Content %s %s", amount,
    seconds < 0 and "Earlier" or "Later")
  local note = string.format(
    "The whole Reference moved %s %s. Move your items, markers, and regions with it to stay in sync.",
    amount, direction)
  return label, note
end

function M.reference_declaration_options(synchronized, last_declared)
  local options = { { id = synchronized, label = string.format("r%d (Synced)", synchronized) } }
  if last_declared and last_declared > 0 and last_declared ~= synchronized then
    table.insert(options, { id = last_declared, label = "r" .. last_declared })
  end
  return options
end

return M
