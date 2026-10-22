local field_shell_module = require("reaui.design_field_shell")

local M = {}

local DATA_STATES = { ready = true, loading = true, empty = true, failed = true }
local SIZES = { compact = true, standard = true }
local CHILD_BORDERS = 1 << 0

local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter, field_shell)
  field_shell = field_shell or field_shell_module.create(ImGui, ctx, adapter)
  local component = {}

  local function resolve(id) return adapter.resolve(id) end

  local function validate(options)
    required_string(options.id, "single selection list id")
    if type(options.items) ~= "table" then error("single selection list items are required") end
    local ids, selected = {}, nil
    for index, item in ipairs(options.items) do
      if type(item) ~= "table" then
        error("single selection list item " .. index .. " must be a table")
      end
      required_string(item.id, "single selection list item id")
      required_string(item.label, "single selection list item label")
      if ids[item.id] then error("duplicate single selection list item id " .. item.id) end
      ids[item.id] = true
      if item.id == options.value then selected = item end
    end
    if options.value ~= nil and type(options.value) ~= "string" then
      error("single selection list value must be a string or nil")
    end
    local data_state = options.data_state or "ready"
    if not DATA_STATES[data_state] then
      error("unsupported single selection list data_state " .. tostring(data_state))
    end
    if data_state == "ready" and #options.items == 0 then
      error("ready single selection list requires items")
    end
    if data_state == "empty" and #options.items > 0 then
      error("empty single selection list cannot contain items")
    end
    if options.value ~= nil and not selected then
      required_string(options.stale_label, "single selection list stale_label")
    end
    local size = options.size or "standard"
    if not SIZES[size] then error("unsupported single selection list size " .. tostring(size)) end
    return data_state, selected, size
  end

  local function status_message(options, state)
    if state == "loading" then return options.loading_label or "Loading items..." end
    if state == "empty" then return options.empty_label or "No items" end
    if state == "failed" then return options.failed_label or "Could not load items" end
    return nil
  end

  function component.draw(options)
    options = options or {}
    local data_state, selected, size = validate(options)
    local blocked = options.disabled == true or data_state ~= "ready"
    local invalid = options.validation and options.validation.state == "invalid"
    local height = resolve("component.single_selection_list.height." .. size)

    ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg,
      resolve("component.single_selection_list.background"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Border, resolve(
      "component.single_selection_list.border." .. (invalid and "invalid" or "default")))
    if options.disabled then ImGui.BeginDisabled(ctx, true) end
    local visible = ImGui.BeginChild(ctx, "##selection-list-" .. options.id,
      0, height, CHILD_BORDERS)
    ImGui.PopStyleColor(ctx, 2)
    local chosen
    if visible then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text,
        resolve("component.single_selection_list.foreground"))
      ImGui.PushStyleColor(ctx, ImGui.Col_Header,
        resolve("component.single_selection_list.row.selected"))
      ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered,
        resolve("component.single_selection_list.row.hover"))
      ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive,
        resolve("component.single_selection_list.row.pressed"))
      if options.value ~= nil and not selected then
        ImGui.TextColored(ctx,
          resolve("component.field_shell.message.invalid.foreground.default"),
          options.stale_label .. " (unavailable)")
      end
      local message = status_message(options, data_state)
      if message then
        ImGui.TextWrapped(ctx, message)
      else
        for index, item in ipairs(options.items) do
          local is_selected = item.id == options.value
          local label = item.label .. (is_selected and " (selected)" or "")
          if ImGui.Selectable(ctx,
              label .. "##selection-list-" .. options.id .. "-" .. index,
              is_selected) then
            chosen = item
          end
          if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, item.label) end
          if is_selected then ImGui.SetItemDefaultFocus(ctx) end
        end
      end
      ImGui.PopStyleColor(ctx, 4)
    end
    if visible then ImGui.EndChild(ctx) end
    if options.disabled then ImGui.EndDisabled(ctx) end

    local changed = chosen ~= nil and chosen.id ~= options.value and not blocked
    local value = changed and chosen.id or options.value
    local events = {}
    if changed then
      table.insert(events, {
        type = "selection.changed",
        id = options.id,
        value = value,
        item = chosen,
      })
    end
    return {
      value = value,
      item = changed and chosen or selected,
      changed = changed,
      stale = value ~= nil and not changed and selected == nil,
      data_state = data_state,
      events = events,
    }
  end

  function component.draw_field(options)
    options = options or {}
    required_string(options.label, "single selection list field label")
    return field_shell.draw(options, function(control_id)
      local control_options = {}
      for key, value in pairs(options) do control_options[key] = value end
      control_options.id = control_id:sub(3)
      return component.draw(control_options)
    end)
  end

  return component
end

return M
