local header_module = require("reaprojectlink.ui.design_review_header")
local footer_module = require("reaprojectlink.ui.design_review_footer")
local stale_module = require("reaprojectlink.ui.design_stale_review")
local shell_module = require("reaprojectlink.ui.design_review_shell")

local function equal(actual, expected, label)
  if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local tests = {}

function tests.header_emits_back_after_rendering_readable_content()
  local calls = { text = {} }
  local ImGui = {
    SameLine = function() end,
    TextWrapped = function(_, value) table.insert(calls.text, value) end,
    PushStyleColor = function() end, PopStyleColor = function() end, Col_Text = 1,
  }
  local adapter = { resolve = function() return 4 end }
  local button = { draw_icon = function(options) calls.button = options return {} end }
  local result = header_module.create(ImGui, "ctx", adapter, button).draw({
    id = "publish", title = "Publish Reference r7", summary = "4 tracks · 8 markers",
  })
  equal(calls.button.accessible_label, "Back", "back label")
  equal(calls.text[1], "Publish Reference r7", "title")
  equal(result.events[1].type, "review.back_requested", "event")
end

function tests.footer_blocks_completion_and_reflows()
  local calls = { available = 300 }
  local ImGui = {
    Separator = function() end, GetContentRegionAvail = function() return calls.available end,
    CalcTextSize = function(_, value) return #value * 7 end, SameLine = function() calls.same = true end,
    SetCursorPosX = function() end, GetCursorPosX = function() return 0 end,
  }
  local adapter = { resolve = function(id) return id:find("inline_wide", 1, true) and 360 or 12 end }
  local status = { draw = function(options) calls.status = options end }
  local button = { draw = function(options) calls.button = options end }
  local result = footer_module.create(ImGui, "ctx", adapter, button, status).draw({
    id = "publish", summary = "Fix 2 issues to publish", role = "blocked",
    complete_label = "Publish", enabled = false,
  })
  equal(calls.button.disabled, true, "disabled")
  equal(calls.button.stretch, true, "stacked")
  equal(calls.same, nil, "no same line")
  equal(#result.events, 0, "no event")
end

function tests.stale_review_emits_only_refresh_request()
  local calls = {}
  local status = { draw = function(options) calls.status = options end }
  local button = { draw = function(options) calls.button = options return {} end }
  local result = stale_module.create({}, "ctx", {}, status, button).draw({
    id = "publish", title = "Review Out of Date",
    message = "The project changed after this review was made.", refresh_label = "Refresh Review",
  })
  equal(calls.status.role, "warning", "warning")
  equal(calls.button.variant, "primary", "primary refresh")
  equal(result.events[1].type, "review.refresh_requested", "event")
end

function tests.shell_replaces_body_when_stale_and_disables_completion()
  local calls = { children = {}, ended = 0 }
  local ImGui = {
    WindowFlags_NoScrollbar = 1,
    GetContentRegionAvail = function() return 900, 640 end,
    GetCursorPosX = function() return 0 end, SetCursorPosX = function(_, x) calls.x = x end,
    BeginChild = function(_, id, width, height)
      table.insert(calls.children, { id = id, width = width, height = height }) return true
    end,
    EndChild = function() calls.ended = calls.ended + 1 end,
  }
  local adapter = { resolve = function(id) return id:find("max_width", 1, true) and 720 or 80 end }
  local header = { draw = function() return { events = { { type = "review.back_requested" } } } end }
  local footer = { draw = function(options) calls.footer = options return { events = {} } end }
  local stale = { draw = function() calls.stale = true return { events = { { type = "review.refresh_requested" } } } end }
  local body_called = false
  local result = shell_module.create(ImGui, "ctx", adapter, header, footer, stale).draw({
    id = "publish", header = { title = "Publish" },
    stale = { title = "Out of date", message = "Changed", refresh_label = "Refresh" },
    footer = { summary = "Refresh to continue", complete_label = "Publish", enabled = true },
    render_body = function() body_called = true end,
  })
  equal(body_called, false, "body replaced")
  equal(calls.footer.enabled, false, "completion disabled")
  equal(calls.children[1].width, 720, "max width")
  equal(calls.children[1].height, 560, "body height")
  equal(calls.ended, 2, "children balanced")
  equal(result.events[2].type, "review.refresh_requested", "event order")
end

function tests.shell_forwards_body_events_between_header_and_footer()
  local ImGui = {
    WindowFlags_NoScrollbar = 1, GetContentRegionAvail = function() return 600, 500 end,
    GetCursorPosX = function() return 0 end, SetCursorPosX = function() end,
    BeginChild = function() return true end, EndChild = function() end,
  }
  local adapter = { resolve = function(id) return id:find("max_width", 1, true) and 720 or 80 end }
  local header = { draw = function() return { events = { { type = "review.back_requested" } } } end }
  local footer = { draw = function() return { events = { { type = "review.complete_requested" } } } end }
  local result = shell_module.create(ImGui, "ctx", adapter, header, footer, {}).draw({
    id = "review", header = { title = "Review" }, footer = { summary = "Ready", complete_label = "Apply" },
    render_body = function() return { events = { { type = "decision.changed" } } } end,
  })
  equal(result.events[1].type, "review.back_requested", "header first")
  equal(result.events[2].type, "decision.changed", "body second")
  equal(result.events[3].type, "review.complete_requested", "footer last")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
