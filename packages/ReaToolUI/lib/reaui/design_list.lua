local button_module = require("reaui.design_button")
local status_module = require("reaui.design_status")
local menu_module = require("reaui.design_menu")
local layout_module = require("reaui.design_layout")

local M = {}

local CHILD_ALWAYS_USE_PADDING = 1 << 1
local VARIANTS = { standard = true, compact = true }

local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter, deps)
  deps = deps or {}
  local button = deps.button or button_module.create(ImGui, ctx, adapter)
  local status = deps.status or status_module.create(ImGui, ctx, adapter)
  local menu = deps.menu or menu_module.create(ImGui, ctx, adapter, button)
  local layout = deps.layout or layout_module.create(ImGui, ctx, adapter)
  local component = {}
  -- Row content heights measured on the previous frame, keyed by row child id.
  local content_heights = {}

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
  local function wrapped(role, color_token, text)
    with_text(role, function()
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, resolve(color_token))
      ImGui.TextWrapped(ctx, text)
      ImGui.PopStyleColor(ctx)
    end)
  end

  local function validate(options)
    required_string(options.id, "list id")
    local variant = options.variant or "standard"
    if not VARIANTS[variant] then error("unsupported list variant " .. tostring(variant)) end
    if type(options.items) ~= "table" then error("list items must be a table") end
    for _, item in ipairs(options.items) do
      if item.kind == "group" then
        required_string(item.label, "list group label")
        if item.collapsible then required_string(item.id, "collapsible list group id") end
        if item.count ~= nil and math.type(item.count) ~= "integer" then error("list group count must be an integer") end
      elseif item.kind == "row" then
        required_string(item.id, "list row id")
        required_string(item.title, "list row title")
        if variant == "compact" and item.detail then error("compact list rows cannot have detail") end
      else
        error("unsupported list item kind " .. tostring(item.kind))
      end
    end
    return variant == "compact"
  end

  local function trailing_parts(row)
    local parts = {}
    if row.trailing_text then
      table.insert(parts, { kind = "text", width = text_width("metadata", row.trailing_text) })
    end
    if row.status then
      table.insert(parts, { kind = "status", width = status.measure({ role = row.status.role, text = row.status.text }) })
    end
    if row.action then table.insert(parts, { kind = "action", width = layout.button_width(row.action.label) }) end
    if row.menu then table.insert(parts, { kind = "menu", width = resolve("semantic.size.control.compact") }) end
    return parts
  end

  local function draw_row_contents(key, row, compact, top, choose)
    local _, spacing_y = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
    local control_height = resolve("semantic.size.control.compact")
    local gap = layout.gap()
    ImGui.SetCursorPosY(ctx, top)
    local left = ImGui.GetCursorPosX(ctx)
    local width = ImGui.GetContentRegionAvail(ctx)
    local parts = trailing_parts(row)
    local trailing_width = 0
    for index, part in ipairs(parts) do trailing_width = trailing_width + part.width + (index > 1 and gap or 0) end

    local body_height = line_height("body")
    local group_height = body_height + (row.detail and spacing_y + line_height("metadata") or 0)
    local text = math.max(text_width("body", row.title), row.detail and text_width("metadata", row.detail) or 0)
    -- Trailing controls sit beside the text only when the text fits on one
    -- line next to them; otherwise they move below the full-width text.
    local beside = #parts > 0 and text <= width - trailing_width - gap
    local line = beside and math.max(group_height, control_height) or group_height
    ImGui.SetCursorPosY(ctx, top + (line - group_height) / 2)
    ImGui.PushTextWrapPos(ctx, left + width)
    ImGui.BeginGroup(ctx)
    wrapped("body", "semantic.color.text.primary", row.title)
    if row.detail then wrapped("metadata", "semantic.color.text.secondary", row.detail) end
    ImGui.EndGroup(ctx)
    ImGui.PopTextWrapPos(ctx)

    if #parts > 0 then
      local moved = layout.trailing(trailing_width)
      local base = moved and ImGui.GetCursorPosY(ctx) or top + (line - control_height) / 2
      for index, part in ipairs(parts) do
        if index > 1 then ImGui.SameLine(ctx, 0, gap) end
        if part.kind == "text" then
          ImGui.SetCursorPosY(ctx, base + (control_height - line_height("metadata")) / 2)
          with_text("metadata", function()
            ImGui.PushStyleColor(ctx, ImGui.Col_Text, resolve("semantic.color.text.secondary"))
            ImGui.TextWrapped(ctx, row.trailing_text)
            ImGui.PopStyleColor(ctx)
          end)
        elseif part.kind == "status" then
          ImGui.SetCursorPosY(ctx, base + (control_height - body_height) / 2)
          status.draw({ role = row.status.role, text = row.status.text, presentation = "inline" })
        elseif part.kind == "action" then
          ImGui.SetCursorPosY(ctx, base)
          local action = row.action
          local event = button.draw({
            id = key .. "-" .. action.id, label = action.label, variant = action.variant or "secondary",
            disabled = action.disabled, size = "compact",
          })
          if event and not action.disabled then choose(action.id) end
        else
          ImGui.SetCursorPosY(ctx, base)
          local chosen = menu.draw({
            id = key .. "-menu", accessible_label = row.menu.accessible_label, items = row.menu.items,
            size = "compact",
          }).action
          if chosen then choose(chosen) end
        end
      end
    end
    content_heights[key] = ImGui.GetCursorPosY(ctx) - spacing_y - top
  end

  local function draw_row(key, row, compact, choose)
    local control_height = resolve("semantic.size.control.compact")
    local padding_x = resolve("semantic.space.inset.padding_x")
    local padding_y = resolve("semantic.space.inset.padding_y")
    local minimum = resolve(row.detail and "semantic.size.row.double" or "semantic.size.row.single")
    if compact then
      minimum = resolve("semantic.size.row.compact")
      padding_y = math.max(0, (minimum - control_height) / 2)
    end
    local previous = content_heights[key]
    local height = math.max((previous or 0) + padding_y * 2, minimum)

    ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, resolve("component.list_row.background"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildRounding, resolve("semantic.radius.control"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, padding_x, padding_y)
    local visible = ImGui.BeginChild(ctx, "##" .. key, 0, height, CHILD_ALWAYS_USE_PADDING,
      ImGui.WindowFlags_NoScrollbar)
    ImGui.PopStyleVar(ctx, 2)
    ImGui.PopStyleColor(ctx)
    if not visible then return end
    -- Whole pixels: ImGui truncates line advances, so a fractional top would
    -- change the measured height and make the rows oscillate frame to frame.
    local top = math.floor(padding_y + (previous and math.max(0, (height - padding_y * 2 - previous) / 2) or 0) + 0.5)
    local ok, err = pcall(draw_row_contents, key, row, compact, top, choose)
    ImGui.EndChild(ctx)
    if not ok then error(err, 0) end
  end

  -- Group header: the count in the primary text color, then the label in the
  -- secondary one. A collapsible header is a full-width tree node whose open
  -- state the caller owns.
  local function draw_group(list_id, group, toggled)
    with_text("body", function()
      if group.collapsible then
        local x, y = ImGui.GetCursorPosX(ctx), ImGui.GetCursorPosY(ctx)
        local open = not group.collapsed
        ImGui.SetNextItemOpen(ctx, open, ImGui.Cond_Always)
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, resolve("semantic.color.text.secondary"))
        local now_open = ImGui.TreeNodeEx(ctx, "##group-" .. list_id .. "-" .. group.id, "",
          ImGui.TreeNodeFlags_SpanAvailWidth | ImGui.TreeNodeFlags_NoTreePushOnOpen)
        ImGui.PopStyleColor(ctx)
        if now_open ~= open then toggled() end
        ImGui.SameLine(ctx, 0, 0)
        ImGui.SetCursorPos(ctx, x + ImGui.GetTreeNodeToLabelSpacing(ctx), y)
      end
      if group.count then
        wrapped("body", "semantic.color.text.primary", tostring(group.count))
        ImGui.SameLine(ctx, 0, (ImGui.CalcTextSize(ctx, " ")))
      end
      wrapped("body", "semantic.color.text.secondary", group.label)
    end)
  end

  function component.draw(options)
    options = options or {}
    local compact = validate(options)
    local result = { events = {}, action = nil, toggled_group = nil }
    local _, spacing_y = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
    local gap = resolve("semantic.space.list.gap")
    local first = true
    local function separate()
      if not first then ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) - spacing_y + gap) end
      first = false
    end

    local hidden = false
    for _, item in ipairs(options.items) do
      if item.kind == "group" then
        separate()
        draw_group(options.id, item, function()
          result.toggled_group = item.id
          table.insert(result.events, { type = "list.group_toggled", id = options.id, group = item.id })
        end)
        hidden = item.collapsible == true and item.collapsed == true
      elseif not hidden then
        separate()
        draw_row(options.id .. "-" .. item.id, item, compact, function(action)
          result.action = { row = item.id, id = action }
          table.insert(result.events, { type = "list.row_action", id = options.id, row = item.id, action = action })
        end)
      end
    end
    layout.settle()
    return result
  end

  return component
end

return M
