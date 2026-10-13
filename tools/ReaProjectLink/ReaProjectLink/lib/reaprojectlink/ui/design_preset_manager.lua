local dropdown_module = require("reaprojectlink.ui.design_dropdown")
local text_field_module = require("reaprojectlink.ui.design_text_field")
local button_module = require("reaprojectlink.ui.design_button")

local M = {}

local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter, dropdown, text_field, button)
  dropdown = dropdown or dropdown_module.create(ImGui, ctx, adapter)
  text_field = text_field or text_field_module.create(ImGui, ctx, adapter)
  button = button or button_module.create(ImGui, ctx, adapter)
  local pattern = {}

  local function find_item(items, value)
    for _, item in ipairs(items) do
      if item.id == value then return item end
    end
    return nil
  end

  local function append_all(target, source)
    for _, event in ipairs(source or {}) do table.insert(target, event) end
  end

  function pattern.draw(options)
    options = options or {}
    required_string(options.id, "preset manager id")
    required_string(options.label, "preset manager label")
    if type(options.presets) ~= "table" then error("preset manager presets are required") end
    if options.draft_name ~= nil and type(options.draft_name) ~= "string" then
      error("preset manager draft_name must be a string or nil")
    end

    local blocked = options.disabled == true or options.busy == true
    local select_result = dropdown.draw_field({
      id = options.id .. "-selection",
      label = options.label,
      description = options.description,
      options = options.presets,
      value = options.value,
      data_state = options.data_state,
      loading_label = options.loading_label,
      empty_label = options.empty_label or "No saved presets",
      failed_label = options.failed_label,
      stale_label = options.stale_label,
      validation = options.selection_validation,
      disabled = blocked,
    })
    local selected = select_result.option or find_item(options.presets, select_result.value)
    local name_result = text_field.draw({
      id = options.id .. "-name",
      label = options.name_label or "Preset name",
      description = options.name_description,
      value = options.draft_name or (selected and selected.label or ""),
      placeholder = options.name_placeholder or "Name this preset",
      validation = options.name_validation,
      disabled = blocked,
    })

    local events = {}
    append_all(events, select_result.events)
    append_all(events, name_result.events)
    local has_selection = selected ~= nil
    local has_name = name_result.value:match("%S") ~= nil
    local actions = {
      {
        key = "save", label = options.save_label or "Save", variant = "primary",
        disabled = blocked or options.save_disabled or not has_name,
      },
      {
        key = "load", label = options.load_label or "Load", variant = "secondary",
        disabled = blocked or options.load_disabled or not has_selection,
      },
      {
        key = "delete", label = options.delete_label or "Delete", variant = "danger",
        disabled = blocked or options.delete_disabled or not has_selection,
      },
    }
    local available = ImGui.GetContentRegionAvail(ctx)
    local gap = adapter.resolve("semantic.space.control.compact_gap")
    local padding = adapter.resolve("semantic.space.control.padding_x")
    local row_width, action = 0, nil
    for index, candidate in ipairs(actions) do
      local width = ImGui.CalcTextSize(ctx, candidate.label) + padding * 2
      if index > 1 and row_width + gap + width <= available then
        ImGui.SameLine(ctx, 0, gap)
        row_width = row_width + gap + width
      else
        row_width = width
      end
      local event = button.draw({
        id = options.id .. "-" .. candidate.key,
        label = candidate.label,
        variant = candidate.variant,
        disabled = candidate.disabled,
        running = options.busy and options.busy_action == candidate.key,
        running_label = options.busy and options.busy_action == candidate.key and
          (options.busy_label or "Working...") or nil,
      })
      if event and not action then action = candidate.key end
    end

    if action then
      table.insert(events, {
        type = "preset." .. action .. "_requested",
        id = options.id,
        value = select_result.value,
        item = selected,
        name = name_result.value,
      })
    end
    return {
      value = select_result.value,
      item = selected,
      name = name_result.value,
      selection_changed = select_result.changed,
      name_changed = name_result.changed,
      action = action,
      events = events,
    }
  end

  return pattern
end

return M
