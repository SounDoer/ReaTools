local header = require("reaprojectlink.ui.views.header")
local setup = require("reaprojectlink.ui.views.setup")

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
  for _, key in ipairs({ "page_header", "card_row", "card", "list", "notice", "stat_group", "issue_item" }) do
    components[key] = recorder(key)
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
  }
  local env = {
    ImGui = {}, ctx = {}, c = c,
    design_system = { components = components, patterns = { review_shell = recorder("review_shell") } },
    adapter = {},
    services = {
      project_service = {
        initialize_source = function() calls.initialized = "source"; return {} end,
        initialize_master = function() calls.initialized = "master"; return {} end,
      },
    },
    app = {
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

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
