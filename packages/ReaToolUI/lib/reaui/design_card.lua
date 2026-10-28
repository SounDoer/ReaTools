local default_icons = require("reaui.icons")
local button_module = require("reaui.design_button")
local status_module = require("reaui.design_status")
local menu_module = require("reaui.design_menu")
local action_bar_module = require("reaui.design_action_bar")
local section_heading_module = require("reaui.design_section_heading")
local layout_module = require("reaui.design_layout")

local M = {}

local CHILD_BORDERS = 1 << 0
local CHILD_ALWAYS_USE_PADDING = 1 << 1
local CHILD_AUTO_RESIZE_Y = 1 << 5
local FIXED_FLAGS = CHILD_BORDERS | CHILD_ALWAYS_USE_PADDING
local AUTO_FLAGS = FIXED_FLAGS | CHILD_AUTO_RESIZE_Y
local TRAILING_KINDS = { icon_button = true, menu = true }

local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

local function optional_size(value, name)
  if value ~= nil and (type(value) ~= "number" or value < 0) then
    error(name .. " must be a non-negative number")
  end
end

function M.create(ImGui, ctx, adapter, deps)
  deps = deps or {}
  local button = deps.button or button_module.create(ImGui, ctx, adapter)
  local status = deps.status or status_module.create(ImGui, ctx, adapter)
  local menu = deps.menu or menu_module.create(ImGui, ctx, adapter, button)
  local action_bar = deps.action_bar or action_bar_module.create(ImGui, ctx, adapter, button)
  local icons = deps.icons or default_icons
  local layout = deps.layout or layout_module.create(ImGui, ctx, adapter)
  local section_heading = deps.section_heading or section_heading_module.create(ImGui, ctx, adapter, layout)
  local component = {}
  -- Heights measured on the previous frame, keyed by card id.
  local natural, footer_heights = {}, {}

  local function resolve(id) return adapter.resolve(id) end
  local function with_text(role, renderer)
    if adapter.with_text then return adapter.with_text(role, renderer) end
    return renderer()
  end

  local function validate(options, render_body)
    required_string(options.id, "card id")
    if render_body ~= nil and type(render_body) ~= "function" then
      error("card content renderer must be a function")
    end
    optional_size(options.width, "card width")
    optional_size(options.min_height, "card min_height")
    if options.variant ~= nil and options.variant ~= "default" and options.variant ~= "emphasized" then
      error("unsupported card variant " .. tostring(options.variant))
    end
    if options.title ~= nil then required_string(options.title, "card title") end
    if options.trailing ~= nil and not TRAILING_KINDS[options.trailing.kind] then
      error("unsupported card trailing kind " .. tostring(options.trailing.kind))
    end
    if options.selection ~= nil then error("card selection was replaced by card sections") end
    for _, section in ipairs(options.sections or {}) do
      required_string(section.id, "card section id")
      required_string(section.heading, "card section heading")
      if type(section.render) ~= "function" then error("card section render must be a function") end
    end
  end

  local function draw_contents(options, render_body, height, result)
    local _, spacing_y = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
    local padding = resolve("semantic.space.container.padding")
    local block_gap = resolve("semantic.space.block.gap")
    local bottom, next_y = nil, nil
    local function item_bottom() return ImGui.GetCursorPosY(ctx) - spacing_y end
    local function begin_block() if next_y then ImGui.SetCursorPosY(ctx, next_y) end end
    local function end_block(y) bottom = y; next_y = y + block_gap end
    local function choose(action)
      if action == nil then return end
      result.action = action
      table.insert(result.events, { type = "card.action_selected", id = options.id, action = action })
    end

    if options.title or options.icon or options.trailing then
      local row_x, row_y = ImGui.GetCursorPosX(ctx), ImGui.GetCursorPosY(ctx)
      local row_width = ImGui.GetContentRegionAvail(ctx)
      local row_height = resolve("semantic.size.control.medium")
      local trailing_width = options.trailing and row_height or 0
      local title_x = row_x
      if options.icon then
        local icon_size = resolve("semantic.size.icon.medium")
        local screen_x, screen_y = ImGui.GetCursorScreenPos(ctx)
        icons.draw(ImGui, ImGui.GetWindowDrawList(ctx), options.icon, screen_x,
          screen_y + (row_height - icon_size) / 2, icon_size, resolve("component.card.title"))
        title_x = row_x + icon_size + resolve("semantic.space.inline.default")
      end
      local row_bottom = row_y + row_height
      if options.title then
        with_text("heading", function()
          ImGui.SetCursorPos(ctx, title_x, row_y + (row_height - ImGui.GetTextLineHeight(ctx)) / 2)
          ImGui.PushTextWrapPos(ctx, row_x + row_width - trailing_width -
            (options.trailing and resolve("semantic.space.inline.default") or 0))
          ImGui.PushStyleColor(ctx, ImGui.Col_Text, resolve("component.card.title"))
          ImGui.TextWrapped(ctx, options.title)
          ImGui.PopStyleColor(ctx)
          ImGui.PopTextWrapPos(ctx)
        end)
        row_bottom = math.max(row_bottom, item_bottom())
      end
      if options.trailing then
        local trailing = options.trailing
        ImGui.SetCursorPos(ctx, row_x + row_width - trailing_width, row_y)
        if trailing.kind == "icon_button" then
          local event = button.draw_icon({
            id = options.id .. "-" .. trailing.id, icon = trailing.icon,
            accessible_label = trailing.accessible_label, variant = "quiet",
          })
          if event then choose(trailing.id) end
        else
          choose(menu.draw({
            id = options.id .. "-" .. trailing.id, accessible_label = trailing.accessible_label,
            items = trailing.items,
          }).action)
        end
      end
      end_block(row_bottom)
    end

    if options.description and options.description ~= "" then
      -- The description belongs to the title row, so it skips the block gap.
      if bottom then ImGui.SetCursorPosY(ctx, bottom) end
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, resolve("component.card.description"))
      ImGui.TextWrapped(ctx, options.description)
      ImGui.PopStyleColor(ctx)
      end_block(item_bottom())
    end

    if options.status then
      begin_block()
      status.draw({
        role = options.status.role, text = options.status.text, detail = options.status.detail,
        role_label = options.status.role_label, presentation = "prominent",
      })
      end_block(item_bottom())
    end

    if render_body then
      begin_block()
      local top = ImGui.GetCursorPosY(ctx)
      result.body_result = render_body()
      -- A body that drew nothing adds no block gap.
      if ImGui.GetCursorPosY(ctx) ~= top then end_block(item_bottom()) end
    end

    for _, section in ipairs(options.sections or {}) do
      begin_block()
      local top = ImGui.GetCursorPosY(ctx)
      ImGui.Separator(ctx)
      ImGui.SetCursorPosY(ctx, top + resolve("semantic.space.footer.padding_y"))
      section_heading.draw({ id = options.id .. "-" .. section.id, title = section.heading, gap_above = false })
      choose(section.render())
      end_block(item_bottom())
    end

    local content_bottom = bottom or (ImGui.GetCursorPosY(ctx) - spacing_y)
    local footer_height = 0
    if options.footer then
      local top = next_y or content_bottom
      local previous = footer_heights[options.id]
      -- Whole pixels: ImGui truncates line advances, so a fractional top would
      -- change the measured footer height and make the footer oscillate.
      if previous and height > 0 then top = math.max(top, math.floor(height - padding - previous + 0.5)) end
      ImGui.SetCursorPosY(ctx, top)
      ImGui.Separator(ctx)
      ImGui.SetCursorPosY(ctx, top + resolve("semantic.space.footer.padding_y"))
      local footer_options = options.footer
      choose(action_bar.draw({
        id = options.id .. "-footer", context = footer_options.context, actions = footer_options.actions or {},
      }).action)
      footer_height = item_bottom() - top
      footer_heights[options.id] = footer_height
      content_bottom = (next_y or content_bottom) + footer_height
    end
    natural[options.id] = content_bottom + padding
    layout.settle()
  end

  function component.draw(options, render_body)
    options = options or {}
    validate(options, render_body)
    local emphasized = options.variant == "emphasized"
    local stored = natural[options.id]
    local height, flags = 0, AUTO_FLAGS
    if stored or options.min_height then
      height = math.max(stored or 0, options.min_height or 0)
      flags = FIXED_FLAGS
    end

    ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, resolve("component.card.background"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Border, resolve(
      "component.card.border." .. (emphasized and "emphasized" or "default")))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildBorderSize, resolve(
      emphasized and "semantic.border.emphasis.width" or "semantic.border.control.width"))
    local padding = resolve("semantic.space.container.padding")
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, padding, padding)
    local visible = ImGui.BeginChild(ctx, "##card-" .. options.id,
      options.width or 0, height, flags, ImGui.WindowFlags_NoScrollbar)
    ImGui.PopStyleVar(ctx, 2)
    ImGui.PopStyleColor(ctx, 2)

    local result = { events = {} }
    local ok, err = true, nil
    if visible then
      ok, err = pcall(draw_contents, options, render_body, height, result)
      ImGui.EndChild(ctx)
    end
    if not ok then error(err, 0) end
    result.natural_height = natural[options.id] or height
    return result
  end

  return component
end

return M
