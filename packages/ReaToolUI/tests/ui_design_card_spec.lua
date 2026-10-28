local card_module = require("reaui.design_card")

local function equal(actual, expected, label)
  if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local TOKENS = {
  ["semantic.space.container.padding"] = 16,
  ["semantic.space.block.gap"] = 16,
  ["semantic.space.footer.padding_y"] = 12,
  ["semantic.space.stack.tight"] = 10,
  ["semantic.space.inline.default"] = 8,
  ["semantic.size.control.medium"] = 28,
  ["semantic.size.icon.medium"] = 16,
}

-- A fake ImGui that tracks the vertical cursor: every item advances it by its
-- height plus an 8 unit item spacing.
local function dependencies(options)
  options = options or {}
  local calls = {
    tokens = {}, colors = 0, popped_colors = 0, vars = 0, popped_vars = 0, ended = 0,
    wrapped = {}, set_y = {}, statuses = {}, icons = {},
  }
  local cursor = { x = 16, y = 16 }
  local function advance(height)
    cursor.y = cursor.y + height + 8
    -- Dear ImGui truncates the next line's cursor (IM_TRUNC).
    if options.truncate then cursor.y = math.floor(cursor.y) end
  end
  local ImGui = {
    Col_ChildBg = 1, Col_Border = 2, Col_Text = 3, StyleVar_ChildBorderSize = 4,
    StyleVar_WindowPadding = 5, StyleVar_ItemSpacing = 6, WindowFlags_NoScrollbar = 8,
  }
  function ImGui.PushStyleColor() calls.colors = calls.colors + 1 end
  function ImGui.PopStyleColor(_, n) calls.popped_colors = calls.popped_colors + (n or 1) end
  function ImGui.PushStyleVar() calls.vars = calls.vars + 1 end
  function ImGui.PopStyleVar(_, n) calls.popped_vars = calls.popped_vars + (n or 1) end
  function ImGui.GetStyleVar() return 8, 8 end
  function ImGui.BeginChild(_, id, width, height, flags)
    calls.child = { id = id, width = width, height = height, flags = flags }
    cursor.x, cursor.y = 16, 16
    return true
  end
  function ImGui.EndChild() calls.ended = calls.ended + 1; calls.last_before_end = calls.last end
  function ImGui.GetCursorPosX() return cursor.x end
  function ImGui.GetCursorPosY() return cursor.y end
  function ImGui.SetCursorPosX(_, x) cursor.x = x end
  function ImGui.SetCursorPosY(_, y) cursor.y = y; table.insert(calls.set_y, y); calls.last = "set" end
  function ImGui.SetCursorPos(_, x, y) cursor.x, cursor.y = x, y end
  function ImGui.GetCursorScreenPos() return cursor.x, cursor.y end
  function ImGui.GetContentRegionAvail() return 300, 200 end
  function ImGui.GetWindowDrawList() return "draw-list" end
  function ImGui.GetTextLineHeight() return 16 end
  function ImGui.PushTextWrapPos(_, x) calls.wrap_pos = x end
  function ImGui.PopTextWrapPos() end
  function ImGui.TextWrapped(_, value) table.insert(calls.wrapped, value); cursor.x = 16; advance(16) end
  function ImGui.Separator()
    calls.separator_y = cursor.y; calls.separators = (calls.separators or 0) + 1; advance(1)
  end
  function ImGui.Dummy(_, w, h) advance(h); calls.last = "dummy " .. w .. "x" .. h end
  local adapter = {
    resolve = function(id)
      table.insert(calls.tokens, id)
      if TOKENS[id] then return TOKENS[id] end
      return id:find("width", 1, true) and 1 or 0x112233ff
    end,
    with_text = function(_, renderer) return renderer() end,
  }
  local deps = {
    icons = { draw = function(_, _, name) table.insert(calls.icons, name) return true end },
    status = { draw = function(status_options)
      table.insert(calls.statuses, status_options); calls.status_y = cursor.y; advance(16)
    end },
    button = { draw_icon = function(button_options)
      calls.trailing_y = cursor.y; calls.trailing = button_options; advance(28)
      if options.click == "trailing" then return { type = "button.activated", id = button_options.id } end
    end },
    menu = { draw = function(menu_options)
      calls.trailing_y = cursor.y; calls.trailing = menu_options; advance(28)
      if options.click == "menu" then return { events = {}, action = "rename" } end
      return { events = {} }
    end },
    action_bar = { draw = function(bar_options)
      if bar_options.id and bar_options.id:find("-actions$") then
        calls.bars = calls.bars or {}
        calls.bars[bar_options.id] = { options = bar_options, y = cursor.y }
        advance(28)
        if options.click == bar_options.id then return { events = {}, action = bar_options.actions[1].id } end
        return { events = {} }
      end
      calls.footer = bar_options; calls.footer_y = cursor.y; advance(options.footer_height or 28)
      if options.click == "footer" then return { events = {}, action = "publish" } end
      return { events = {} }
    end },
    section_heading = { draw = function(heading_options)
      calls.headings = calls.headings or {}
      table.insert(calls.headings, { id = heading_options.id, title = heading_options.title,
        gap_above = heading_options.gap_above, y = cursor.y })
      advance(20)
    end },
  }
  return ImGui, adapter, deps, calls
end

local function body_lines(ImGui, count)
  return function()
    for _ = 1, count do ImGui.TextWrapped("ctx", "line") end
    return "content"
  end
end

local FOOTER = { context = "2 changes", actions = { { id = "publish", label = "Publish", variant = "primary" } } }

local tests = {}

function tests.renders_content_and_balances_stacks()
  local ImGui, adapter, deps, calls = dependencies()
  local card = card_module.create(ImGui, "ctx", adapter, deps)
  local result = card.draw({ id = "project", title = "Source project", description = "Current local project.", width = 320 },
    function() return "content" end)
  equal(result.body_result, "content", "body result")
  equal(#result.events, 0, "no events")
  equal(calls.child.width, 320, "width")
  equal(calls.wrapped[1], "Source project", "title")
  equal(calls.wrapped[2], "Current local project.", "description")
  equal(calls.ended, 1, "child end")
  equal(calls.colors, calls.popped_colors, "color stack")
  equal(calls.vars, calls.popped_vars, "var stack")
  equal(calls.last_before_end, "dummy 0x0", "contents end with an item, not a cursor move")
end

function tests.title_row_height_is_fixed_with_or_without_trailing()
  local status = { role = "ready", text = "Synchronized" }
  local ImGui, adapter, deps, plain = dependencies()
  card_module.create(ImGui, "ctx", adapter, deps).draw({ id = "a", title = "Reference", status = status })
  local ImGui2, adapter2, deps2, trailing = dependencies()
  card_module.create(ImGui2, "ctx", adapter2, deps2).draw({
    id = "b", title = "Reference", status = status, icon = "film",
    trailing = { kind = "icon_button", id = "more", icon = "more", accessible_label = "More" },
  })
  equal(trailing.trailing_y, 16, "trailing control sits on the title row")
  equal(plain.status_y, 16 + 28 + 16, "status after fixed row and block gap")
  equal(trailing.status_y, 16 + 28 + 16, "same status position with trailing")
  equal(trailing.icons[1], "film", "title icon")
  equal(trailing.statuses[1].presentation, "prominent", "prominent status")
end

function tests.natural_height_ignores_min_height()
  local ImGui, adapter, deps = dependencies()
  local card = card_module.create(ImGui, "ctx", adapter, deps)
  local first = card.draw({ id = "c", title = "Reference" }, body_lines(ImGui, 2))
  local second = card.draw({ id = "c", title = "Reference", min_height = 400 }, body_lines(ImGui, 2))
  -- title row 28, gap 16, two 16 lines with 8 spacing between, padding 16 on both sides
  equal(first.natural_height, 16 + 28 + 16 + 40 + 16, "natural")
  equal(second.natural_height, first.natural_height, "min height does not leak into natural")
end

function tests.first_frame_auto_resizes_and_later_frames_use_natural_height()
  local ImGui, adapter, deps, calls = dependencies()
  local card = card_module.create(ImGui, "ctx", adapter, deps)
  local first = card.draw({ id = "c", title = "Reference" })
  assert(calls.child.flags & (1 << 5) ~= 0, "auto resize on first frame")
  equal(calls.child.height, 0, "auto height")
  card.draw({ id = "c", title = "Reference" })
  equal(calls.child.flags & (1 << 5), 0, "fixed later")
  equal(calls.child.height, first.natural_height, "fixed at natural")
end

function tests.footer_is_pinned_to_bottom_when_min_height_exceeds_content()
  local ImGui, adapter, deps, calls = dependencies()
  local card = card_module.create(ImGui, "ctx", adapter, deps)
  card.draw({ id = "f", title = "Reference", footer = FOOTER }, body_lines(ImGui, 1))
  local natural_separator = calls.separator_y
  equal(natural_separator, 16 + 28 + 16 + 16 + 16, "separator after body and block gap")
  equal(calls.footer_y, natural_separator + 12, "footer padding")
  card.draw({ id = "f", title = "Reference", footer = FOOTER, min_height = 300 }, body_lines(ImGui, 1))
  -- footer height = 12 padding + 28 action bar
  equal(calls.child.height, 300, "stretched")
  equal(calls.separator_y, 300 - 16 - 40, "separator pinned to the bottom")
end

function tests.pinned_footer_stays_still_with_fractional_sizes()
  local ImGui, adapter, deps, calls = dependencies({ truncate = true, footer_height = 27.3 })
  local card = card_module.create(ImGui, "ctx", adapter, deps)
  card.draw({ id = "f", title = "Reference", footer = FOOTER }, body_lines(ImGui, 1))
  local separator_y = {}
  for frame = 1, 6 do
    card.draw({ id = "f", title = "Reference", footer = FOOTER, min_height = 300.5 }, body_lines(ImGui, 1))
    separator_y[frame] = calls.separator_y
  end
  for frame = 3, 6 do
    equal(separator_y[frame], separator_y[2], "separator y on frame " .. frame)
  end
end

function tests.height_shrinks_when_content_shrinks()
  local ImGui, adapter, deps, calls = dependencies()
  local card = card_module.create(ImGui, "ctx", adapter, deps)
  local tall = card.draw({ id = "s", title = "Reference" }, body_lines(ImGui, 5))
  card.draw({ id = "s", title = "Reference" }, body_lines(ImGui, 1))
  local short = card.draw({ id = "s", title = "Reference" }, body_lines(ImGui, 1))
  assert(short.natural_height < tall.natural_height, "natural shrinks")
  equal(calls.child.height, short.natural_height, "child shrinks on the next frame")
end

function tests.trailing_menu_and_footer_actions_surface_as_action()
  for _, fixture in ipairs({
    { click = "trailing", trailing = { kind = "icon_button", id = "check", icon = "check", accessible_label = "Check" }, expected = "check" },
    { click = "menu", trailing = { kind = "menu", id = "menu", accessible_label = "More", items = { { id = "rename", label = "Rename" } } }, expected = "rename" },
    { click = "footer", footer = FOOTER, expected = "publish" },
  }) do
    local ImGui, adapter, deps = dependencies({ click = fixture.click })
    local result = card_module.create(ImGui, "ctx", adapter, deps).draw({
      id = "card", title = "Reference", trailing = fixture.trailing, footer = fixture.footer,
    })
    equal(result.action, fixture.expected, fixture.click .. " action")
    equal(result.events[1].type, "card.action_selected", fixture.click .. " event")
    equal(result.events[1].id, "card", fixture.click .. " card id")
    equal(result.events[1].action, fixture.expected, fixture.click .. " event action")
  end
end

local function sections(ImGui, order, action)
  return {
    { id = "registered", heading = "Registered", render = function()
      table.insert(order, "registered"); ImGui.TextWrapped("ctx", "Kick")
    end },
    { id = "selected", heading = "Selected", render = function()
      table.insert(order, "selected"); ImGui.TextWrapped("ctx", "Snare")
      return action
    end },
  }
end

function tests.sections_follow_the_body_each_behind_a_separator()
  local ImGui, adapter, deps, calls = dependencies()
  local order = {}
  card_module.create(ImGui, "ctx", adapter, deps).draw({ id = "c", title = "Reference",
    sections = sections(ImGui, order) }, body_lines(ImGui, 1))
  local body_bottom = 16 + 28 + 16 + 16
  equal(calls.separators, 2, "one separator per section")
  equal(calls.headings[1].y, body_bottom + 16 + 12, "first heading after the separator padding")
  equal(calls.headings[1].title, "Registered", "first heading")
  equal(calls.headings[1].id, "c-registered", "heading id")
  equal(calls.headings[1].gap_above, false, "no gap above the heading")
  equal(calls.headings[2].title, "Selected", "second heading")
  -- first section: heading 20 + stack.tight 10, text 16 → bottom; then block gap, separator, padding
  equal(calls.headings[2].y, calls.headings[1].y + 30 + 16 + 16 + 12, "second section after its separator")
  equal(order[1], "registered", "sections render in order")
  equal(order[2], "selected", "second section renders")
end

function tests.empty_body_adds_no_block()
  local status = { role = "ready", text = "Up to Date" }
  local ImGui, adapter, deps, without = dependencies()
  card_module.create(ImGui, "ctx", adapter, deps).draw({ id = "a", title = "Reference", status = status,
    sections = sections(ImGui, {}) })
  local ImGui2, adapter2, deps2, empty = dependencies()
  local result = card_module.create(ImGui2, "ctx", adapter2, deps2).draw({ id = "b", title = "Reference",
    status = status, sections = sections(ImGui2, {}) }, function() return "nothing" end)
  equal(empty.headings[1].y, without.headings[1].y, "first section where it is without a body")
  equal(result.body_result, "nothing", "body result kept")
end

function tests.section_action_surfaces_as_card_action()
  local ImGui, adapter, deps = dependencies()
  local result = card_module.create(ImGui, "ctx", adapter, deps).draw({ id = "c", title = "Reference",
    sections = sections(ImGui, {}, "register_selected") })
  equal(result.action, "register_selected", "section action")
  equal(result.events[1].type, "card.action_selected", "event type")
  equal(result.events[1].action, "register_selected", "event action")
end

function tests.section_actions_sit_below_the_content()
  local ImGui, adapter, deps, calls = dependencies({ click = "c-selected-actions" })
  local result = card_module.create(ImGui, "ctx", adapter, deps).draw({ id = "c", title = "Reference",
    sections = { { id = "selected", heading = "Selected", actions = { { id = "register", label = "Register" } },
      render = function() ImGui.TextWrapped("ctx", "Snare") end } } })
  local bar = calls.bars["c-selected-actions"]
  -- heading 20 + stack.tight 10, text 16 + stack.tight 10
  equal(bar.y, calls.headings[1].y + 30 + 26, "actions after the content")
  equal(bar.options.actions[1].label, "Register", "section actions")
  equal(result.action, "register", "section action becomes the card action")
end

function tests.pinned_footer_leaves_sections_with_the_content()
  local ImGui, adapter, deps, calls = dependencies()
  local card = card_module.create(ImGui, "ctx", adapter, deps)
  local options = { id = "p", title = "Reference", sections = sections(ImGui, {}), footer = FOOTER }
  card.draw(options, body_lines(ImGui, 1))
  local natural_y = calls.headings[1].y
  calls.separators, calls.headings = 0, {}
  options.min_height = 400
  card.draw(options, body_lines(ImGui, 1))
  equal(calls.headings[1].y, natural_y, "sections stay below the body")
  equal(calls.separators, 3, "two section separators and the footer separator")
  equal(calls.separator_y, 400 - 16 - 40, "footer separator pinned to the bottom")
end

function tests.rejects_selection_option()
  local ImGui, adapter, deps = dependencies()
  local ok, err = pcall(function()
    card_module.create(ImGui, "ctx", adapter, deps).draw({ id = "x", selection = {} })
  end)
  equal(ok, false, "selection rejected")
  assert(tostring(err):find("sections", 1, true), "error names sections")
end

function tests.empty_card_renders_without_events()
  local ImGui, adapter, deps, calls = dependencies()
  local result = card_module.create(ImGui, "ctx", adapter, deps).draw({ id = "empty" })
  equal(#result.events, 0, "no events")
  equal(result.action, nil, "no action")
  equal(calls.ended, 1, "child closed")
  equal(calls.separator_y, nil, "no separator without footer")
end

function tests.emphasized_variant_uses_emphasis_tokens()
  local ImGui, adapter, deps, calls = dependencies()
  card_module.create(ImGui, "ctx", adapter, deps).draw({ id = "current", variant = "emphasized" })
  local joined = table.concat(calls.tokens, "\n")
  assert(joined:find("component.card.border.emphasized", 1, true), "emphasis border")
  assert(joined:find("semantic.border.emphasis.width", 1, true), "emphasis width")
end

function tests.content_failure_closes_child_and_rethrows()
  local ImGui, adapter, deps, calls = dependencies()
  local card = card_module.create(ImGui, "ctx", adapter, deps)
  local ok, err = pcall(function() card.draw({ id = "bad" }, function() error("content failed") end) end)
  equal(ok, false, "failure")
  assert(tostring(err):find("content failed", 1, true), "original error")
  equal(calls.ended, 1, "child closed")
end

function tests.rejects_invalid_inputs()
  local ImGui, adapter, deps = dependencies()
  local card = card_module.create(ImGui, "ctx", adapter, deps)
  assert(not pcall(function() card.draw({ id = "" }) end), "id rejected")
  assert(not pcall(function() card.draw({ id = "x", variant = "selected" }) end), "variant rejected")
  assert(not pcall(function() card.draw({ id = "x", width = -1 }) end), "width rejected")
  assert(not pcall(function() card.draw({ id = "x", min_height = -1 }) end), "min height rejected")
  assert(not pcall(function() card.draw({ id = "x", trailing = { kind = "badge" } }) end), "trailing rejected")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
