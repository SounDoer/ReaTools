-- Product composition and compatibility helpers for ReaProjectLink.
-- Supported controls delegate to ReaToolUI. Product-only value rows, Toast,
-- complex mapping rows, and virtualized lists remain local by design.
local icons = require("reaprojectlink.ui.icons")

local M = {}

local CHILD_BORDER = 1
local CHILD_ALWAYS_USE_PADDING = 2
local CHILD_AUTO_RESIZE_Y = 32
local CARD_FLAGS = CHILD_BORDER | CHILD_ALWAYS_USE_PADDING | CHILD_AUTO_RESIZE_Y
local VALUE_COLUMN = 130
local STACK_BELOW = 560
local TOAST_MAX_WIDTH = 520
local LEVEL_TOKEN = {
  neutral = "component.status.neutral.foreground",
  ready = "component.status.ready.foreground",
  warning = "component.status.warning.foreground",
  blocked = "component.status.blocked.foreground",
}
local LEVEL_LABEL = { neutral = "Info", ready = "Ready", warning = "Attention", blocked = "Blocked" }

local function split_label(label)
  local visible, hidden = label:match("^(.-)##(.+)$")
  return visible or label, hidden or label:gsub("[^%w]+", "-"):lower()
end

function M.create(ImGui, ctx, design_system)
  local adapter = design_system.adapter
  local shared = design_system.components
  local patterns = design_system.patterns
  local c = {}
  local cards, pages = {}, {}
  local toast_height = 64
  local confirmation

  local function resolve(id) return adapter.resolve(id) end
  local function with_text(role, renderer) return adapter.with_text(role, renderer) end
  local function secondary(renderer)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, resolve("semantic.color.text.secondary"))
    renderer()
    ImGui.PopStyleColor(ctx)
  end
  local function level_color(level) return resolve(LEVEL_TOKEN[level] or LEVEL_TOKEN.neutral) end

  function c.title(text) with_text("title", function() ImGui.Text(ctx, text) end) end
  function c.heading(text) with_text("heading", function() ImGui.Text(ctx, text) end) end
  function c.colored(text, color)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, color)
    ImGui.TextWrapped(ctx, text)
    ImGui.PopStyleColor(ctx)
  end
  function c.muted(text) secondary(function() ImGui.TextWrapped(ctx, text) end) end
  function c.small(text)
    secondary(function() with_text("metadata", function() ImGui.TextWrapped(ctx, text) end) end)
  end
  function c.inline_muted(text)
    secondary(function() with_text("metadata", function() ImGui.Text(ctx, text) end) end)
  end
  function c.text_width(role, text)
    return with_text(role, function() return ImGui.CalcTextSize(ctx, text) end)
  end
  function c.section(text)
    ImGui.Dummy(ctx, 0, resolve("semantic.space.section.loose"))
    c.heading(text)
  end
  function c.key_value(label, value)
    secondary(function() with_text("label", function() ImGui.Text(ctx, label) end) end)
    ImGui.SameLine(ctx, VALUE_COLUMN)
    ImGui.TextWrapped(ctx, tostring(value))
  end
  function c.value_row(label, value)
    ImGui.AlignTextToFramePadding(ctx)
    c.key_value(label, value)
  end
  function c.copy_value(id, label, value)
    ImGui.AlignTextToFramePadding(ctx)
    secondary(function() with_text("label", function() ImGui.Text(ctx, label) end) end)
    ImGui.SameLine(ctx, VALUE_COLUMN)
    if shared.button.draw({ id = "copy-" .. id, label = "Copy", variant = "secondary" }) then
      ImGui.SetClipboardText(ctx, tostring(value))
    end
    ImGui.SameLine(ctx)
    ImGui.TextWrapped(ctx, tostring(value))
  end

  function c.icon(name, color, size)
    size = size or resolve("semantic.size.icon.medium")
    local x, y = ImGui.GetCursorScreenPos(ctx)
    icons.draw(ImGui, ImGui.GetWindowDrawList(ctx), name, x, y, size,
      color or resolve("semantic.color.text.primary"))
    ImGui.Dummy(ctx, size, size)
  end
  function c.status(text, level)
    shared.status.draw({ role = level or "neutral", text = text })
  end
  function c.inline_status(text, level)
    ImGui.TextColored(ctx, level_color(level), (LEVEL_LABEL[level] or "Info") .. ": " .. text)
  end
  function c.status_width(text, level)
    return ImGui.CalcTextSize(ctx, (LEVEL_LABEL[level] or "Info") .. ": " .. text)
  end
  function c.badge(text)
    with_text("metadata", function()
      local width, height = ImGui.CalcTextSize(ctx, text)
      local x, y = ImGui.GetCursorScreenPos(ctx)
      local draw_list = ImGui.GetWindowDrawList(ctx)
      local pad = resolve("semantic.space.inline.default")
      ImGui.DrawList_AddRectFilled(draw_list, x, y, x + width + pad * 2, y + height + 4,
        resolve("semantic.color.selection.default"), resolve("semantic.radius.control"))
      ImGui.DrawList_AddText(draw_list, x + pad, y + 2,
        resolve("semantic.color.text.primary"), text)
      ImGui.Dummy(ctx, width + pad * 2, height + 4)
    end)
  end

  function c.button(label, kind)
    local visible, id = split_label(label)
    return shared.button.draw({ id = "product-" .. id, label = visible,
      variant = kind == "primary" and "primary" or "secondary" }) ~= nil
  end
  function c.disabled_button(label)
    local visible, id = split_label(label)
    shared.button.draw({ id = "product-" .. id, label = visible, variant = "secondary", disabled = true })
  end
  function c.button_width(label)
    local visible = split_label(label)
    return ImGui.CalcTextSize(ctx, visible) + resolve("semantic.space.control.padding_x") * 2
  end
  function c.icon_button(id, name, tooltip)
    return shared.button.draw_icon({ id = id, icon = name, accessible_label = tooltip or name,
      variant = "quiet" }) ~= nil
  end
  function c.same_line_right(width)
    ImGui.SameLine(ctx)
    local available = ImGui.GetContentRegionAvail(ctx)
    if available < width then ImGui.NewLine(ctx); available = ImGui.GetContentRegionAvail(ctx) end
    ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + math.max(0, available - width))
  end
  function c.card_width()
    local available = ImGui.GetContentRegionAvail(ctx)
    if available < STACK_BELOW then return 0, false end
    local gap = resolve("semantic.space.stack.default")
    return (available - gap) / 2, true
  end

  function c.begin_card(id, width, highlighted)
    ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, resolve("component.card.background"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Border, resolve(
      highlighted and "component.card.border.emphasized" or "component.card.border.default"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildBorderSize, resolve(
      highlighted and "semantic.border.emphasis.width" or "semantic.border.control.width"))
    local padding = resolve("semantic.space.container.padding")
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, padding, padding)
    local visible = ImGui.BeginChild(ctx, "##card-" .. id, width or 0, 0, CARD_FLAGS)
    ImGui.PopStyleVar(ctx, 2)
    ImGui.PopStyleColor(ctx, 2)
    table.insert(cards, visible)
    return visible
  end
  function c.end_card() if table.remove(cards) then ImGui.EndChild(ctx) end end
  function c.card_header(icon, title)
    c.icon(icon, resolve("semantic.color.text.secondary"))
    ImGui.SameLine(ctx, 0, resolve("semantic.space.inline.default"))
    c.heading(title)
  end
  function c.menu(id, entries, align_right)
    if align_right ~= false then c.same_line_right(resolve("semantic.size.control.medium")) end
    local items = {}
    for _, entry in ipairs(entries) do
      table.insert(items, entry.separator and { separator = true } or {
        id = entry.id, label = entry.label, disabled = entry.disabled, danger = entry.danger,
      })
    end
    return shared.menu.draw({ id = id, items = items }).action
  end

  function c.notice(id, level, text, actions)
    local action_options = {}
    for index, label in ipairs(actions or {}) do
      table.insert(action_options, { id = tostring(index), label = label })
    end
    local result = shared.notice.draw({ id = id, role = level or "neutral", text = text,
      actions = action_options })
    return result.action and tonumber(result.action) or nil
  end
  function c.toast_overlay(toast)
    local window_x, window_y = ImGui.GetWindowPos(ctx)
    local window_width, window_height = ImGui.GetWindowSize(ctx)
    local margin = resolve("semantic.space.section.default")
    local width = math.min(window_width - margin * 2, TOAST_MAX_WIDTH)
    ImGui.SetCursorScreenPos(ctx, window_x + window_width - margin - width,
      math.max(window_y + margin, window_y + window_height - margin - toast_height))
    local chosen = c.notice("toast", toast.is_error and "blocked" or "ready", toast.text,
      toast.is_error and { "Dismiss" } or nil)
    local _, height = ImGui.GetItemRectSize(ctx)
    if height and height > 0 then toast_height = height end
    return chosen == 1
  end

  -- Product compatibility for grouped Lane mapping options. The shared
  -- Dropdown intentionally supports a flat option set only.
  function c.dropdown(id, preview, options)
    local chosen
    ImGui.SetNextItemWidth(ctx, -1)
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg, resolve("component.dropdown.background.default"))
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered, resolve("component.dropdown.background.hover"))
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive, resolve("component.dropdown.background.pressed"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, resolve("component.dropdown.foreground.default"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Border, resolve("component.dropdown.border.default"))
    if ImGui.BeginCombo(ctx, "##" .. id, preview) then
      for index, option in ipairs(options) do
        if option.separator then ImGui.Separator(ctx)
        elseif option.header then c.inline_muted(option.header)
        elseif ImGui.Selectable(ctx, option.label .. "##" .. id .. "-" .. index, false) then chosen = option end
      end
      ImGui.EndCombo(ctx)
    end
    ImGui.PopStyleColor(ctx, 5)
    return chosen
  end
  function c.segmented(id, options, selected)
    local normalized, values = {}, {}
    for index, option in ipairs(options) do
      local option_id = tostring(option.id)
      normalized[index] = { id = option_id, label = option.label }
      values[option_id] = option.id
    end
    local result = shared.segmented_control.draw({
      id = id,
      options = normalized,
      value = tostring(selected),
    })
    return values[result.value]
  end

  function c.begin_group(id, label, detail, level, default_open)
    local flags = ImGui.TreeNodeFlags_SpanAvailWidth
    if default_open then flags = flags | ImGui.TreeNodeFlags_DefaultOpen end
    local open = ImGui.TreeNodeEx(ctx, "##group-" .. id, label, flags)
    if detail then
      c.same_line_right(ImGui.CalcTextSize(ctx, detail))
      ImGui.TextColored(ctx, level_color(level), detail)
    end
    return open
  end
  function c.end_group() ImGui.TreePop(ctx) end
  function c.clipped(count, draw_row)
    local clipper = ImGui.CreateListClipper(ctx)
    ImGui.ListClipper_Begin(clipper, count)
    while ImGui.ListClipper_Step(clipper) do
      local first, last = ImGui.ListClipper_GetDisplayRange(clipper)
      for index = first + 1, last do draw_row(index) end
    end
  end

  function c.begin_page(id, has_footer)
    local available = ImGui.GetContentRegionAvail(ctx)
    local width = math.min(available, resolve("semantic.layout.content.max_width"))
    local footer_height = has_footer and -resolve("semantic.size.footer.medium") or 0
    ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, resolve("semantic.color.surface.canvas"))
    local visible = ImGui.BeginChild(ctx, "##page-" .. id, width, footer_height)
    ImGui.PopStyleColor(ctx)
    table.insert(pages, { visible = visible, width = width, id = id })
    return visible
  end
  function c.end_page()
    local page = table.remove(pages)
    if page.visible then ImGui.EndChild(ctx) end
    return page
  end
  function c.review_header(title, summary)
    return patterns.review_header.draw({ id = "page", title = title, summary = summary }).back_requested
  end
  function c.footer(page, summary, level, label, enabled)
    ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, resolve("semantic.color.surface.canvas"))
    local visible = ImGui.BeginChild(ctx, "##footer-" .. page.id, page.width, 0, 0,
      ImGui.WindowFlags_NoScrollbar)
    ImGui.PopStyleColor(ctx)
    local clicked = false
    if visible then
      clicked = patterns.review_footer.draw({ id = page.id, summary = summary,
        role = level or "neutral", complete_label = label, enabled = enabled }).complete_requested
      ImGui.EndChild(ctx)
    end
    return clicked
  end
  function c.stale(title, text, label)
    ImGui.Dummy(ctx, 0, resolve("semantic.space.region.default"))
    return patterns.stale_review.draw({ id = "current-review", title = title,
      message = text, refresh_label = label }).refresh_requested
  end

  function c.request_confirmation(options, on_confirm)
    if confirmation then return false end
    confirmation = { options = options, on_confirm = on_confirm }
    return true
  end
  function c.draw_confirmation()
    if not confirmation then return end
    local pending = confirmation
    local options = {}
    for key, value in pairs(pending.options) do options[key] = value end
    options.open = true
    local result = patterns.confirmation_dialog.draw(options)
    if result.action == "confirmed" then
      confirmation = nil
      pending.on_confirm()
    elseif result.action == "cancelled" then
      confirmation = nil
    end
  end

  return c
end

function M.create_settings_compat(ImGui, ctx, design_system)
  local adapter = design_system.adapter
  local button = design_system.components.button
  local compat = {}
  local pages = {}
  local function with_text(role, renderer) return adapter.with_text(role, renderer) end
  local function secondary(renderer)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, adapter.resolve("semantic.color.text.secondary"))
    renderer()
    ImGui.PopStyleColor(ctx)
  end
  function compat.begin_page(id)
    local width = math.min(ImGui.GetContentRegionAvail(ctx),
      adapter.resolve("semantic.layout.content.max_width"))
    ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, adapter.resolve("semantic.color.surface.canvas"))
    local visible = ImGui.BeginChild(ctx, "##page-" .. id, width, 0)
    ImGui.PopStyleColor(ctx)
    table.insert(pages, visible)
    return visible
  end
  function compat.end_page() if table.remove(pages) then ImGui.EndChild(ctx) end end
  function compat.section(label)
    ImGui.Dummy(ctx, 0, adapter.resolve("semantic.space.section.loose"))
    with_text("heading", function() ImGui.Text(ctx, label) end)
  end
  function compat.copy_value(id, label, value)
    ImGui.AlignTextToFramePadding(ctx)
    secondary(function() with_text("label", function() ImGui.Text(ctx, label) end) end)
    ImGui.SameLine(ctx, VALUE_COLUMN)
    if button.draw({ id = "settings-copy-" .. id, label = "Copy", variant = "secondary" }) then
      ImGui.SetClipboardText(ctx, tostring(value))
    end
    ImGui.SameLine(ctx)
    ImGui.TextWrapped(ctx, tostring(value))
  end
  function compat.key_value(label, value)
    secondary(function() with_text("label", function() ImGui.Text(ctx, label) end) end)
    ImGui.SameLine(ctx, VALUE_COLUMN)
    ImGui.TextWrapped(ctx, tostring(value))
  end
  function compat.explanation(text)
    secondary(function() with_text("metadata", function() ImGui.TextWrapped(ctx, text) end) end)
  end
  return compat
end

return M
