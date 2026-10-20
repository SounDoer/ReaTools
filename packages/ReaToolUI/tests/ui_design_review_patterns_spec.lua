local header_module = require("reaui.design_review_header")
local footer_module = require("reaui.design_review_footer")
local stale_module = require("reaui.design_stale_review")
local shell_module = require("reaui.design_review_shell")

local function equal(actual, expected, label)
  if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local tests = {}

function tests.review_header_renders_through_page_header_with_back()
  local calls = {}
  local page_header = { draw = function(options)
    calls.header = options
    return { events = { { type = "page_header.back_requested", id = options.id } }, back_requested = true }
  end }
  local result = header_module.create({}, "ctx", {}, page_header).draw({
    id = "publish", title = "Publish Reference r7", summary = "4 tracks · 8 markers", disabled = true,
  })
  equal(calls.header.id, "publish", "header id")
  equal(calls.header.title, "Publish Reference r7", "title")
  equal(calls.header.back_label, "Back", "default back label")
  equal(calls.header.summary, "4 tracks · 8 markers", "summary")
  equal(calls.header.back_disabled, true, "disabled back")
  equal(result.back_requested, true, "back requested")
  equal(#result.events, 1, "one event")
  equal(result.events[1].type, "review.back_requested", "review event")
  equal(result.events[1].id, "publish", "event id")
  local quiet = header_module.create({}, "ctx", {}, { draw = function() return { events = {}, back_requested = false } end })
  local idle = quiet.draw({ id = "publish", title = "Publish", back_label = "Back to Main" })
  equal(#idle.events, 0, "no event without back")
  equal(idle.back_requested, false, "not requested")
end

local function footer_fake(available)
  local calls = { available = available, separators = 0, y = 100 }
  local ImGui = {
    StyleVar_ItemSpacing = 1,
    Separator = function() calls.separators = calls.separators + 1; calls.y = calls.y + 1 + 4 end,
    GetContentRegionAvail = function() return calls.available end,
    GetStyleVar = function() return 8, 4 end,
    GetCursorPosY = function() return calls.y end,
    SetCursorPosY = function(_, y) calls.y = y; calls.set_y = calls.set_y or {}; table.insert(calls.set_y, y) end,
    SetCursorPosX = function() calls.set_x = true end,
    GetTextLineHeight = function() return 16 end,
    SameLine = function() calls.same = true end,
  }
  local adapter = { resolve = function(id)
    if id:find("inline_wide", 1, true) then return 360 end
    if id:find("footer.padding_y", 1, true) then return 12 end
    if id:find("control.medium", 1, true) then return 32 end
    return 12
  end }
  local status = { draw = function(options) calls.status = options; calls.status_y = calls.y end }
  local button = { draw = function(options) calls.button = options; calls.button_y = calls.y end }
  local layout = {
    button_width = function(label) return #label * 7 + 24 end,
    trailing = function(width) calls.trailing = width; return false end,
  }
  return footer_module.create(ImGui, "ctx", adapter, button, status, layout), calls
end

function tests.review_footer_draws_exactly_one_separator()
  for _, available in ipairs({ 300, 600 }) do
    local footer, calls = footer_fake(available)
    footer.draw({ id = "publish", summary = "Ready to publish", role = "ready", complete_label = "Publish" })
    equal(calls.separators, 1, "one separator at " .. available)
    equal(calls.status.presentation, "inline", "inline status")
    equal(calls.status.role, "ready", "status role")
  end
end

function tests.review_footer_uses_layout_trailing()
  local footer, calls = footer_fake(600)
  footer.draw({ id = "publish", summary = "Ready to publish", role = "ready", complete_label = "Publish",
    running_label = "Publishing Reference..." })
  local top = 100 + 1 + 12
  equal(calls.status_y, top + (32 - 16) / 2, "status centered on the button row")
  equal(calls.trailing, #"Publishing Reference..." * 7 + 24, "trailing width fits the longest label")
  equal(calls.button_y, top, "button on the footer row")
  equal(calls.button.stretch, false, "natural width")
  equal(calls.set_x, nil, "no manual x positioning")
end

function tests.footer_blocks_completion_and_reflows()
  local calls = { available = 300 }
  local ImGui = {
    Separator = function() end, GetContentRegionAvail = function() return calls.available end,
    CalcTextSize = function(_, value) return #value * 7 end, SameLine = function() calls.same = true end,
    SetCursorPosX = function() end, GetCursorPosX = function() return 0 end,
    GetStyleVar = function() return 8, 4 end, GetCursorPosY = function() return 0 end, SetCursorPosY = function() end,
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

function tests.shell_footer_passes_window_flags_in_the_window_slot()
  local children = {}
  local ImGui = {
    WindowFlags_NoScrollbar = 8, GetContentRegionAvail = function() return 600, 500 end,
    GetCursorPosX = function() return 0 end, SetCursorPosX = function() end,
    BeginChild = function(_, id, _, _, child_flags, window_flags)
      children[#children + 1] = { id = id, child_flags = child_flags, window_flags = window_flags }
      return true
    end,
    EndChild = function() end,
  }
  local adapter = { resolve = function(id) return id:find("max_width", 1, true) and 720 or 80 end }
  local stub = { draw = function() return { events = {} } end }
  shell_module.create(ImGui, "ctx", adapter, stub, stub, {}).draw({
    id = "review", header = { title = "Review" }, footer = { summary = "Ready", complete_label = "Apply" },
    render_body = function() return { events = {} } end,
  })
  equal(children[2].id, "##review-shell-review-footer", "footer child")
  equal(children[2].child_flags, 0, "no child flags")
  equal(children[2].window_flags, 8, "no scrollbar window flag")
end

function tests.review_sections_are_separated_by_section_loose()
  local calls = { y = 0, texts = {}, set_y = {} }
  local role = "body"
  local ImGui = {
    WindowFlags_NoScrollbar = 1, Col_Text = 2, StyleVar_ItemSpacing = 3,
    GetContentRegionAvail = function() return 600, 500 end,
    GetCursorPosX = function() return 0 end, SetCursorPosX = function() end,
    BeginChild = function() return true end, EndChild = function() end,
    GetStyleVar = function() return 8, 4 end,
    GetCursorPosY = function() return calls.y end,
    SetCursorPosY = function(_, y) calls.y = y; table.insert(calls.set_y, y) end,
    PushStyleColor = function(_, _, color) calls.color = color end, PopStyleColor = function() end,
    TextWrapped = function(_, text)
      table.insert(calls.texts, { text = text, role = role, color = calls.color }); calls.y = calls.y + 20 + 4
    end,
  }
  local adapter = {
    resolve = function(id)
      if id:find("max_width", 1, true) then return 720 end
      if id:find("section.loose", 1, true) then return 24 end
      if id:find("footer.height", 1, true) then return 80 end
      return id
    end,
    with_text = function(next_role, renderer)
      local previous = role; role = next_role
      local result = renderer()
      role = previous
      return result
    end,
  }
  local header = { draw = function() return { events = {} } end }
  local footer = { draw = function() return { events = {} } end }
  local shell = shell_module.create(ImGui, "ctx", adapter, header, footer, {})
  local function body()
    local first = shell.section({ id = "issues", title = "Issues" }, function() calls.y = calls.y + 40; return "issues" end)
    local before = calls.y
    local second = shell.section({ id = "details", title = "Details" }, function() return "details" end)
    return { events = {}, first = first, second = second, before = before }
  end
  for frame = 1, 2 do
    calls.y, calls.texts, calls.set_y = 0, {}, {}
    local result = shell.draw({ id = "review", header = { title = "Review" },
      footer = { summary = "Ready", complete_label = "Apply" }, render_body = body })
    local inner = result.body_result
    equal(inner.first, "issues", "section returns render result")
    equal(inner.second, "details", "second result")
    equal(#calls.set_y, 1, "only the second section adds a gap on frame " .. frame)
    equal(calls.set_y[1], inner.before - 4 + 24, "section loose gap")
    equal(calls.texts[1].text, "Issues", "first title")
    equal(calls.texts[1].role, "heading", "heading font")
    equal(calls.texts[1].color, "semantic.color.text.primary", "title color")
  end
  assert(not pcall(function() shell.section({ id = "x" }, function() end) end), "title required")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
