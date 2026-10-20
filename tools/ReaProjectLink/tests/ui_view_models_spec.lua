local view_models = require("reaprojectlink.ui.view_models")

local function equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

local function source_input(overrides)
  local input = {
    subscribed = true,
    synchronized = 4,
    check = { state = "done", latest = 4 },
    track_count = 3,
    item_count = 18,
    delivery_revision = 12,
    reference_counts = { tracks = 1, markers = 2, regions = 3 },
  }
  for key, value in pairs(overrides or {}) do input[key] = value end
  return input
end

local function master_input(overrides)
  local input = {
    track_count = 1,
    marker_count = 2,
    region_count = 0,
    reference_revision = 8,
    rows = {
      { id = "a", name = "A", accepted = 3, unmapped_count = 0,
        check = { state = "done", latest = 3, reviewed_reference = 8 } },
    },
  }
  for key, value in pairs(overrides or {}) do input[key] = value end
  return input
end

local function assert_stats(stats, expected, label)
  equal(#stats, #expected / 2, label .. " stat count")
  for index = 1, #stats do
    equal(stats[index].label, expected[index * 2 - 1], label .. " stat label " .. index)
    equal(stats[index].value, expected[index * 2], label .. " stat value " .. index)
  end
end

local tests = {}

function tests.formats_project_and_subscription_names()
  equal(view_models.project_name("C:/show/SFX_Main.RPP"), "SFX_Main", "project name")
  equal(view_models.project_name(""), "Untitled Project", "unsaved project")
  equal(view_models.subscription_name({ sourceProjectName = "Dialogue" }), "Dialogue", "stored name")
  equal(view_models.subscription_name({ pointerPath = "C:/dx/_ReaProjectLink/DX/delivery.json" }),
    "DX", "name from package path")
  equal(view_models.subscription_name({}), "Unnamed Source", "no name")
end

function tests.formats_counts_and_check_age()
  equal(view_models.count(1, "item"), "1 item", "singular")
  equal(view_models.count(3, "new track"), "3 new tracks", "plural")
  equal(view_models.checked_text(nil), nil, "never checked")
  equal(view_models.checked_text(20), "Checked just now", "seconds")
  equal(view_models.checked_text(185), "Checked 3 min ago", "minutes")
  equal(view_models.checked_text(7300), "Checked 2 h ago", "hours")
  equal(view_models.blocked_summary(1, "publish"), "Fix 1 issue to publish", "one issue")
  equal(view_models.blocked_summary(2, "import"), "Fix 2 issues to import", "issues")
end

function tests.source_highlights_reference_until_it_is_current()
  local cases = {
    { { subscribed = false }, "unsubscribed", "reference" },
    { { check = { state = "unreachable" } }, "unreachable", "reference" },
    { { check = { state = "invalid", error = "bad" } }, "invalid", "reference" },
    { { media_error = "Media File Not Found" }, "blocked", "reference" },
    { { check = { state = "done", latest = 5 } }, "newer", "reference" },
    { { check = { state = "checking" } }, "checking", "delivery" },
    { {}, "current", "delivery" },
    { { track_count = 0 }, "current", "delivery" },
  }
  for _, case in ipairs(cases) do
    local cards = view_models.source_cards(source_input(case[1]))
    equal(cards.reference.state, case[2], "reference state")
    equal(cards.highlight, case[3], case[2] .. " highlight")
  end
  local no_tracks = view_models.source_cards(source_input({ track_count = 0 }))
  equal(no_tracks.delivery.state, "unconfigured", "delivery unconfigured when current reference")
end

function tests.source_reference_card_text_and_actions()
  local newer = view_models.source_cards(source_input({ check = { state = "done", latest = 5 } })).reference
  equal(newer.status, "Reference r5 Available", "newer status")
  equal(newer.level, "warning", "newer level")
  equal(newer.status_detail, "Synchronized r4", "synchronized revision under the status")
  equal(newer.action.id, "review_update", "newer action")
  local unsubscribed = view_models.source_cards(source_input({ subscribed = false })).reference
  equal(unsubscribed.action.id, "choose_reference", "subscribe action")
  equal(unsubscribed.status, "Not Connected", "unsubscribed status")
  equal(unsubscribed.level, "warning", "unsubscribed level")
  equal(unsubscribed.status_detail, nil, "no revision before subscribing")
  equal(unsubscribed.stats, nil, "no counts before subscribing")
  local unreachable = view_models.source_cards(source_input({ check = { state = "unreachable" } })).reference
  equal(unreachable.status, "Couldn't Reach Shared Storage", "unreachable status")
  equal(unreachable.action.id, "retry", "retry action")
  equal(unreachable.level, "blocked", "unreachable level")
  equal(unreachable.status_detail, "Synchronized r4", "last known revision while unreachable")
  local invalid = view_models.source_cards(source_input({ check = { state = "invalid", error = "bad" } })).reference
  equal(invalid.note, "bad", "invalid detail")
  equal(invalid.status, "Couldn't Read the Reference", "invalid status")
  local blocked = view_models.source_cards(source_input({ media_error = "Media File Not Found" })).reference
  equal(blocked.status, "Media File Not Found", "media status")
  equal(blocked.action.id, "review_update", "media action")
  local checking = view_models.source_cards(source_input({ check = { state = "checking" } })).reference
  equal(checking.status, "Checking...", "checking status")
  equal(checking.action, nil, "no action while checking")
  equal(checking.level, "neutral", "checking level")
  local current = view_models.source_cards(source_input()).reference
  equal(current.status, "Up to Date", "current status")
  equal(current.status_detail, "Reference r4", "current revision")
  assert_stats(current.stats, { "Tracks", 1, "Markers", 2, "Regions", 3 }, "current")
  equal(current.action, nil, "no action when current")
  equal(current.level, "ready", "current level")
  assert_stats(newer.stats, { "Tracks", 1, "Markers", 2, "Regions", 3 }, "newer keeps synchronized counts")
  local pending = view_models.source_cards(source_input({
    synchronized = 0, check = { state = "done", latest = 5 },
  })).reference
  equal(pending.stats, nil, "counts are omitted before the first synchronization")
  equal(pending.status_detail, nil, "no revision before the first synchronization")
end

function tests.source_delivery_card_states()
  local empty = view_models.source_cards(source_input({ track_count = 0, item_count = 0 })).delivery
  equal(empty.status, "No Delivery Tracks", "no tracks")
  equal(empty.action, nil, "no card action when unconfigured")
  assert_stats(empty.stats, { "Tracks", 0, "Items", 0 }, "unconfigured")
  equal(empty.selection_actions[1].id, "register_selected", "register selected action id")
  equal(empty.selection_actions[1].label, "Register", "register label")
  equal(empty.selection_actions[2].id, "unregister_selected", "unregister selected action id")
  equal(empty.selection_actions[2].label, "Unregister", "unregister label")
  equal(empty.selection_note, "Nothing selected in REAPER", "default selection note")
  local never = view_models.source_cards(source_input({ delivery_revision = 0 })).delivery
  equal(never.status, "Not Published Yet", "never published")
  equal(never.level, "neutral", "source not-published level")
  local published = view_models.source_cards(source_input()).delivery
  equal(published.status, "Last Published r12", "published")
  equal(published.level, "ready", "published delivery matches Up to Date")
  assert_stats(published.stats, { "Tracks", 3, "Items", 18 }, "published")
  equal(published.action.id, "review_publish", "publish action")
  equal(published.note, nil, "no pending note")
  local selecting = view_models.source_cards(source_input({
    selection_counts = { tracks = { selected = 2, registered = 1 } },
  })).delivery
  equal(selecting.selection_note, "Selected: 2 Tracks", "delivery selection note")
  local pending = view_models.source_cards(source_input({ check = { state = "done", latest = 5 } })).delivery
  equal(pending.note, "Will record Reference r4", "pending note")
  local unsynchronized = view_models.source_cards(source_input({
    synchronized = 0, check = { state = "done", latest = 5 },
  })).delivery
  equal(unsynchronized.note, nil, "no note without a synchronized revision")
end

function tests.master_highlight_priority()
  equal(view_models.master_cards(master_input({ track_count = 0, marker_count = 0, region_count = 0 })).highlight,
    "reference", "nothing registered")
  equal(view_models.master_cards(master_input({ reference_revision = 0 })).highlight, "reference", "unpublished")
  equal(view_models.master_cards(master_input({ rows = {} })).highlight, "deliveries", "no subscriptions")
  local newer = view_models.master_cards(master_input({ rows = {
    { id = "a", name = "A", accepted = 3, unmapped_count = 0,
      check = { state = "done", latest = 4, reviewed_reference = 8 } },
  } }))
  equal(newer.highlight, "deliveries", "newer delivery")
  local current = view_models.master_cards(master_input())
  equal(current.highlight, nil, "nothing to do")
  equal(current.all_current, true, "all up to date")
  equal(current.rows[1].id, "a", "row id kept")
  equal(current.rows[1].name, "A", "row name kept")
  local checking = view_models.master_cards(master_input({ rows = {
    { id = "a", name = "A", accepted = 3, unmapped_count = 0 },
  } }))
  equal(checking.all_current, false, "checking is not up to date")
  local unmapped = view_models.master_cards(master_input({ rows = {
    { id = "a", name = "A", accepted = 3, unmapped_count = 2,
      check = { state = "done", latest = 3, reviewed_reference = 8 } },
  } }))
  equal(unmapped.highlight, "deliveries", "unmapped delivery")
  local unreachable = view_models.master_cards(master_input({ rows = {
    { id = "a", name = "A", accepted = 3, unmapped_count = 0, check = { state = "unreachable" } },
  } }))
  equal(unreachable.highlight, "deliveries", "unreachable delivery")
  local older_reference = view_models.master_cards(master_input({ rows = {
    { id = "a", name = "A", accepted = 3, unmapped_count = 0,
      check = { state = "done", latest = 3, reviewed_reference = 7 } },
  } }))
  equal(older_reference.highlight, nil, "older reference does not need attention")
  equal(older_reference.all_current, true, "older reference counts as current")
  local no_tracks_no_rows = view_models.master_cards(
    master_input({ track_count = 0, marker_count = 0, region_count = 0, rows = {} }))
  equal(no_tracks_no_rows.highlight, "reference", "reference wins over no subscriptions")
end

local function assert_master_rows(stats, track_count, marker_count, region_count)
  assert_stats(stats, { "Tracks", track_count, "Markers", marker_count, "Regions", region_count }, "master")
end

function tests.master_reference_card_states()
  local unregistered = view_models.master_cards(
    master_input({ track_count = 0, marker_count = 0, region_count = 0 })).reference
  equal(unregistered.status, "Nothing Registered", "nothing registered status")
  equal(unregistered.level, "warning", "nothing registered level")
  equal(unregistered.note, "Select Tracks, Markers, or Regions in REAPER, then register them.",
    "nothing registered note")
  equal(unregistered.action, nil, "nothing registered has no publish action")
  equal(unregistered.attention, true, "nothing registered needs attention")
  assert_master_rows(unregistered.stats, 0, 0, 0)
  equal(unregistered.selection_actions[1].id, "register_selected", "register selected action id")
  equal(unregistered.selection_actions[2].id, "unregister_selected", "unregister selected action id")
  equal(unregistered.selection_note, "Nothing selected in REAPER", "default selection note")

  local unpublished = view_models.master_cards(master_input({ reference_revision = 0 })).reference
  equal(unpublished.status, "Not Published Yet", "unpublished")
  equal(unpublished.action.id, "review_publish", "publish action")
  equal(unpublished.level, "warning", "master not-published level")
  equal(unpublished.attention, true, "unpublished needs attention")
  assert_master_rows(unpublished.stats, 1, 2, 0)

  local published = view_models.master_cards(master_input()).reference
  equal(published.status, "Published r8", "published")
  equal(published.level, "neutral", "published level")
  equal(published.attention, false, "published needs no attention")
  assert_master_rows(published.stats, 1, 2, 0)

  local selecting = view_models.master_cards(master_input({
    selection_counts = {
      tracks = { selected = 2 }, markers = { selected = 0 }, regions = { selected = 1 },
    },
  })).reference
  equal(selecting.selection_note, "Selected: 2 Tracks and 1 Region", "master selection note")

  local empty = view_models.master_cards(master_input({ rows = {} })).deliveries_empty
  equal(empty.action.id, "add_delivery", "add action")
  equal(empty.status, "No Deliveries Yet", "deliveries empty status")
end

function tests.master_reference_package_missing()
  local missing = view_models.master_cards(master_input({
    package_check = { state = "missing" },
  })).reference
  equal(missing.state, "package_missing", "package missing state")
  equal(missing.status, "Package Missing", "package missing status")
  equal(missing.level, "blocked", "package missing level")
  equal(missing.attention, true, "package missing needs attention")
  equal(missing.action.id, "review_publish", "package missing action")
  equal(missing.note, "Published files for Reference r8 weren't found. Publish again to restore them.",
    "package missing note")
  assert_master_rows(missing.stats, 1, 2, 0)
  local highlight = view_models.master_cards(master_input({
    package_check = { state = "missing" },
  })).highlight
  equal(highlight, "reference", "package missing wins highlight")

  local done = view_models.master_cards(master_input({
    package_check = { state = "done" },
  })).reference
  equal(done.state, "published", "package check done keeps Published card")

  local idle = view_models.master_cards(master_input({
    package_check = { state = "idle" },
  })).reference
  equal(idle.state, "published", "package check idle keeps Published card")

  local none = view_models.master_cards(master_input()).reference
  equal(none.state, "published", "no package check keeps Published card")
end

function tests.delivery_row_priority()
  local function row(check, unmapped)
    return view_models.delivery_row({ accepted = 3, unmapped_count = unmapped or 0, check = check }, 8)
  end
  local unreachable = row({ state = "unreachable" }, 2)
  equal(unreachable.state, "unreachable", "unreachable first")
  equal(unreachable.action.id, "retry", "retry action")
  equal(unreachable.status, "Couldn't Reach", "unreachable row status")
  local invalid = row({ state = "invalid", error = "bad" })
  equal(invalid.note, "bad", "invalid detail")
  equal(invalid.status, "Couldn't Read Delivery", "invalid row status")
  local newer = row({ state = "done", latest = 4, reviewed_reference = 7 }, 2)
  equal(newer.state, "newer", "newer before unmapped")
  equal(newer.status, "r4 Available · Have r3", "newer status")
  equal(newer.action.id, "sync", "sync action")
  local unmapped = row({ state = "done", latest = 3, reviewed_reference = 7 }, 2)
  equal(unmapped.state, "unmapped", "unmapped before older reference")
  equal(unmapped.status, "2 Lanes Not Imported", "unmapped status")
  equal(unmapped.action.id, "map_lanes", "map action")
  equal(unmapped.level, "neutral", "unmapped level")
  local older = row({ state = "done", latest = 3, reviewed_reference = 7 })
  equal(older.state, "older_reference", "older reference")
  equal(older.status, "Made Against Reference r7", "older status")
  equal(older.action, nil, "older has no action")
  equal(older.level, "warning", "older reference level")
  local current = row({ state = "done", latest = 3, reviewed_reference = 8 })
  equal(current.status, "Up to Date · r3", "current")
  equal(current.level, "ready", "current row level")
  equal(row(nil).status, "Checking...", "not checked yet")
end

function tests.lane_mapping_options_and_labels()
  local lane = { lane_id = "a", clips = { {}, {} },
    suggestions = { { display_name = "DX Main", track_ref = "track-1" } } }
  local options = view_models.lane_mapping_options(lane)
  equal(options[1].header, "Suggested", "suggestion header")
  equal(options[2].label, "DX Main", "suggestion first")
  local ids = {}
  for _, option in ipairs(options) do
    if option.id then table.insert(ids, option.id) end
  end
  equal(table.concat(ids, ","), "suggestion,create,selected,unmapped", "option order")
  equal(view_models.lane_mapping_options({ suggestions = {} })[1].id, "create", "no header without suggestions")

  local mapping = view_models.mapping_from_option(options[2], {})
  equal(mapping.kind, "existing", "suggestion maps to existing")
  equal(mapping.track_ref, "track-1", "suggested track")
  local none, err = view_models.mapping_from_option({ id = "selected" }, {})
  equal(none, nil, "no selection")
  equal(err, "Select exactly one track in REAPER first.", "selection error")
  equal(view_models.mapping_from_option({ id = "selected" }, { "t" }).track_ref, "t", "selected track")
  equal(view_models.mapping_from_option({ id = "create" }, {}).kind, "create", "create")
  equal(view_models.mapping_from_option({ id = "unmapped" }, {}).kind, "unmapped", "skip")

  equal(view_models.lane_mapping_label(nil, "create", tostring), "New Track", "import default")
  equal(view_models.lane_mapping_label(nil, "unmapped", tostring), "Don't Import", "update default")
  equal(view_models.lane_mapping_label({ kind = "existing", track_ref = "Bus" }, "create", tostring),
    "Bus", "existing track name")
end

function tests.mapping_summary_and_parent()
  local lanes = {
    { lane_id = "a", clips = { {}, {} } },
    { lane_id = "b", clips = { {} } },
    { lane_id = "c", clips = { {} } },
  }
  local mappings = { b = { kind = "existing", track_ref = "t" }, c = { kind = "unmapped" } }
  equal(view_models.mapping_summary(lanes, mappings, "create"), "1 new track · 3 items", "summary")
  local parented = view_models.with_parent({
    a = { kind = "create" },
    b = { kind = "existing", track_ref = "t" },
  }, "folder")
  equal(parented.a.parent_track_ref, "folder", "new track parent")
  equal(parented.b.parent_track_ref, nil, "existing track untouched")
  local suggested_lane = { { lane_id = "a", clips = { {} },
    suggestions = { { display_name = "A", track_ref = "t" } } } }
  equal(view_models.mapping_summary(suggested_lane, {}, "create"), "1 new track · 1 item",
    "suggestions do not preselect the summary")
  equal(view_models.lane_mapping_label(nil, "create", tostring), "New Track",
    "suggestions do not preselect the label")
end

function tests.selection_text_summarizes_the_reaper_selection()
  equal(view_models.selection_text({}), "Nothing selected in REAPER", "nothing selected")
  equal(view_models.selection_text({
    tracks = { selected = 0 }, markers = { selected = 0 }, regions = { selected = 0 },
  }), "Nothing selected in REAPER", "all zero")
  equal(view_models.selection_text({ tracks = { selected = 1 } }), "Selected: 1 Track", "one track")
  equal(view_models.selection_text({ tracks = { selected = 2 }, regions = { selected = 1 } }),
    "Selected: 2 Tracks and 1 Region", "two kinds")
  equal(view_models.selection_text({
    tracks = { selected = 2 }, markers = { selected = 1 }, regions = { selected = 3 },
  }), "Selected: 2 Tracks, 1 Marker and 3 Regions", "three kinds")
end

function tests.reference_declaration_options()
  local options = view_models.reference_declaration_options(5, 4)
  equal(#options, 2, "two choices")
  equal(options[1].id, 5, "synchronized first")
  equal(options[1].label, "r5 (Synced)", "synchronized label")
  equal(options[2].label, "r4", "previous label")
  equal(#view_models.reference_declaration_options(5, 5), 1, "same revision")
  equal(#view_models.reference_declaration_options(5, 0), 1, "no previous declaration")
end

function tests.whole_project_shift_texts_state_the_direction()
  local label, note = view_models.shift_texts(1.5)
  equal(label, "Move All Project Content 1.500 s Later", "later label")
  equal(note, "The whole Reference moved 1.500 s later. Move your items, markers, and regions with it to stay in sync.",
    "later note")
  label, note = view_models.shift_texts(-0.5)
  equal(label, "Move All Project Content 0.500 s Earlier", "earlier label")
  equal(note, "The whole Reference moved 0.500 s earlier. Move your items, markers, and regions with it to stay in sync.",
    "earlier note")
end

function tests.source_delivery_and_master_reference_stats()
  local delivery = view_models.source_cards(source_input({ track_count = 3, item_count = 12 })).delivery
  assert_stats(delivery.stats, { "Tracks", 3, "Items", 12 }, "source delivery")
  local reference = view_models.master_cards(master_input({ track_count = 4, marker_count = 1, region_count = 2 }))
  assert_master_rows(reference.reference.stats, 4, 1, 2)
end

function tests.card_footer_orders_primary_last()
  local card = view_models.master_cards(master_input({
    selection_counts = { tracks = { selected = 2 } },
  })).reference
  local footer = view_models.card_footer(card, true)
  equal(footer.context, "Selected: 2 Tracks", "selection context")
  local ids = {}
  for index, action in ipairs(footer.actions) do ids[index] = action.id end
  equal(table.concat(ids, ","), "register_selected,unregister_selected,review_publish", "action order")
  equal(footer.actions[3].variant, "primary", "card action is primary when highlighted")
  equal(footer.actions[1].variant, nil, "selection actions stay secondary")
  local quiet = view_models.card_footer(card, false)
  for _, action in ipairs(quiet.actions) do equal(action.variant, nil, action.id .. " not primary") end
  equal(view_models.card_footer({ status = "Checking..." }, true), nil, "no footer without actions or context")
end

function tests.deliveries_status_aggregates_rows()
  local function status(levels)
    local rows = {}
    for index, spec in ipairs(levels) do
      rows[index] = { state = spec[1], level = spec[2], attention = spec[3] }
    end
    return view_models.deliveries_status(rows)
  end
  local two = status({ { "newer", "warning", true }, { "unmapped", "neutral", true } })
  equal(two.text, "2 Need Attention", "two need attention")
  equal(two.role, "warning", "warning role")
  local blocked = status({ { "unreachable", "blocked", true }, { "current", "ready", false } })
  equal(blocked.text, "1 Needs Attention", "one needs attention")
  equal(blocked.role, "blocked", "blocked role wins")
  local checking = status({ { "current", "ready", false }, { "checking", "neutral", false } })
  equal(checking.text, "Checking...", "checking")
  equal(checking.role, "neutral", "checking role")
  local current = status({ { "current", "ready", false }, { "older_reference", "warning", false } })
  equal(current.text, "All Up to Date", "all current")
  equal(current.role, "ready", "ready role")
end

function tests.reference_name_list_collapses_after_limit()
  equal(view_models.REFERENCE_NAME_LIMIT, 5, "limit")
  local surface = {
    tracks = { { name = "DX", ref = "t1" }, { name = "", ref = "t2" }, { name = "FX", ref = "t3" }, { name = "MX", ref = "t4" } },
    markers = { { name = "Hit", entry_id = "m1" }, { name = "Cue", entry_id = "m2" } },
    regions = { { name = "Intro", entry_id = "r1" } },
  }
  local items, overflow, lookup = view_models.reference_name_list(surface, false)
  local shape = {}
  for index, item in ipairs(items) do shape[index] = item.kind == "group" and item.label or item.id end
  equal(table.concat(shape, ","), "Tracks,track-1,track-2,track-3,track-4,Markers,marker-1", "collapsed items")
  equal(items[3].title, "Unnamed Track", "fallback name")
  equal(items[2].action.id, "detach", "detach action id")
  equal(items[2].action.label, "Detach...", "detach label")
  equal(overflow.label, "+ 2 more", "collapsed overflow")
  equal(overflow.expanded, false, "collapsed state")
  equal(lookup["track-1"].id, "detach_track", "track lookup")
  equal(lookup["track-1"].ref, "t1", "track ref")
  equal(lookup["marker-1"].id, "detach_entry", "marker lookup")
  equal(lookup["marker-1"].kind, "Marker", "marker kind")

  local all, expanded = view_models.reference_name_list(surface, true)
  local rows = 0
  for _, item in ipairs(all) do if item.kind == "row" then rows = rows + 1 end end
  equal(rows, 7, "all rows when expanded")
  equal(all[#all - 1].label, "Regions", "regions group")
  equal(expanded.label, "Showing all 7", "expanded overflow")
  equal(expanded.expanded, true, "expanded state")

  local _, none = view_models.reference_name_list({ tracks = { { name = "A" } }, markers = {}, regions = {} }, false)
  equal(none, nil, "no overflow within the limit")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
