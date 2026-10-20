local view_models = require("reaprojectlink.ui.view_models")
local header = require("reaprojectlink.ui.views.header")
local setup = require("reaprojectlink.ui.views.setup")
local source_main = require("reaprojectlink.ui.views.source_main")
local master_main = require("reaprojectlink.ui.views.master_main")
local reference_publish_review = require("reaprojectlink.ui.views.reference_publish_review")
local delivery_publish_review = require("reaprojectlink.ui.views.delivery_publish_review")
local reference_update_review = require("reaprojectlink.ui.views.reference_update_review")
local delivery_sync_review = require("reaprojectlink.ui.views.delivery_sync_review")

local function equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

-- Records the options passed to shared components and returns scripted
-- results. `script` maps a component key to the result its draw returns.
local function fake_view_env(script)
  script = script or {}
  local calls = { notices = {}, block_gaps = 0, order = {} }
  local function recorder(key)
    return {
      draw = function(options, render_body)
        calls[key] = options
        table.insert(calls.order, key)
        if key == "card_row" then
          for _, entry in ipairs(options.cards) do
            if entry.render_body then entry.render_body() end
          end
        elseif render_body then
          render_body()
        end
        return script[key] or { events = {}, actions = {} }
      end,
    }
  end
  local components = {}
  for _, key in ipairs({ "page_header", "card_row", "card", "list", "notice", "stat_group", "issue_item",
    "disclosure", "checkbox", "number_field" }) do
    components[key] = recorder(key)
  end
  components.segmented_control = {
    draw_field = function(options)
      calls.segmented_field = options
      return script.segmented or { changed = false, value = options.value }
    end,
  }
  components.issue_item.draw_list = function(options)
    calls.issue_list = options
    return script.issue_list or { events = {} }
  end
  calls.sections = {}
  local review_shell = {
    draw = function(options)
      calls.review_shell = options
      if not options.stale then options.render_body() end
      return script.review_shell or { events = {} }
    end,
    section = function(options, render)
      table.insert(calls.sections, options.title)
      calls.current_section = options.title
      render()
      calls.current_section = nil
    end,
  }
  local checkbox_draw = components.checkbox.draw
  components.checkbox.draw = function(options)
    calls.checkbox_section = calls.current_section
    return checkbox_draw(options) or {}
  end
  local c = {
    notice = function(id, level, text, actions)
      table.insert(calls.notices, { id = id, level = level, text = text, actions = actions })
      table.insert(calls.order, "notice:" .. id)
      return script.notice and script.notice[id]
    end,
    block_gap = function()
      calls.block_gaps = calls.block_gaps + 1
      table.insert(calls.order, "block_gap")
    end,
    begin_page = function() return true end,
    end_page = function() end,
    small = function(text) table.insert(calls.order, "small:" .. text) end,
    segmented = function(_, _, selected) return selected end,
    clipped = function(count, draw_row) for index = 1, count do draw_row(index) end end,
    colored = function() end,
    list_gap = function() end,
    button = function() return false end,
    dropdown = function(id) return script.dropdown and script.dropdown[id] end,
    mapping_row = function(id, title, detail, draw_control)
      calls.mapping_rows = calls.mapping_rows or {}
      table.insert(calls.mapping_rows, { id = id, title = title, detail = detail })
      return draw_control()
    end,
    request_confirmation = function(options) calls.confirmation = options; return true end,
  }
  local surface = script.surface or { tracks = {}, markers = {}, regions = {} }
  local env = {
    ImGui = { TextColored = function() end }, ctx = {}, c = c,
    design_system = {
      components = components,
      patterns = { review_shell = review_shell },
      adapter = { resolve = function() return 0 end },
    },
    adapter = {
      get_project_value = function() return script.subscriptions end,
      project_change_count = function() return script.change_count or 0 end,
      select_items = function(refs) calls.selected_items = refs end,
      selected_tracks = function() return {} end,
    },
    services = {
      project_service = {
        initialize_source = function() calls.initialized = "source"; return {} end,
        initialize_master = function() calls.initialized = "master"; return {} end,
        delivery_tracks = function() return script.lanes or {} end,
        selection_counts = function() return script.selection or {} end,
      },
      reference_subscription = {
        local_surface = function() return surface end,
      },
      reference_publish = {
        reference_tracks = function() return script.reference_tracks or {} end,
        timeline_entries = function() return {} end,
        selection_counts = function() return {} end,
        review = function(_, _, options) calls.rebuilt = options; return script.rebuilt_review end,
      },
      delivery_update = {
        review = function(_, _, id, target)
          calls.update_opened, calls.update_target = id, target
          return nil, "fake"
        end,
      },
    },
    reaper = {
      GetUserFileNameForRead = function() calls.import_opened = true; return false end,
    },
    app = {
      checks = {
        reference = script.reference_check or { state = "done", latest = 2 },
        deliveries = script.delivery_checks or {},
      },
      review = script.review,
      back = function() calls.back = true end,
      seconds_since_check = function() return 5 end,
      request_check = function() calls.check_requested = true end,
      open_settings = function() calls.settings_opened = true end,
      notify = function() end,
    },
  }
  return env, calls
end

local STATE = { path = "C:/Session/Mix.rpp" }

local tests = {}

function tests.header_uses_page_header()
  local env, calls = fake_view_env({ page_header = { events = {}, action = "check" } })
  header.draw(env, STATE, "Master", "All Up to Date")
  local options = calls.page_header
  equal(options.id, "main-header", "id")
  equal(options.title, "Mix", "title")
  equal(options.badge, "Master", "badge")
  equal(options.meta, "All Up to Date  ·  Checked just now", "meta")
  equal(options.actions[1].id, "check", "check id")
  equal(options.actions[1].label, "Check Now", "check label")
  equal(options.actions[1].icon, "refresh", "check icon")
  equal(options.actions[2].id, "settings", "settings id")
  equal(options.actions[2].icon, "gear", "settings icon")
  equal(options.actions[2].icon_only, true, "settings icon_only")
  equal(calls.check_requested, true, "check action requests a check")

  env, calls = fake_view_env({ page_header = { events = {}, action = "settings" } })
  header.draw(env, STATE, "Source")
  equal(calls.page_header.meta, "Checked just now", "meta without status")
  equal(calls.settings_opened, true, "settings action opens settings")
end

function tests.notices_are_followed_by_block_gap()
  local env, calls = fake_view_env()
  header.draw(env, { path = "" }, "Source")
  equal(#calls.notices, 1, "one notice")
  equal(calls.notices[1].id, "unsaved", "unsaved notice")
  equal(calls.block_gaps, 1, "one block gap")
  equal(calls.order[#calls.order], "block_gap", "gap follows the notice")

  env, calls = fake_view_env()
  header.draw(env, STATE, "Source")
  equal(calls.block_gaps, 0, "no gap without notices")
end

function tests.setup_uses_card_row()
  local env, calls = fake_view_env({
    card_row = { events = {}, actions = { ["setup-master"] = "initialize" } },
  })
  setup.draw(env, STATE)
  equal(calls.page_header.title, "Set Up ReaProjectLink", "page title")
  equal(calls.page_header.summary, "Choose the type for this project.", "page summary")
  local cards = calls.card_row.cards
  equal(#cards, 2, "two cards")
  local source, master = cards[1].options, cards[2].options
  equal(source.id, "setup-source", "source id")
  equal(source.icon, "upload", "source icon")
  equal(source.description, "An editing project that publishes Deliveries to the Master Project.",
    "source description")
  equal(source.footer.actions[1].label, "Initialize Source Project", "source action")
  equal(source.footer.actions[1].variant, "secondary", "source action variant")
  equal(#source.footer.actions, 1, "one source action")
  equal(master.id, "setup-master", "master id")
  equal(master.icon, "download", "master icon")
  equal(master.description,
    "An integration project that publishes the Reference and receives Deliveries.", "master description")
  equal(master.footer.actions[1].label, "Initialize Master Project", "master action")
  equal(master.footer.actions[1].variant, "secondary", "master action variant")
  equal(calls.initialized, "master", "master action initializes the Master Project")
  equal(calls.check_requested, true, "initialization requests a check")
end

local SOURCE_STATE = {
  path = "C:/Session/Dialogue.rpp",
  reference_manifest_path = "C:/Shared/reference.json",
  synchronized_reference_revision = 2,
  delivery_revision = 1,
}

local function named(count, prefix)
  local entries = {}
  for index = 1, count do entries[index] = { name = prefix .. " " .. index, ref = prefix .. index } end
  return entries
end

local function card_options(calls, id)
  for _, entry in ipairs(calls.card_row.cards) do
    if entry.options.id == id then return entry.options end
  end
end

function tests.source_cards_use_card_row()
  local selection = { tracks = { selected = 2 } }
  local env, calls = fake_view_env({ lanes = { { item_count = 3 } }, selection = selection })
  source_main.draw(env, SOURCE_STATE)
  equal(calls.card_row.cards[1].options.id, "source-reference", "first card")
  equal(calls.card_row.cards[2].options.id, "source-delivery", "second card")
  local reference, delivery = card_options(calls, "source-reference"), card_options(calls, "source-delivery")
  equal(reference.variant, nil, "reference not emphasized")
  equal(delivery.variant, "emphasized", "delivery emphasized")
  equal(reference.status.text, "Up to Date", "reference status")
  equal(reference.status.detail, "Reference r2", "reference status detail")
  local actions = delivery.footer.actions
  equal(#actions, 3, "three delivery actions")
  equal(actions[1].label, "Register", "first action")
  equal(actions[2].label, "Unregister", "second action")
  equal(actions[3].label, "Review and Publish", "last action")
  equal(actions[3].variant, "primary", "last action primary")
  equal(delivery.footer.context, view_models.selection_text(selection), "selection context")
end

function tests.source_reference_names_list()
  local surface = { tracks = named(6, "Track"), markers = named(2, "Marker"), regions = {} }
  local env, calls = fake_view_env({ surface = surface, list = { events = {}, overflow_toggled = true } })
  env.app.reference_names_expanded = false
  source_main.draw(env, SOURCE_STATE)
  equal(calls.list.variant, "compact", "compact list")
  local rows = 0
  for _, item in ipairs(calls.list.items) do if item.kind == "row" then rows = rows + 1 end end
  equal(rows, 5, "five rows")
  equal(calls.list.overflow.label, "+ 3 more", "overflow label")
  equal(env.app.reference_names_expanded, true, "overflow toggle expands")

  env, calls = fake_view_env({ surface = surface, list = { events = {}, action = { row = "track-1", id = "detach" } } })
  source_main.draw(env, SOURCE_STATE)
  equal(calls.confirmation.id, "detach-reference-track", "row action requests detach confirmation")
end

function tests.source_reference_without_sync_has_no_list()
  local state = {}
  for key, value in pairs(SOURCE_STATE) do state[key] = value end
  state.synchronized_reference_revision = 0
  local env, calls = fake_view_env({ surface = { tracks = named(2, "Track"), markers = {}, regions = {} } })
  source_main.draw(env, state)
  equal(calls.list, nil, "no list without synchronization")
end

local MASTER_STATE = { path = "C:/Session/Mix.rpp", reference_revision = 1 }
local SUBSCRIPTIONS = '[' ..
  '{"sourceProjectId":"a","sourceProjectName":"Dialogue","acceptedDeliveryRevision":1},' ..
  '{"sourceProjectId":"b","sourceProjectName":"Music","acceptedDeliveryRevision":2},' ..
  '{"sourceProjectId":"c","sourceProjectName":"Foley","acceptedDeliveryRevision":1,' ..
  '"lanes":[{"unmapped":true}]}]'
local DELIVERY_CHECKS = {
  a = { state = "done", latest = 3 },
  b = { state = "done", latest = 2 },
  c = { state = "done", latest = 1 },
}

local function master_env(extra)
  local script = { reference_tracks = { {} }, subscriptions = SUBSCRIPTIONS, delivery_checks = DELIVERY_CHECKS }
  for key, value in pairs(extra or {}) do script[key] = value end
  return fake_view_env(script)
end

function tests.master_deliveries_rows_use_list()
  local env, calls = master_env()
  master_main.draw(env, MASTER_STATE)
  local deliveries = card_options(calls, "master-deliveries")
  equal(deliveries.variant, "emphasized", "deliveries emphasized")
  equal(deliveries.footer, nil, "no footer with rows")
  equal(deliveries.status.text, "2 Need Attention", "aggregate status")
  equal(deliveries.trailing.kind, "icon_button", "trailing kind")
  equal(deliveries.trailing.icon, "plus", "trailing icon")
  local rows = calls.list.items
  equal(calls.list.variant, "standard", "standard list")
  equal(#rows, 3, "three rows")
  equal(rows[1].action.label, "Sync", "first row action")
  equal(rows[1].action.variant, "primary", "first attention row is primary")
  equal(rows[2].action, nil, "current row has no action")
  equal(rows[3].action.label, "Map Lanes", "unmapped row action")
  equal(rows[3].action.variant, nil, "second attention row is not primary")
  equal(rows[1].menu.items[2].id, "remove", "row menu")
  equal(card_options(calls, "master-reference").footer.actions[3].variant, nil,
    "Reference footer has no primary when Deliveries is highlighted")
end

function tests.master_deliveries_actions_route()
  local env, calls = master_env({ card_row = { events = {}, actions = { ["master-deliveries"] = "add" } } })
  master_main.draw(env, MASTER_STATE)
  equal(calls.import_opened, true, "add opens import")

  env, calls = master_env({ list = { events = {}, action = { row = "a", id = "sync" } } })
  master_main.draw(env, MASTER_STATE)
  equal(calls.update_opened, "a", "sync opens update for the row")

  env, calls = master_env({ list = { events = {}, action = { row = "b", id = "remove" } } })
  master_main.draw(env, MASTER_STATE)
  equal(calls.confirmation.id, "remove-subscription", "remove requests confirmation")
end

function tests.master_deliveries_empty_state()
  local env, calls = master_env({ subscriptions = "" })
  master_main.draw(env, MASTER_STATE)
  equal(calls.list, nil, "no list without rows")
  local deliveries = card_options(calls, "master-deliveries")
  equal(deliveries.status.text, "No Deliveries Yet", "empty status")
  equal(deliveries.footer.actions[1].label, "Add Delivery", "empty action")
  equal(deliveries.footer.actions[1].variant, "primary", "empty action primary when highlighted")
end

local function reference_publish_data(overrides)
  local data = { reference_revision = 2, base_revision = 1, lanes = {}, markers = {}, regions = {},
    blockers = {}, blocker_count = 0 }
  for key, value in pairs(overrides or {}) do data[key] = value end
  return data
end

local function delivery_publish_data(overrides)
  local data = { delivery_revision = 3, lanes = {}, blocker_count = 0, synchronized_reference_revision = 0 }
  for key, value in pairs(overrides or {}) do data[key] = value end
  return data
end

local function has(list, value)
  for _, entry in ipairs(list) do if entry == value then return true end end
  return false
end

function tests.reference_publish_issues_route_by_id()
  local data = reference_publish_data({ save_as_blocker = "moved", blockers = { "moved" }, blocker_count = 1 })
  local env, calls = fake_view_env({
    review = { data = data, options = {} },
    issue_list = { events = {}, action = { item = "save-as", id = "new" } },
    rebuilt_review = data,
  })
  reference_publish_review.draw(env)
  equal(calls.issue_list.items[1].id, "save-as", "save-as issue")
  equal(calls.issue_list.items[1].role, "blocked", "save-as role")
  equal(#calls.issue_list.items, 1, "the save-as blocker is not repeated")
  equal(calls.rebuilt.save_as_decision, "new", "decision rebuilds the review")
  equal(has(calls.sections, "Issues"), true, "Issues section")

  env, calls = fake_view_env({
    review = { data = reference_publish_data({ unchanged = true, unchanged_blocker = true }), options = {} },
    issue_list = { events = {}, action = { item = "unchanged", id = "publish-anyway" } },
  })
  reference_publish_review.draw(env)
  equal(calls.confirmation.id, "publish-unchanged-reference", "publish anyway confirmation")
end

function tests.publish_issue_actions_request_confirmations()
  local data = reference_publish_data({ save_as_blocker = "moved", blockers = { "moved" }, blocker_count = 1 })
  local env, calls = fake_view_env({
    review = { data = data, options = {} },
    issue_list = { events = {}, action = { item = "save-as", id = "continue" } },
    rebuilt_review = data,
  })
  reference_publish_review.draw(env)
  equal(calls.rebuilt.save_as_decision, "continue", "continue rebuilds the review")

  for _, case in ipairs({
    { view = reference_publish_review, data = reference_publish_data({ removed_blocker = "Removed" }),
      item = "removed", action = "publish-without", confirmation = "publish-reference-without-removed" },
    { view = delivery_publish_review, data = delivery_publish_data({ removed_blocker = "Removed" }),
      item = "removed", action = "publish-without", confirmation = "publish-delivery-without-removed" },
    { view = delivery_publish_review, data = delivery_publish_data({ has_unprocessed_fx = true }),
      item = "unprocessed-fx", action = "publish-unprocessed", confirmation = "publish-unprocessed-media" },
  }) do
    env, calls = fake_view_env({
      review = { data = case.data, options = {} },
      issue_list = { events = {}, action = { item = case.item, id = case.action } },
    })
    case.view.draw(env)
    equal(calls.confirmation.id, case.confirmation, case.item .. " confirmation")
  end
end

function tests.delivery_publish_running_footer()
  local env, calls = fake_view_env({ review = { data = delivery_publish_data(), options = {}, publishing = true } })
  delivery_publish_review.draw(env)
  local footer = calls.review_shell.footer
  equal(footer.complete_label, "Publishing...", "running label")
  equal(footer.enabled, false, "footer disabled while publishing")
  equal(footer.summary, "Publishing Delivery...", "running summary")
  equal(env.app.review.publish_ready, true, "publish handshake continues")
end

function tests.delivery_publish_select_item()
  local lane = { lane_id = "l1", display_name = "Dialogue", clips = {
    { display_name = "Line 1", blockers = { "Offline media" }, clip = { item_ref = "item-1" } },
  } }
  local env, calls = fake_view_env({
    review = { data = delivery_publish_data({ lanes = { lane }, blocker_count = 1 }), options = {} },
    issue_list = { events = {}, action = { item = "clip-l1-1-1", id = "select-item" } },
  })
  delivery_publish_review.draw(env)
  equal(calls.selected_items[1], "item-1", "select item")
  equal(calls.disclosure.variant, "inset", "lane disclosure is inset")
  equal(calls.disclosure.role, "blocked", "blocked lane disclosure")
end

function tests.reference_update_shift_decision()
  local status = { latest_revision = 3, synchronized_revision = 2, available = true,
    can_shift_entire_project = true, shift_seconds = 2, snapshot = {}, alignment_mode = "mirror" }
  local env, calls = fake_view_env({ review = { status = status, shift_entire_project = false } })
  reference_update_review.draw(env)
  equal(calls.checkbox_section, "Decision", "checkbox inside Decision section")
  equal(calls.review_shell.footer.complete_label, "Synchronize", "footer label")
  equal(calls.review_shell.footer.enabled, true, "footer enabled")
end

function tests.stale_review_passes_stale()
  local data = reference_publish_data({ project_change_count = 5 })
  local env, calls = fake_view_env({
    review = { data = data, options = {} }, change_count = 6, rebuilt_review = data,
    review_shell = { events = { { type = "review.refresh_requested" } } },
  })
  reference_publish_review.draw(env)
  equal(calls.review_shell.stale.refresh_label, "Refresh Review", "stale state")
  equal(calls.rebuilt ~= nil, true, "refresh rebuilds the review")
end

local function import_review(overrides)
  local data = {
    snapshot = { sourceProjectName = "Dialogue", reference = { reviewedRevision = 1 } },
    pointer = { latestDeliveryRevision = 2 },
    lanes = {}, blocker_count = 0,
  }
  for key, value in pairs(overrides or {}) do data[key] = value end
  return { kind = "delivery_import", data = data, mappings = {}, row_errors = {}, allow_reference = false }
end

function tests.import_reference_warning_allows_difference()
  local review = import_review({ reference_warning = true })
  local env, calls = fake_view_env({
    review = review,
    issue_list = { events = {}, action = { item = "reference-warning", id = "allow" } },
  })
  delivery_sync_review.draw(env)
  local item = calls.issue_list.items[1]
  equal(item.id, "reference-warning", "reference warning issue")
  equal(item.actions[1].id, "allow", "allow action id")
  equal(item.actions[1].label, "Allow Difference", "allow action label")
  equal(review.allow_reference, true, "allow sets the review flag")
end

function tests.mapping_row_routes_dropdown_choice()
  local review = import_review({ lanes = { { lane_id = "l1", display_name = "Dialogue", clips = { {}, {} } } } })
  local env, calls = fake_view_env({ review = review, dropdown = { ["lane-l1"] = { id = "unmapped" } } })
  delivery_sync_review.draw(env)
  equal(calls.mapping_rows[1].id, "lane-l1", "mapping row id")
  equal(calls.mapping_rows[1].title, "Dialogue", "mapping row title")
  equal(review.mappings.l1.kind, "unmapped", "dropdown choice maps the lane")
  equal(calls.segmented_field.label, "New tracks go under", "parent choice field")
end

function tests.update_load_reopens_review()
  local review = {
    kind = "delivery_update", mappings = {}, rebindings = {}, row_errors = {}, allow_reference = false,
    target_input = 2,
    data = {
      target_snapshot = { sourceProjectName = "Dialogue" }, target_revision = 3, latest_revision = 4,
      replacement_count = 1, source_item_count = 1, additions = {}, unmapped_lanes = {}, bound_lanes = {},
      blocker_count = 0, pending_count = 1, source_project_id = "a",
    },
  }
  local env, calls = fake_view_env({ review = review, number_field = { events = {}, action = "load" } })
  delivery_sync_review.draw(env)
  equal(calls.number_field.description, "Latest is r4", "load context")
  equal(calls.number_field.action.label, "Load", "load action")
  equal(calls.update_opened, "a", "load reopens the update review")
  equal(calls.update_target, 2, "load uses the typed target")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
