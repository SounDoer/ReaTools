local status_module = require("reaui.design_status")
local action_bar_module = require("reaui.design_action_bar")
local layout_module = require("reaui.design_layout")

local M = {}

local CHILD_BORDERS = 1 << 0
local CHILD_ALWAYS_USE_PADDING = 1 << 1
local CHILD_AUTO_RESIZE_Y = 1 << 5
local FLAGS = CHILD_BORDERS | CHILD_ALWAYS_USE_PADDING | CHILD_AUTO_RESIZE_Y
local ROLES = { warning = true, blocked = true }

local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter, deps)
  deps = deps or {}
  local status = deps.status or status_module.create(ImGui, ctx, adapter)
  local action_bar = deps.action_bar or action_bar_module.create(ImGui, ctx, adapter)
  local layout = deps.layout or layout_module.create(ImGui, ctx, adapter)
  local component = {}

  local function resolve(id) return adapter.resolve(id) end

  local function validate(options)
    required_string(options.id, "issue item id")
    if not ROLES[options.role] then error("unsupported issue item role " .. tostring(options.role)) end
    required_string(options.message, "issue item message")
    if options.actions ~= nil and type(options.actions) ~= "table" then
      error("issue item actions must be a table")
    end
  end

  local function draw_contents(options, result)
    status.draw({ role = options.role, text = options.message, detail = options.detail, presentation = "inline" })
    if options.actions and #options.actions > 0 then
      local _, spacing_y = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
      ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) - spacing_y + resolve("semantic.space.control.gap"))
      local action = action_bar.draw({ id = options.id, actions = options.actions }).action
      if action then
        result.action = action
        table.insert(result.events, { type = "issue_item.action_selected", id = options.id, action = action })
      end
    end
  end

  function component.draw(options)
    options = options or {}
    validate(options)
    local prefix = "component.issue_item." .. options.role
    ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, resolve(prefix .. ".background"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Border, resolve(prefix .. ".border"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildBorderSize, resolve("semantic.border.control.width"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildRounding, resolve("semantic.radius.control"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,
      resolve("semantic.space.inset.padding_x"), resolve("semantic.space.inset.padding_y"))
    local visible = ImGui.BeginChild(ctx, "##issue-" .. options.id, 0, 0, FLAGS, ImGui.WindowFlags_NoScrollbar)
    ImGui.PopStyleVar(ctx, 3)
    ImGui.PopStyleColor(ctx, 2)

    local result = { events = {}, action = nil }
    if not visible then return result end
    local ok, err = pcall(draw_contents, options, result)
    ImGui.EndChild(ctx)
    if not ok then error(err, 0) end
    return result
  end

  function component.draw_list(options)
    options = options or {}
    required_string(options.id, "issue list id")
    if type(options.items) ~= "table" or #options.items == 0 then error("issue list needs items") end
    local result = { events = {}, action = nil }
    local _, spacing_y = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
    for index, item in ipairs(options.items) do
      if index > 1 then
        ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) - spacing_y + resolve("semantic.space.list.gap"))
      end
      local item_result = component.draw(item)
      if item_result.action then result.action = { item = item.id, id = item_result.action } end
      for _, event in ipairs(item_result.events) do table.insert(result.events, event) end
    end
    layout.settle()
    return result
  end

  return component
end

return M
