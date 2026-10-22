-- One UI frame is rendered per scenario (see tests/run_ui_smoke.lua). Review
-- fixtures contain only the fields the views read; `fields` builds a fresh
-- table per scenario because views mutate Review state.

-- A publishable first Delivery Publish Review plus job state fields.
local function delivery_publish_with(extra)
  return {
    kind = "delivery_publish",
    fields = function()
      local fields = {
        options = {},
        data = {
          delivery_revision = 1, blocker_count = 0, has_unprocessed_fx = false,
          synchronized_reference_revision = 5, last_declared_reference_revision = 0,
          reviewed_reference_revision = 5, package_root = "C:/smoke",
          lanes = {
            { lane_id = "lane-1", display_name = "SFX_Impacts", clips = {
              { display_name = "Hit_01", blockers = {}, clip = {} },
            } },
          },
        },
      }
      for key, value in pairs(extra) do fields[key] = value end
      return fields
    end,
  }
end

local reviews = {
  reference_update = {
    kind = "reference_update",
    fields = function()
      return {
        shift_entire_project = false,
        status = {
          latest_revision = 5, synchronized_revision = 4, available = false,
          video_error = "Media File Not Found", can_shift_entire_project = true,
          shift_seconds = 1.5, alignment_mode = "mirror",
          snapshot = {
            lanes = { { displayName = "Picture", items = { {} } } },
            markers = { { name = "FFOP" } },
            regions = { { name = "Scene" } },
          },
        },
      }
    end,
  },
  delivery_publish = {
    kind = "delivery_publish",
    fields = function()
      return {
        options = {},
        data = {
          delivery_revision = 13, blocker_count = 2, has_unprocessed_fx = true,
          synchronized_reference_revision = 5, last_declared_reference_revision = 4,
          reviewed_reference_revision = 5, save_as_blocker = "moved", package_root = "C:/smoke",
          lanes = {
            { lane_id = "lane-1", display_name = "SFX_Impacts", fx_blocked = true, clips = {
              { display_name = "Whoosh_03", status = "Blocked", blockers = { "Media File Not Found" }, clip = {} },
              { display_name = "Hit_01", status = "Included", blockers = {}, clip = {} },
            } },
          },
        },
      }
    end,
  },
  delivery_publish_first = {
    kind = "delivery_publish",
    fields = function()
      return {
        options = {},
        data = {
          delivery_revision = 1, blocker_count = 0, has_unprocessed_fx = false,
          synchronized_reference_revision = 5, last_declared_reference_revision = 0,
          reviewed_reference_revision = 5, package_root = "C:/smoke",
          lanes = {
            { lane_id = "lane-1", display_name = "SFX_Impacts", clips = {
              { display_name = "Hit_01", blockers = {}, clip = {} },
            } },
          },
        },
      }
    end,
  },
  delivery_publish_same_reference = {
    kind = "delivery_publish",
    fields = function()
      return {
        options = {},
        data = {
          delivery_revision = 14, blocker_count = 0, has_unprocessed_fx = false,
          synchronized_reference_revision = 5, last_declared_reference_revision = 5,
          reviewed_reference_revision = 5, package_root = "C:/smoke",
          lanes = {
            { lane_id = "lane-1", display_name = "SFX_Impacts", clips = {
              { display_name = "Hit_01", blockers = {}, clip = {} },
            } },
          },
        },
      }
    end,
  },
  delivery_publish_checking = {
    kind = "delivery_publish",
    fields = function()
      return { options = {}, checking = true, job = { kind = "check", done_bytes = 40, total_bytes = 100 } }
    end,
  },
  delivery_publish_running = delivery_publish_with({
    job = { kind = "publish", phase = "working", done_bytes = 40, total_bytes = 100 },
  }),
  delivery_publish_cancelling = delivery_publish_with({
    job = { kind = "publish", phase = "cancelling", done_bytes = 40, total_bytes = 100 },
  }),
  delivery_publish_failed = delivery_publish_with({
    outcome = { state = "failed", message = "Could not copy Hit_01.wav: the network path was not found." },
  }),
  reference_publish = {
    kind = "reference_publish",
    fields = function()
      return {
        options = {},
        data = {
          reference_revision = 9, base_revision = 8, blocker_count = 1,
          blockers = { "Reference video is missing: C:/smoke/picture.mov" },
          unchanged = true, unchanged_blocker = "identical", package_root = "C:/smoke",
          lanes = { { displayName = "Picture", items = { {} } } },
          markers = { { name = "FFOP" } }, regions = { { name = "" } },
        },
      }
    end,
  },
  reference_publish_checking = {
    kind = "reference_publish",
    fields = function()
      return { options = {}, checking = true, job = { kind = "check", done_bytes = 0, total_bytes = 100 } }
    end,
  },
  reference_publish_running = {
    kind = "reference_publish",
    fields = function()
      return {
        options = {},
        job = { kind = "publish", phase = "working", done_bytes = 0 },
        data = {
          reference_revision = 9, base_revision = 8, blocker_count = 0, blockers = {}, package_root = "C:/smoke",
          lanes = { { displayName = "Picture", items = { {} } } },
          markers = { { name = "FFOP" } }, regions = {},
        },
      }
    end,
  },
  delivery_import = {
    kind = "delivery_import",
    fields = function()
      return {
        mappings = {}, row_errors = {}, allow_reference = false,
        data = {
          pointer = { latestDeliveryRevision = 15 },
          snapshot = { sourceProjectName = "Dialogue", reference = { reviewedRevision = 8 } },
          blocker_count = 1, reference_warning = true,
          lanes = {
            { lane_id = "a", display_name = "DX_Main", clips = { {}, { blocked = true, error = "Managed WAV hash mismatch." } },
              suggestions = { { display_name = "DX Main", track_ref = false } } },
            { lane_id = "b", display_name = "DX_Walla", clips = { {} }, suggestions = {} },
          },
        },
      }
    end,
  },
  delivery_update = {
    kind = "delivery_update",
    fields = function()
      return {
        mappings = {}, rebindings = {}, row_errors = {}, allow_reference = false, target_input = 15,
        data = {
          source_project_id = "source-1", target_revision = 15, latest_revision = 15,
          target_snapshot = { sourceProjectName = "Dialogue" },
          replacement_count = 12, source_item_count = 14, pending_count = 26,
          blocker_count = 0, reference_warning = false, additions = {},
          unmapped_lanes = {
            { lane_id = "c", display_name = "DX_Radio", orphaned = true, clips = { {} }, suggestions = {} },
            { lane_id = "d", display_name = "DX_Alt", skipped = true, clips = { {} }, suggestions = {} },
          },
          bound_lanes = { { lane_id = "a", display_name = "DX_Main", track_name = "DX Main" } },
        },
      }
    end,
  },
}

-- Populated main views: Delivery footer with three actions, the Reference
-- name List with overflow, and Delivery rows in each check state.
local populated_source = {
  project_values = {
    reference_manifest_path = "C:/smoke/reference.json",
    synchronized_reference_revision = "5",
    delivery_revision = "12",
  },
  services = {
    reference_subscription = {
      peek = function() return { latest_revision = 6 } end,
      local_surface = function()
        return {
          tracks = { { name = "Picture", ref = {} }, { name = "Dialogue Guide", ref = {} } },
          markers = { { name = "FFOP", entry_id = "m1" }, { name = "LFOA", entry_id = "m2" } },
          regions = { { name = "Scene 1", entry_id = "r1" }, { name = "Scene 2", entry_id = "r2" },
            { name = "", entry_id = "r3" } },
        }
      end,
    },
    project_service = {
      delivery_tracks = function()
        return { { lane_id = "a", display_name = "SFX_Impacts", item_count = 4 },
          { lane_id = "b", display_name = "SFX_Whooshes", item_count = 2 } }
      end,
      selection_counts = function() return { tracks = { selected = 1, registered = 1 } } end,
    },
  },
}

local peeks = {
  dx = { latest_revision = 15, reviewed_reference_revision = 9 },
  sfx = { latest_revision = 8, reviewed_reference_revision = 9 },
  mx = { latest_revision = 3, reviewed_reference_revision = 7 },
}
local populated_master = {
  project_values = {
    reference_revision = "9",
    delivery_subscriptions = '[' ..
      '{"sourceProjectId":"dx","sourceProjectName":"Dialogue","acceptedDeliveryRevision":14,"lanes":[]},' ..
      '{"sourceProjectId":"sfx","sourceProjectName":"SFX","acceptedDeliveryRevision":8,' ..
        '"lanes":[{"unmapped":true}]},' ..
      '{"sourceProjectId":"mx","sourceProjectName":"Music","acceptedDeliveryRevision":3,"lanes":[]},' ..
      '{"sourceProjectId":"fol","sourceProjectName":"Foley","acceptedDeliveryRevision":2,"lanes":[]}]',
  },
  services = {
    delivery_update = {
      peek = function(_, entry)
        local status = peeks[entry.sourceProjectId]
        if status then return status end
        return nil, "Shared storage is offline.", "unreachable"
      end,
    },
    reference_publish = {
      reference_tracks = function() return { {}, {}, {} } end,
      timeline_entries = function()
        return { { kind = "marker", registered = true }, { kind = "marker", registered = true },
          { kind = "region", registered = true } }
      end,
      selection_counts = function() return { tracks = { selected = 2 } } end,
    },
  },
}

local function with(base, fields)
  local view = {}
  for key, value in pairs(base) do view[key] = value end
  for key, value in pairs(fields) do view[key] = value end
  return view
end

local views = {
  { project_type = "" },
  { project_type = "source" },
  with(populated_source, { project_type = "source" }),
  with(populated_source, { project_type = "source", reference_names_expanded = true }),
  with(populated_master, { project_type = "master" }),
  { project_type = "source", view = "settings" },
  { project_type = "source", review = reviews.reference_update },
  { project_type = "source", review = reviews.delivery_publish },
  { project_type = "source", review = reviews.delivery_publish_first },
  { project_type = "source", review = reviews.delivery_publish_same_reference },
  { project_type = "source", review = reviews.delivery_publish_checking },
  { project_type = "source", review = reviews.delivery_publish_running },
  { project_type = "source", review = reviews.delivery_publish_cancelling },
  { project_type = "source", review = reviews.delivery_publish_failed },
  { project_type = "master" },
  { project_type = "master", view = "settings" },
  { project_type = "master", review = reviews.reference_publish },
  { project_type = "master", review = reviews.reference_publish_checking },
  { project_type = "master", review = reviews.reference_publish_running },
  { project_type = "master", review = reviews.delivery_import },
  { project_type = "master", review = reviews.delivery_update },
}

local scenarios = {}
for _, theme in ipairs({ "light", "dark" }) do
  for _, width in ipairs({ 320, 1040 }) do
    for _, view in ipairs(views) do
      table.insert(scenarios, with(view, { theme = theme, width = width }))
    end
  end
end

return scenarios
