local constants = require("reaprojectlink.constants")
local settings = require("reaprojectlink.ui.views.settings")

local function equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

local function fake_env(actions)
  actions = actions or {}
  local calls = { copies = {}, values = {}, themes = {}, notifications = {} }
  local compat = {}
  function compat.begin_page() return true end
  function compat.end_page() end
  function compat.section() end
  function compat.copy_value(id, label, value)
    table.insert(calls.copies, { id = id, label = label, value = value })
  end
  function compat.key_value(label, value)
    table.insert(calls.values, { label = label, value = value })
  end
  function compat.explanation() end

  local design_adapter = {
    set_theme = function(value) table.insert(calls.themes, value) end,
    push_base = function() calls.pushes = (calls.pushes or 0) + 1 end,
    pop_base = function() calls.pops = (calls.pops or 0) + 1 end,
  }
  local env = {
    ImGui = { GetVersion = function() return 0, 9, "0.9" end },
    ctx = {}, fs = {}, version = "0.1.0", settings_compat = compat,
    adapter = {
      get_project_value = function(key)
        if key == constants.PROJECT_KEYS.delivery_id then return "delivery-1" end
        if key == constants.PROJECT_KEYS.reference_alignment_mode then return "mirror" end
      end,
    },
    theme = {
      mode = "dark", preference = "auto",
      set_preference = function(self, value)
        self.preference = value
        self.mode = value == "auto" and "dark" or value
        calls.saved_theme = value
      end,
    },
    design_system = {
      adapter = design_adapter,
      components = {
        checkbox = { draw = function() return actions.checkbox or { changed = false } end },
        segmented_control = {
          draw_field = function() return actions.segmented or { changed = false, value = "auto" } end,
        },
        button = { draw = function() return actions.reset_button and {} or nil end },
      },
      patterns = {
        path_selection = {
          draw = function(options)
            calls.path_options = options
            return { browse_requested = actions.browse == true }
          end,
        },
        review_header = {
          draw = function() return { back_requested = actions.back == true } end,
        },
        confirmation_dialog = {
          draw = function(options)
            calls.confirmation_options = options
            return { action = actions.confirmation }
          end,
        },
      },
    },
    reaper = {
      GetAppVersion = function() return "7.78" end,
      GetUserFileNameForRead = function() return true, "C:/reference.json" end,
    },
    services = {
      reference_subscription = {
        subscribe = function(_, _, path) calls.subscribed = path; return {} end,
        set_alignment_mode = function(_, mode) calls.alignment = mode; return {} end,
      },
      project_service = {
        reset = function() calls.reset = true; return {} end,
      },
    },
    app = {
      back = function() calls.back = true end,
      reset = function() calls.app_reset = true end,
      request_check = function() calls.check_requested = true end,
      notify = function(_, message, is_error)
        table.insert(calls.notifications, { message = message, is_error = is_error })
      end,
    },
    c = {},
  }
  return env, calls
end

local SOURCE_STATE = {
  project_type = constants.PROJECT_TYPES.source,
  path = "C:/Session/Dialogue.rpp",
  project_id = "project-1",
  reference_manifest_path = "C:/old/reference.json",
}

local tests = {}

function tests.routes_shared_control_events_to_existing_product_effects()
  local env, calls = fake_env({
    browse = true,
    checkbox = { changed = true, checked = false },
    segmented = { changed = true, value = "light" },
  })
  settings.create():draw(env, SOURCE_STATE)
  equal(calls.subscribed, "C:/reference.json", "Reference picker subscribes")
  equal(calls.alignment, "relative", "unchecked alignment stores relative mode")
  equal(calls.saved_theme, "light", "theme preference persists")
  equal(calls.path_options.read_only, true, "Reference path remains picker-owned")
  equal(calls.copies[4].value, "delivery-1", "Delivery ID remains copyable")
  equal(calls.pushes, 1, "shared style pushed")
  equal(calls.pops, 1, "shared style popped")
end

function tests.reset_runs_only_after_shared_confirmation()
  local view = settings.create()
  local env, calls = fake_env({ reset_button = true, confirmation = "confirmed" })
  view:draw(env, SOURCE_STATE)
  equal(calls.confirmation_options.open, true, "reset opens confirmation")
  equal(calls.confirmation_options.danger, true, "reset confirmation is destructive")
  equal(calls.reset, true, "reset service called")
  equal(calls.app_reset, true, "application state reset")
  equal(calls.check_requested, true, "project check requested")
  equal(view.reset_open, false, "confirmation closes")
end

function tests.back_closes_pending_reset_without_mutating_project()
  local view = settings.create()
  view.reset_open = true
  local env, calls = fake_env({ back = true })
  view:draw(env, SOURCE_STATE)
  equal(calls.back, true, "Back navigation preserved")
  equal(calls.reset, nil, "Back does not reset project")
  equal(view.reset_open, false, "pending confirmation cleared")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
