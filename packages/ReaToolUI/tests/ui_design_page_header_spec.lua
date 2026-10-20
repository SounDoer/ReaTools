local module = require("reaui.design_page_header")
local layout_module = require("reaui.design_layout")

local function equal(actual, expected, label)
  if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local TOKENS = {
  ["semantic.layout.page_header.collapse_below"] = 560,
  ["semantic.space.header.gap_below"] = 20,
  ["semantic.space.header.gap_below_compact"] = 16,
  ["semantic.space.inline.default"] = 12,
  ["semantic.space.inset.padding_x"] = 12,
  ["semantic.space.inset.padding_y"] = 8,
  ["semantic.space.control.gap"] = 8,
  ["semantic.space.control.padding_x"] = 12,
  ["semantic.size.control.medium"] = 32,
  ["semantic.radius.control"] = 4,
  ["semantic.border.control.width"] = 1,
}
local CHAR = 7
local LINES = { title = 20, label = 14, body = 16, metadata = 12 }

-- Fake ImGui with a simulated cursor; each item advances by its height plus 8.
local function fake(options)
  options = options or {}
  local width = options.width or 800
  local calls = { texts = {}, buttons = {}, icons = {}, rects = {}, separators = 0, set_x = {},
    colors = 0, popped_colors = 0 }
  local cursor = { x = 0, y = 0 }
  local last = { x = 0, y = 0, w = 0, h = 0 }
  local groups = {}
  local wrap_pos
  local role = "body"
  local function item(w, h)
    last = { x = cursor.x, y = cursor.y, w = w, h = h }
    for _, group in ipairs(groups) do
      group.right = math.max(group.right, cursor.x + w)
      group.bottom = math.max(group.bottom, cursor.y + h)
    end
    cursor.x = 0
    cursor.y = last.y + h + 8
  end
  local ImGui = { Col_Text = 2, StyleVar_ItemSpacing = 5 }
  function ImGui.PushStyleColor() calls.colors = calls.colors + 1 end
  function ImGui.PopStyleColor(_, n) calls.popped_colors = calls.popped_colors + (n or 1) end
  function ImGui.GetStyleVar() return 8, 8 end
  function ImGui.GetCursorPosX() return cursor.x end
  function ImGui.GetCursorPosY() return cursor.y end
  function ImGui.SetCursorPosX(_, x) cursor.x = x; table.insert(calls.set_x, x) end
  function ImGui.SetCursorPosY(_, y) cursor.y = y end
  function calls.cursor_y() return cursor.y end
  function ImGui.GetCursorScreenPos() return cursor.x, cursor.y end
  function ImGui.GetContentRegionAvail() return width - cursor.x, 400 end
  function ImGui.CalcTextSize(_, text) return #text * CHAR, LINES[role] end
  function ImGui.GetTextLineHeight() return LINES[role] end
  function ImGui.PushTextWrapPos(_, x) wrap_pos = x end
  function ImGui.PopTextWrapPos() wrap_pos = nil end
  function ImGui.TextWrapped(_, text)
    local limit = (wrap_pos or width) - cursor.x
    local natural = #text * CHAR
    local lines = math.max(1, math.ceil(natural / limit))
    table.insert(calls.texts, { text = text, role = role, lines = lines, x = cursor.x, y = cursor.y })
    item(math.min(natural, limit), lines * LINES[role])
  end
  function ImGui.Text(_, text)
    table.insert(calls.texts, { text = text, role = role, lines = 1, x = cursor.x, y = cursor.y })
    item(#text * CHAR, LINES[role])
  end
  function ImGui.Dummy(_, w, h) item(w, h) end
  function ImGui.BeginGroup()
    table.insert(groups, { x = cursor.x, y = cursor.y, right = cursor.x, bottom = cursor.y })
  end
  function ImGui.EndGroup()
    local group = table.remove(groups)
    cursor.x, cursor.y = group.x, group.y
    item(group.right - group.x, group.bottom - group.y)
  end
  function ImGui.SameLine(_, _, spacing)
    cursor.x = last.x + last.w + (spacing or 8)
    cursor.y = last.y
  end
  function ImGui.NewLine()
    cursor.x = 0
    cursor.y = last.y + last.h + 8
  end
  function ImGui.Separator() calls.separators = calls.separators + 1 end
  function ImGui.GetWindowDrawList() return "draw_list" end
  function ImGui.DrawList_AddRect(_, x1, y1, x2, y2, color)
    table.insert(calls.rects, { x1 = x1, y1 = y1, x2 = x2, y2 = y2, color = color })
  end
  function ImGui.DrawList_AddText(_, x, y, color, text)
    table.insert(calls.texts, { text = text, role = role, lines = 1, x = x, y = y, color = color })
  end
  local adapter = {
    resolve = function(id) return TOKENS[id] or id end,
    with_text = function(next_role, renderer)
      local previous = role
      role = next_role
      local result = renderer()
      role = previous
      return result
    end,
  }
  local deps = {
    button = {
      draw = function(o)
        table.insert(calls.buttons, { options = o, x = cursor.x, y = cursor.y })
        item(#o.label * CHAR + 24, 32)
        if options.click == o.id then return { type = "button.activated", id = o.id } end
      end,
      draw_icon = function(o)
        table.insert(calls.icons, { options = o, x = cursor.x, y = cursor.y })
        item(32, 32)
        if options.click == o.id then return { type = "button.activated", id = o.id } end
      end,
    },
  }
  deps.layout = layout_module.create(ImGui, "ctx", adapter)
  return module.create(ImGui, "ctx", adapter, deps), calls, width
end

local HEADER = {
  id = "publish", title = "Publish Reference", badge = "r7", meta = "Last checked 2 min ago",
  actions = {
    { id = "check", label = "Check Now", icon = "download" },
    { id = "publish", label = "Publish", variant = "primary" },
  },
}

local function find_text(calls, text)
  for _, entry in ipairs(calls.texts) do if entry.text == text then return entry end end
end

local tests = {}

function tests.header_lays_out_title_badge_meta_and_actions_on_one_row()
  local header, calls, width = fake()
  header.draw(HEADER)
  local title = find_text(calls, "Publish Reference")
  equal(title.role, "title", "title font")
  equal(title.y, (32 - 20) / 2, "title centered on the control row")
  local badge = calls.rects[1]
  equal(badge.color, "semantic.color.border.subtle", "badge outline")
  equal(badge.x2 - badge.x1, #"r7" * CHAR + 12, "badge horizontal padding is half the inset padding")
  equal(find_text(calls, "r7").role, "metadata", "badge font")
  local meta = find_text(calls, "Last checked 2 min ago")
  equal(meta.role, "label", "meta font")
  local publish = calls.buttons[2]
  equal(publish.options.label, "Publish", "text action")
  equal(publish.x + #"Publish" * CHAR + 24, width, "actions end at the content edge")
  equal(publish.y, 0, "actions on the title row")
  equal(calls.buttons[1].options.label, "Check Now", "wide keeps text actions")
  equal(#calls.icons, 0, "no icon buttons when wide")
  equal(calls.colors, calls.popped_colors, "color stack")
end

function tests.header_collapses_text_actions_to_icons_below_560()
  local header, calls = fake({ width = 400 })
  header.draw(HEADER)
  equal(#calls.icons, 1, "icon action collapsed")
  equal(calls.icons[1].options.icon, "download", "action icon")
  equal(calls.icons[1].options.accessible_label, "Check Now", "label becomes accessible label")
  equal(calls.icons[1].options.id, "publish-check", "scoped id")
  equal(#calls.buttons, 1, "actions without icons stay text buttons")
  equal(calls.buttons[1].options.variant, "primary", "variant kept")
end

function tests.header_hides_meta_when_collapsed()
  local wide_header, wide = fake({ width = 560 })
  wide_header.draw(HEADER)
  assert(find_text(wide, "Last checked 2 min ago"), "meta at the breakpoint")
  local header, calls = fake({ width = 559 })
  header.draw(HEADER)
  equal(find_text(calls, "Last checked 2 min ago"), nil, "meta hidden below the breakpoint")
end

function tests.header_never_draws_separator()
  for _, width in ipairs({ 320, 800 }) do
    local header, calls = fake({ width = width })
    header.draw(HEADER)
    equal(calls.separators, 0, "no separator at " .. width)
  end
end

function tests.header_back_requested()
  local header, calls = fake({ click = "publish-back" })
  local result = header.draw({ id = "publish", title = "Publish Reference", back_label = "Back to Main" })
  equal(calls.icons[1].options.icon, "back", "back icon")
  equal(calls.icons[1].options.accessible_label, "Back to Main", "back label")
  equal(calls.icons[1].options.variant, "quiet", "quiet back button")
  equal(result.back_requested, true, "back requested")
  equal(result.events[1].type, "page_header.back_requested", "event type")
  equal(result.events[1].id, "publish", "event id")
  local title = find_text(calls, "Publish Reference")
  equal(title.x, 32 + 12, "title follows the back button")
end

function tests.header_action_event_and_disabled_action()
  local header = fake({ click = "publish-publish" })
  local result = header.draw(HEADER)
  equal(result.action, "publish", "action")
  equal(result.events[1].type, "page_header.action_selected", "event type")
  equal(result.events[1].action, "publish", "event action")
  equal(result.back_requested, false, "no back")
  local disabled = fake({ click = "publish-publish" })
  local blocked = disabled.draw({ id = "publish", title = "Publish", actions = {
    { id = "publish", label = "Publish", variant = "primary", disabled = true } } })
  equal(#blocked.events, 0, "disabled action never emits")
end

function tests.header_gap_below_uses_compact_value_when_collapsed()
  local wide_header, wide = fake({ width = 800 })
  wide_header.draw(HEADER)
  equal(wide.cursor_y(), 32 + 20, "wide gap below the control row")
  local header, calls = fake({ width = 400 })
  header.draw({ id = "publish", title = "Publish", actions = { { id = "check", label = "Check", icon = "download" } } })
  equal(calls.cursor_y(), 32 + 16, "compact gap below")
end

function tests.header_long_title_moves_actions_below_at_320()
  local header, calls, width = fake({ width = 320 })
  header.draw({ id = "publish", title = string.rep("Very long reference title ", 3), badge = "r7",
    actions = { { id = "publish", label = "Publish", variant = "primary" } } })
  local title = calls.texts[1]
  assert(title.lines > 1, "title wraps")
  for _, x in ipairs(calls.set_x) do assert(x <= width, "nothing beyond the content width") end
  assert(calls.rects[1].x2 <= width, "badge stays inside")
  local publish = calls.buttons[1]
  assert(publish.y > 0, "actions moved below the title")
  equal(publish.x + #"Publish" * CHAR + 24, width, "right aligned")
  equal(calls.cursor_y(), publish.y + 32 + 16, "gap measured from the lowest item")
end

function tests.header_summary_sits_under_the_title_before_the_gap()
  local header, calls = fake({ width = 800 })
  header.draw({ id = "review", title = "Publish Reference", back_label = "Back", summary = "4 tracks · 8 markers" })
  local summary = find_text(calls, "4 tracks · 8 markers")
  equal(summary.role, "label", "summary font")
  equal(summary.x, 32 + 12, "summary aligns with the title")
  equal(summary.y, 32 + 8, "summary directly under the control row")
  equal(calls.cursor_y(), summary.y + 14 + 20, "gap below the summary")
end

function tests.header_back_disabled_never_requests()
  local header, calls = fake({ click = "review-back" })
  header.draw({ id = "review", title = "Publish", back_label = "Back", back_disabled = true })
  equal(calls.icons[1].options.disabled, true, "back button disabled")
end

function tests.header_validates_options()
  local header = fake()
  assert(not pcall(function() header.draw({ id = "x" }) end), "title required")
  assert(not pcall(function() header.draw({ title = "x" }) end), "id required")
  assert(not pcall(function() header.draw({ id = "x", title = "x", actions = { { id = "a" } } }) end),
    "action label required")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
