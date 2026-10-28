local list_module = require("reaui.design_list")
local layout_module = require("reaui.design_layout")

local function equal(actual, expected, label)
  if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local TOKENS = {
  ["semantic.space.list.gap"] = 8,
  ["semantic.space.inset.padding_x"] = 12,
  ["semantic.space.inset.padding_y"] = 8,
  ["semantic.space.control.gap"] = 8,
  ["semantic.space.control.padding_x"] = 12,
  ["semantic.size.control.compact"] = 28,
  ["semantic.size.control.medium"] = 32,
  ["semantic.size.row.single"] = 40,
  ["semantic.size.row.double"] = 56,
  ["semantic.size.row.compact"] = 32,
}
local CHAR = 7
local LINE = 16

-- Fake ImGui with a simulated cursor. Text is CHAR units per character and
-- wraps at the pushed wrap position; each item advances by its height plus 8.
local function fake(options)
  options = options or {}
  local width = options.width or 296
  local calls = {
    children = {}, texts = {}, separators = 0, buttons = {}, menus = {}, statuses = {},
    set_x = {}, colors = 0, popped_colors = 0, vars = 0, popped_vars = 0, ended = 0, roles = {},
  }
  local outer = { x = 0, y = 0 }
  local cursor = outer
  local x0 = 0
  local last = { x = 0, y = 0, w = 0, h = 0 }
  local groups = {}
  local wrap_pos
  local role = "body"
  local color_stack = {}
  calls.trees = {}
  local LINE = options.line or LINE
  local function item(w, h)
    last = { x = cursor.x, y = cursor.y, w = w, h = h }
    for _, group in ipairs(groups) do
      group.right = math.max(group.right, cursor.x + w)
    end
    cursor.x = x0
    cursor.y = last.y + h + 8
    -- Dear ImGui truncates the next line's cursor (IM_TRUNC).
    if options.truncate then cursor.y = math.floor(cursor.y) end
  end
  local ImGui = {
    Col_ChildBg = 1, Col_Text = 2, StyleVar_ChildRounding = 3, StyleVar_WindowPadding = 4,
    StyleVar_ItemSpacing = 5, WindowFlags_NoScrollbar = 8, Cond_Always = 1,
    TreeNodeFlags_SpanAvailWidth = 2, TreeNodeFlags_NoTreePushOnOpen = 4,
  }
  function ImGui.PushStyleColor(_, _, color)
    calls.colors = calls.colors + 1
    table.insert(color_stack, color)
  end
  function ImGui.PopStyleColor(_, n)
    calls.popped_colors = calls.popped_colors + (n or 1)
    for _ = 1, n or 1 do table.remove(color_stack) end
  end
  local next_open
  function ImGui.SetNextItemOpen(_, open) next_open = open end
  function ImGui.TreeNodeEx(_, id)
    table.insert(calls.trees, { id = id, requested = next_open, y = cursor.y })
    item(width, LINE)
    if options.toggle then return not next_open end
    return next_open
  end
  function ImGui.GetTreeNodeToLabelSpacing() return 20 end
  function ImGui.SetCursorPos(_, x, y) cursor.x, cursor.y = x, y end
  function ImGui.PushStyleVar() calls.vars = calls.vars + 1 end
  function ImGui.PopStyleVar(_, n) calls.popped_vars = calls.popped_vars + (n or 1) end
  function ImGui.GetStyleVar() return 8, 8 end
  function ImGui.BeginChild(_, id, w, h)
    table.insert(calls.children, { id = id, y = outer.y, height = h })
    cursor = { x = 12, y = 8 }
    x0 = 12
    return true
  end
  function ImGui.EndChild()
    calls.ended = calls.ended + 1
    local child = calls.children[#calls.children]
    cursor = outer
    x0 = 0
    last = { x = 0, y = child.y, w = width, h = child.height }
    cursor.y = child.y + child.height + 8
  end
  function ImGui.GetCursorPosX() return cursor.x end
  function ImGui.GetCursorPosY() return cursor.y end
  function ImGui.SetCursorPosX(_, x) cursor.x = x; table.insert(calls.set_x, x) end
  function ImGui.SetCursorPosY(_, y) cursor.y = y; calls.last = "set" end
  function ImGui.Dummy(_, w, h) item(w, h); calls.last = "dummy " .. w .. "x" .. h end
  function ImGui.GetContentRegionAvail() return x0 + width - cursor.x, 100 end
  function ImGui.CalcTextSize(_, text) return #text * CHAR, LINE end
  function ImGui.GetTextLineHeight() return LINE end
  function ImGui.PushTextWrapPos(_, x) wrap_pos = x end
  function ImGui.PopTextWrapPos() wrap_pos = nil end
  function ImGui.TextWrapped(_, text)
    local limit = (wrap_pos or (x0 + width)) - cursor.x
    local natural = #text * CHAR
    local lines = math.max(1, math.ceil(natural / limit))
    table.insert(calls.texts, { text = text, role = role, lines = lines, x = cursor.x, y = cursor.y,
      color = color_stack[#color_stack] })
    item(math.min(natural, limit), lines * LINE)
  end
  function ImGui.BeginGroup() table.insert(groups, { x = cursor.x, y = cursor.y, right = cursor.x }) end
  function ImGui.EndGroup()
    local group = table.remove(groups)
    local bottom = cursor.y - 8
    cursor.x, cursor.y = group.x, group.y
    item(group.right - group.x, bottom - group.y)
  end
  function ImGui.SameLine(_, _, spacing)
    cursor.x = last.x + last.w + (spacing or 8)
    cursor.y = last.y
  end
  function ImGui.NewLine()
    cursor.x = x0
    cursor.y = last.y + last.h + 8
  end
  function ImGui.Separator() calls.separators = calls.separators + 1 end
  local adapter = {
    resolve = function(id) return TOKENS[id] or id end,
    with_text = function(next_role, renderer)
      local previous = role
      role = next_role
      table.insert(calls.roles, next_role)
      local result = renderer()
      role = previous
      return result
    end,
  }
  local deps = {
    status = {
      measure = function(o) return #o.text * CHAR + 24 end,
      draw = function(o)
        table.insert(calls.statuses, o)
        item(#o.text * CHAR + 24, LINE)
      end,
    },
    button = { draw = function(o)
      table.insert(calls.buttons, { options = o, x = cursor.x })
      item(#o.label * CHAR + 24, 28)
      if options.click == o.label then return { type = "button.activated", id = o.id } end
    end },
    menu = { draw = function(o)
      table.insert(calls.menus, { options = o, x = cursor.x })
      item(28, 28)
      return { events = {}, action = options.menu_choice }
    end },
  }
  deps.layout = layout_module.create(ImGui, "ctx", adapter)
  calls.cursor_y = function() return cursor.y end
  return list_module.create(ImGui, "ctx", adapter, deps), calls, width
end

local ROWS = {
  { kind = "row", id = "music", title = "Music bed", status = { role = "ready", text = "Ready" } },
  { kind = "row", id = "dialogue", title = "Dialogue", detail = "3 takes · 00:42",
    action = { id = "detach", label = "Detach..." },
    menu = { accessible_label = "Dialogue actions", items = { { id = "rename", label = "Rename" } } } },
}

local tests = {}

function tests.rows_have_no_separator_and_use_list_gap()
  local list, calls = fake()
  list.draw({ id = "refs", items = ROWS })
  equal(calls.separators, 0, "no separators")
  equal(#calls.children, 2, "two rows")
  local first, second = calls.children[1], calls.children[2]
  equal(second.y, first.y + first.height + 8, "list gap between rows")
  equal(calls.colors, calls.popped_colors, "color stack")
  equal(calls.vars, calls.popped_vars, "var stack")
  equal(calls.ended, 2, "children closed")
end

function tests.detail_stays_still_with_fractional_line_height()
  local list, calls = fake({ line = 13.3, truncate = true })
  local row = { kind = "row", id = "name", title = "Name", detail = "Master",
    action = { id = "copy", label = "Copy" } }
  local detail_y = {}
  for frame = 1, 6 do
    calls.texts = {}
    list.draw({ id = "settings", items = { row } })
    detail_y[frame] = calls.texts[2].y
  end
  for frame = 3, 6 do
    equal(detail_y[frame], detail_y[2], "detail y on frame " .. frame)
  end
end

function tests.double_height_when_detail_present()
  local list, calls = fake()
  list.draw({ id = "refs", items = ROWS })
  equal(calls.children[1].height, 40, "single line row")
  equal(calls.children[2].height, 56, "two line row")
  equal(calls.texts[3].text, "3 takes · 00:42", "detail text")
  equal(calls.texts[3].role, "metadata", "detail font")
end

function tests.trailing_sits_beside_short_titles_and_is_right_aligned()
  local list, calls, width = fake()
  list.draw({ id = "refs", items = { ROWS[2] } })
  local button = calls.buttons[1]
  local menu = calls.menus[1]
  equal(menu.x + 28, 12 + width, "menu ends at the content edge")
  equal(button.x + #"Detach..." * CHAR + 24 + 8, menu.x, "action then gap then menu")
  equal(button.options.size, "compact", "compact row action")
  equal(menu.options.size, "compact", "compact menu trigger")
end

function tests.trailing_wraps_under_long_title_at_320()
  local list, calls, width = fake()
  local title = string.rep("Long reference name ", 4)
  list.draw({ id = "refs", items = { { kind = "row", id = "long", title = title,
    status = { role = "warning", text = "Changed" }, action = { id = "review", label = "Review" } } } })
  assert(calls.texts[1].lines > 1, "title wraps")
  local button = calls.buttons[1]
  equal(button.x + #"Review" * CHAR + 24, 12 + width, "trailing right aligned on its own line")
  for _, x in ipairs(calls.set_x) do assert(x <= 12 + width, "nothing beyond the content width") end
  local status = calls.statuses[1]
  equal(status.presentation, "inline", "inline status")
end

function tests.compact_rejects_detail()
  local list = fake()
  assert(not pcall(function()
    list.draw({ id = "refs", variant = "compact", items = { ROWS[2] } })
  end), "detail rejected")
end

function tests.compact_rows_use_compact_height()
  local list, calls = fake()
  list.draw({ id = "names", variant = "compact", items = {
    { kind = "row", id = "a", title = "Trailer_Main.rpp", action = { id = "detach", label = "Detach...", variant = "quiet" } },
  } })
  equal(calls.children[1].height, 32, "compact row")
end

function tests.group_labels_render_between_rows()
  local list, calls = fake()
  list.draw({ id = "refs", items = { ROWS[1], { kind = "group", label = "Dialogue" }, ROWS[2] } })
  local label
  for _, text in ipairs(calls.texts) do if text.text == "Dialogue" and text.role == "body" then label = text end end
  assert(label, "group label in body font")
  equal(calls.children[2].y > calls.children[1].y + calls.children[1].height + 8, true, "label sits between rows")
  equal(#calls.trees, 0, "plain groups do not collapse")
end

local function text_named(calls, value)
  for _, text in ipairs(calls.texts) do if text.text == value then return text end end
end

local GROUPED = {
  { kind = "group", id = "tracks", label = "Tracks", count = 2, collapsible = true, collapsed = true },
  { kind = "row", id = "a", title = "Kick" },
  { kind = "row", id = "b", title = "Snare" },
  { kind = "group", id = "regions", label = "Region", count = 1, collapsible = true },
  { kind = "row", id = "c", title = "Scene 1" },
}

function tests.group_header_shows_count_then_noun_in_body()
  local list, calls = fake()
  list.draw({ id = "refs", items = { { kind = "group", id = "tracks", label = "Tracks", count = 3,
    collapsible = true } } })
  local count, noun = text_named(calls, "3"), text_named(calls, "Tracks")
  equal(count.role, "body", "count font")
  equal(count.color, "semantic.color.text.primary", "count color")
  equal(noun.role, "body", "noun font")
  equal(noun.color, "semantic.color.text.secondary", "noun color")
  equal(noun.y, count.y, "count and noun share the line")
  assert(noun.x > count.x, "noun follows the count")
  equal(count.x, 20, "header text starts after the disclosure arrow")
  equal(calls.trees[1].requested, true, "expanded unless collapsed")
end

function tests.collapsed_group_hides_only_its_rows()
  local list, calls = fake()
  local result = list.draw({ id = "refs", items = GROUPED })
  equal(#calls.children, 1, "only the expanded group's row")
  equal(calls.children[1].id, "##refs-c", "the region row")
  equal(calls.trees[1].requested, false, "collapsed group requested closed")
  equal(result.toggled_group, nil, "nothing toggled")
end

function tests.toggling_a_group_reports_it()
  local list = fake({ toggle = true })
  local result = list.draw({ id = "refs", items = { GROUPED[1], GROUPED[2] } })
  equal(result.toggled_group, "tracks", "toggled group")
  equal(result.events[1].type, "list.group_toggled", "event type")
  equal(result.events[1].id, "refs", "list id")
  equal(result.events[1].group, "tracks", "event group")
end

function tests.trailing_text_sits_beside_the_title()
  local list, calls, width = fake()
  list.draw({ id = "refs", variant = "compact", items = {
    { kind = "row", id = "a", title = "Kick", trailing_text = "2 Items" },
  } })
  local trailing = text_named(calls, "2 Items")
  equal(trailing.role, "metadata", "trailing text font")
  equal(trailing.color, "semantic.color.text.secondary", "trailing text color")
  equal(trailing.x + #"2 Items" * CHAR, 12 + width, "right aligned")
  equal(trailing.y, text_named(calls, "Kick").y, "beside the title")
end

function tests.collapsible_group_requires_id()
  local list = fake()
  assert(not pcall(function()
    list.draw({ id = "refs", items = { { kind = "group", label = "Tracks", collapsible = true } } })
  end), "id required")
end

function tests.list_ends_with_an_item_without_moving_the_cursor()
  local list, calls = fake()
  list.draw({ id = "refs", items = { ROWS[1], ROWS[2] } })
  local last = calls.children[#calls.children]
  equal(calls.last, "dummy 0x0", "list ends with an item, not a cursor move")
  equal(calls.cursor_y(), last.y + last.height + 8, "cursor after the last row")
end

function tests.row_action_and_menu_events()
  local list = fake({ click = "Detach...", menu_choice = nil })
  local result = list.draw({ id = "refs", items = { ROWS[2] } })
  equal(result.action.row, "dialogue", "action row")
  equal(result.action.id, "detach", "action id")
  equal(result.events[1].type, "list.row_action", "event type")
  equal(result.events[1].action, "detach", "event action")
  local menu_list = fake({ menu_choice = "rename" })
  local menu_result = menu_list.draw({ id = "refs", items = { ROWS[2] } })
  equal(menu_result.action.id, "rename", "menu item")
end

function tests.disabled_row_action_never_emits()
  local list = fake({ click = "Detach..." })
  local result = list.draw({ id = "refs", items = { { kind = "row", id = "d", title = "Dialogue",
    action = { id = "detach", label = "Detach...", disabled = true } } } })
  equal(#result.events, 0, "no events")
  equal(result.action, nil, "no action")
end

function tests.empty_list_renders_nothing_and_emits_nothing()
  local list, calls = fake()
  local result = list.draw({ id = "refs", items = {} })
  equal(#calls.children, 0, "no rows")
  equal(#calls.texts, 0, "no text")
  equal(#result.events, 0, "no events")
  equal(result.toggled_group, nil, "not toggled")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
