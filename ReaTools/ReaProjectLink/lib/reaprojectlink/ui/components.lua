-- Product composition and compatibility helpers for ReaProjectLink.
-- Supported controls delegate to ReaToolUI. Toast, Lane mapping rows with the
-- grouped dropdown, and virtualized lists remain local by design.
local M = {}

local CHILD_ALWAYS_USE_PADDING = 2
local CHILD_AUTO_RESIZE_Y = 32

local function split_label(label)
  local visible, hidden = label:match("^(.-)##(.+)$")
  return visible or label, hidden or label:gsub("[^%w]+", "-"):lower()
end

function M.create(ImGui, ctx, design_system)
  local adapter = design_system.adapter
  local shared = design_system.components
  local patterns = design_system.patterns
  local c = {}
  local pages = {}
  local toast_height = 64
  local confirmation
  local list_clipper = ImGui.CreateListClipper(ctx)
  ImGui.Attach(ctx, list_clipper)

  local function resolve(id) return adapter.resolve(id) end
  local function with_text(role, renderer) return adapter.with_text(role, renderer) end
  local function secondary(renderer)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, resolve("semantic.color.text.secondary"))
    renderer()
    ImGui.PopStyleColor(ctx)
  end

  function c.colored(text, color)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, color)
    ImGui.TextWrapped(ctx, text)
    ImGui.PopStyleColor(ctx)
  end
  function c.small(text)
    secondary(function() with_text("metadata", function() ImGui.TextWrapped(ctx, text) end) end)
  end
  function c.muted(text)
    secondary(function() with_text("body", function() ImGui.TextWrapped(ctx, text) end) end)
  end

  function c.button(label, kind)
    local visible, id = split_label(label)
    return shared.button.draw({ id = "product-" .. id, label = visible,
      variant = kind == "primary" and "primary" or "secondary" }) ~= nil
  end

  -- The next item starts `token` below the previous one. Ends on an item so a
  -- container may close right after it.
  local function gap(token)
    local _, spacing_y = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
    ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) - spacing_y * 2 + resolve(token))
    ImGui.Dummy(ctx, 0, 0)
  end
  function c.block_gap() gap("semantic.space.block.gap") end
  function c.list_gap() gap("semantic.space.list.gap") end

  -- Inset row with title and detail on the left and `draw_control()` on the
  -- right; the control moves under the text when the row is narrow. Returns
  -- `draw_control()`'s result.
  function c.mapping_row(id, title, detail, draw_control)
    ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, resolve("component.list_row.background"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildRounding, resolve("semantic.radius.control"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,
      resolve("semantic.space.inset.padding_x"), resolve("semantic.space.inset.padding_y"))
    local visible = ImGui.BeginChild(ctx, "##mapping-" .. id, 0, 0,
      CHILD_ALWAYS_USE_PADDING | CHILD_AUTO_RESIZE_Y, ImGui.WindowFlags_NoScrollbar)
    ImGui.PopStyleVar(ctx, 2)
    ImGui.PopStyleColor(ctx)
    if not visible then return nil end
    local available = ImGui.GetContentRegionAvail(ctx)
    local control_width = resolve("semantic.size.field.inline_compact")
    local control_gap = resolve("semantic.space.control.gap")
    local beside = available >= resolve("semantic.size.field.inline_wide")
    local left, top = ImGui.GetCursorPosX(ctx), ImGui.GetCursorPosY(ctx)
    ImGui.PushTextWrapPos(ctx, beside and left + available - control_width - control_gap or 0)
    ImGui.BeginGroup(ctx)
    ImGui.TextWrapped(ctx, title)
    if detail then c.small(detail) end
    ImGui.EndGroup(ctx)
    ImGui.PopTextWrapPos(ctx)
    if beside then
      local _, text_height = ImGui.GetItemRectSize(ctx)
      ImGui.SameLine(ctx, left + available - control_width)
      ImGui.SetCursorPosY(ctx, top + math.max(0, (text_height - ImGui.GetFrameHeight(ctx)) / 2))
    end
    local result = draw_control()
    ImGui.EndChild(ctx)
    return result
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
  -- above_review_footer keeps the toast off the Review Shell footer actions.
  function c.toast_overlay(toast, above_review_footer)
    local window_x, window_y = ImGui.GetWindowPos(ctx)
    local window_width, window_height = ImGui.GetWindowSize(ctx)
    local margin = resolve("semantic.space.section.default")
    local inset = above_review_footer and resolve("component.review_shell.footer.height") or 0
    local width = math.min(window_width - margin * 2, resolve("semantic.layout.toast.max_width"))
    ImGui.SetCursorScreenPos(ctx, window_x + window_width - margin - width,
      math.max(window_y + margin, window_y + window_height - margin - inset - toast_height))
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
    ImGui.PushStyleColor(ctx, ImGui.Col_Button, resolve("component.dropdown.background.default"))
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, resolve("component.dropdown.background.hover"))
    ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, resolve("component.dropdown.background.pressed"))
    local padding_x = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, padding_x,
      (resolve("semantic.size.control.medium") - ImGui.GetFontSize(ctx)) / 2)
    -- The option popup would otherwise inherit the page padding.
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,
      resolve("semantic.space.inset.padding_x"), resolve("semantic.space.inset.padding_y"))
    if ImGui.BeginCombo(ctx, "##" .. id, preview) then
      for index, option in ipairs(options) do
        if option.separator then ImGui.Separator(ctx)
        elseif option.header then
          secondary(function() with_text("metadata", function() ImGui.Text(ctx, option.header) end) end)
        elseif ImGui.Selectable(ctx, option.label .. "##" .. id .. "-" .. index, false) then chosen = option end
      end
      ImGui.EndCombo(ctx)
    end
    ImGui.PopStyleVar(ctx, 2)
    ImGui.PopStyleColor(ctx, 8)
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

  function c.clipped(count, draw_row)
    ImGui.ListClipper_Begin(list_clipper, count)
    while ImGui.ListClipper_Step(list_clipper) do
      local first, last = ImGui.ListClipper_GetDisplayRange(list_clipper)
      for index = first + 1, last do draw_row(index) end
    end
  end

  function c.begin_page(id, centered)
    local available = ImGui.GetContentRegionAvail(ctx)
    local width = math.min(available, resolve("semantic.layout.content.max_width"))
    if centered then ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (available - width) / 2) end
    ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, resolve("semantic.color.surface.canvas"))
    local visible = ImGui.BeginChild(ctx, "##page-" .. id, width, 0)
    ImGui.PopStyleColor(ctx)
    table.insert(pages, visible)
    return visible
  end
  function c.end_page() if table.remove(pages) then ImGui.EndChild(ctx) end end

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

return M
