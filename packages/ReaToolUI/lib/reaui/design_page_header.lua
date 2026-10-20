local button_module = require("reaui.design_button")
local layout_module = require("reaui.design_layout")

local M = {}

local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

local function optional_string(value, name)
  if value ~= nil then required_string(value, name) end
end

function M.create(ImGui, ctx, adapter, deps)
  deps = deps or {}
  local button = deps.button or button_module.create(ImGui, ctx, adapter)
  local layout = deps.layout or layout_module.create(ImGui, ctx, adapter)
  local component = {}

  local function resolve(id) return adapter.resolve(id) end
  local function with_text(role, renderer)
    if adapter.with_text then return adapter.with_text(role, renderer) end
    return renderer()
  end
  local function text_width(role, text)
    return with_text(role, function() return ImGui.CalcTextSize(ctx, text) end)
  end
  local function line_height(role)
    return with_text(role, function() return ImGui.GetTextLineHeight(ctx) end)
  end

  local function validate(options)
    required_string(options.id, "page header id")
    required_string(options.title, "page header title")
    optional_string(options.badge, "page header badge")
    optional_string(options.meta, "page header meta")
    optional_string(options.summary, "page header summary")
    optional_string(options.back_label, "page header back_label")
    if options.actions ~= nil and type(options.actions) ~= "table" then
      error("page header actions must be a table")
    end
    for _, action in ipairs(options.actions or {}) do
      required_string(action.id, "page header action id")
      required_string(action.label, "page header action label")
      optional_string(action.icon, "page header action icon")
      if action.icon_only and not action.icon then error("page header icon_only action needs an icon") end
    end
  end

  local function draw_badge(text, row_y, row_height)
    local padding_x = resolve("semantic.space.inset.padding_x") / 2
    local padding_y = resolve("semantic.space.inset.padding_y") / 2
    local width = text_width("metadata", text) + padding_x * 2
    local height = line_height("metadata") + padding_y * 2
    ImGui.SetCursorPosY(ctx, row_y + (row_height - height) / 2)
    local x, y = ImGui.GetCursorScreenPos(ctx)
    local draw_list = ImGui.GetWindowDrawList(ctx)
    ImGui.DrawList_AddRect(draw_list, x, y, x + width, y + height, resolve("semantic.color.border.subtle"),
      resolve("semantic.radius.control"), 0, resolve("semantic.border.control.width"))
    with_text("metadata", function()
      ImGui.DrawList_AddText(draw_list, x + padding_x, y + padding_y, resolve("semantic.color.text.secondary"), text)
    end)
    ImGui.Dummy(ctx, width, height)
  end

  function component.draw(options)
    options = options or {}
    validate(options)
    local result = { events = {}, action = nil, back_requested = false }
    local _, spacing_y = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
    local row_x, row_y = ImGui.GetCursorPosX(ctx), ImGui.GetCursorPosY(ctx)
    local available = ImGui.GetContentRegionAvail(ctx)
    local collapsed = available < resolve("semantic.layout.page_header.collapse_below")
    local row_height = resolve("semantic.size.control.medium")
    local inline = resolve("semantic.space.inline.default")
    local gap = layout.gap()
    local bottom = row_y + row_height
    local function track() bottom = math.max(bottom, ImGui.GetCursorPosY(ctx) - spacing_y) end

    local parts, trailing_width = {}, 0
    local function add(part)
      trailing_width = trailing_width + (#parts > 0 and gap or 0) + part.width
      table.insert(parts, part)
    end
    if options.meta and not collapsed then add({ kind = "meta", width = text_width("label", options.meta) }) end
    for _, action in ipairs(options.actions or {}) do
      local icon = action.icon ~= nil and (collapsed or action.icon_only == true)
      add({ kind = icon and "icon" or "button", action = action,
        width = icon and layout.icon_button_width() or layout.button_width(action.label) })
    end

    ImGui.BeginGroup(ctx)
    if options.back_label then
      ImGui.SetCursorPosY(ctx, row_y)
      if button.draw_icon({ id = options.id .. "-back", icon = "back", accessible_label = options.back_label,
          variant = "quiet", disabled = options.back_disabled }) and not options.back_disabled then
        result.back_requested = true
        table.insert(result.events, { type = "page_header.back_requested", id = options.id })
      end
      ImGui.SameLine(ctx, 0, inline)
    end
    local title_x = ImGui.GetCursorPosX(ctx)
    -- The title wraps before the badge so the badge never leaves the row.
    local badge_space = 0
    if options.badge then
      badge_space = inline + text_width("metadata", options.badge) + resolve("semantic.space.inset.padding_x")
    end
    with_text("title", function()
      ImGui.SetCursorPosY(ctx, row_y + (row_height - ImGui.GetTextLineHeight(ctx)) / 2)
      ImGui.PushTextWrapPos(ctx, row_x + available - badge_space)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, resolve("semantic.color.text.primary"))
      ImGui.TextWrapped(ctx, options.title)
      ImGui.PopStyleColor(ctx)
      ImGui.PopTextWrapPos(ctx)
    end)
    if options.badge then
      ImGui.SameLine(ctx, 0, inline)
      draw_badge(options.badge, row_y, row_height)
    end
    ImGui.EndGroup(ctx)
    track()

    if #parts > 0 then
      local moved = layout.trailing(trailing_width)
      local base = moved and ImGui.GetCursorPosY(ctx) or row_y
      for index, part in ipairs(parts) do
        if index > 1 then ImGui.SameLine(ctx, 0, gap) end
        if part.kind == "meta" then
          with_text("label", function()
            ImGui.SetCursorPosY(ctx, base + (row_height - ImGui.GetTextLineHeight(ctx)) / 2)
            ImGui.PushStyleColor(ctx, ImGui.Col_Text, resolve("semantic.color.text.secondary"))
            ImGui.Text(ctx, options.meta)
            ImGui.PopStyleColor(ctx)
          end)
        else
          ImGui.SetCursorPosY(ctx, base)
          local action = part.action
          local variant = action.variant or "secondary"
          local event
          if part.kind == "icon" then
            -- Icon buttons have no primary variant.
            event = button.draw_icon({ id = options.id .. "-" .. action.id, icon = action.icon,
              accessible_label = action.label, variant = variant == "primary" and "secondary" or variant,
              disabled = action.disabled })
          else
            event = button.draw({ id = options.id .. "-" .. action.id, label = action.label,
              variant = variant, disabled = action.disabled })
          end
          if event and not action.disabled then
            result.action = action.id
            table.insert(result.events, { type = "page_header.action_selected", id = options.id, action = action.id })
          end
        end
        track()
      end
    end

    if options.summary then
      ImGui.SetCursorPosY(ctx, bottom + spacing_y)
      ImGui.SetCursorPosX(ctx, title_x)
      with_text("label", function()
        ImGui.PushTextWrapPos(ctx, row_x + available)
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, resolve("semantic.color.text.secondary"))
        ImGui.TextWrapped(ctx, options.summary)
        ImGui.PopStyleColor(ctx)
        ImGui.PopTextWrapPos(ctx)
      end)
      track()
    end

    -- ImGui rejects a window that ends on SetCursorPos, so the gap ends on an item.
    ImGui.SetCursorPosY(ctx, bottom - spacing_y + resolve(collapsed and "semantic.space.header.gap_below_compact" or
      "semantic.space.header.gap_below"))
    ImGui.Dummy(ctx, 0, 0)
    return result
  end

  return component
end

return M
