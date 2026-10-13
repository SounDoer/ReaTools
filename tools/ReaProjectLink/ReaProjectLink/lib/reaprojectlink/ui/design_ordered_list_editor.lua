local list_module = require("reaprojectlink.ui.design_single_selection_list")
local button_module = require("reaprojectlink.ui.design_button")

local M = {}

local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter, selection_list, button)
  selection_list = selection_list or list_module.create(ImGui, ctx, adapter)
  button = button or button_module.create(ImGui, ctx, adapter)
  local pattern = {}

  local function selected_index(items, value)
    for index, item in ipairs(items) do
      if item.id == value then return index end
    end
    return nil
  end

  local function draw_actions(options, selected, index)
    local actions = {
      {
        key = "add", label = options.add_label or "Add", variant = "secondary",
        disabled = options.disabled or options.add_disabled,
      },
      {
        key = "delete", label = options.delete_label or "Delete", variant = "danger",
        disabled = options.disabled or options.delete_disabled or selected == nil,
      },
      {
        key = "up", label = options.move_up_label or "Move up", variant = "secondary",
        disabled = options.disabled or options.move_up_disabled or index == nil or index == 1,
      },
      {
        key = "down", label = options.move_down_label or "Move down", variant = "secondary",
        disabled = options.disabled or options.move_down_disabled or index == nil or
          index == #options.items,
      },
    }
    local available = ImGui.GetContentRegionAvail(ctx)
    local gap = adapter.resolve("semantic.space.control.compact_gap")
    local padding = adapter.resolve("semantic.space.control.padding_x")
    local row_width = 0
    local activated
    for action_index, action in ipairs(actions) do
      local width = ImGui.CalcTextSize(ctx, action.label) + padding * 2
      if action_index > 1 and row_width + gap + width <= available then
        ImGui.SameLine(ctx, 0, gap)
        row_width = row_width + gap + width
      else
        row_width = width
      end
      local event = button.draw({
        id = options.id .. "-" .. action.key,
        label = action.label,
        variant = action.variant,
        disabled = action.disabled,
      })
      if event and not activated then activated = action.key end
    end
    return activated
  end

  function pattern.draw(options)
    options = options or {}
    required_string(options.id, "ordered list editor id")
    required_string(options.label, "ordered list editor label")
    if type(options.items) ~= "table" then error("ordered list editor items are required") end
    if options.render_editor ~= nil and type(options.render_editor) ~= "function" then
      error("ordered list editor render_editor must be a function")
    end

    local list_result = selection_list.draw_field(options)
    local value = list_result.value
    local selected = list_result.item
    local index = selected_index(options.items, value)
    local events = {}
    for _, event in ipairs(list_result.events) do table.insert(events, event) end

    local action = draw_actions(options, selected, index)
    if action == "add" then
      table.insert(events, { type = "ordered_list.add_requested", id = options.id })
    elseif action == "delete" then
      table.insert(events, {
        type = "ordered_list.delete_requested", id = options.id,
        value = value, item = selected, index = index,
      })
    elseif action == "up" or action == "down" then
      table.insert(events, {
        type = "ordered_list.move_requested", id = options.id,
        value = value, item = selected, index = index, direction = action,
      })
    end

    if options.render_editor and selected then options.render_editor(selected, index) end
    return {
      value = value,
      item = selected,
      index = index,
      changed = list_result.changed,
      action = action,
      events = events,
    }
  end

  return pattern
end

return M
