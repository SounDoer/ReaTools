local button_module = require("reaui.design_button")

local M = {}
local GENERIC_TITLES = { ["Are you sure?"] = true, Warning = true }
local GENERIC_ACTIONS = { Yes = true, OK = true, Continue = true }

local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter, button)
  button = button or button_module.create(ImGui, ctx, adapter)
  local pattern = {}
  local requested, was_visible = {}, {}

  function pattern.draw(options)
    options = options or {}
    required_string(options.id, "confirmation dialog id")
    required_string(options.title, "confirmation dialog title")
    required_string(options.message, "confirmation dialog message")
    required_string(options.confirm_label, "confirmation dialog confirm_label")
    if type(options.open) ~= "boolean" then error("confirmation dialog open must be a boolean") end
    if GENERIC_TITLES[options.title] then error("confirmation dialog title must name the consequence") end
    if GENERIC_ACTIONS[options.confirm_label] then
      error("confirmation dialog confirm_label must use a specific action verb")
    end
    if options.alternative_label ~= nil then
      required_string(options.alternative_label, "confirmation dialog alternative_label")
    end
    if options.running and (type(options.running_label) ~= "string" or options.running_label == "") then
      error("confirmation dialog running_label is required while running")
    end

    local popup_id = options.title .. "##confirmation-" .. options.id
    if options.open and not requested[options.id] then ImGui.OpenPopup(ctx, popup_id) end
    requested[options.id] = options.open
    local events, action = {}, nil
    local visible, popup_open = ImGui.BeginPopupModal(ctx, popup_id, true,
      ImGui.WindowFlags_AlwaysAutoResize)
    if visible then
      was_visible[options.id] = true
      ImGui.TextWrapped(ctx, options.message)
      if options.detail and options.detail ~= "" then
        ImGui.PushStyleColor(ctx, ImGui.Col_Text, adapter.resolve("semantic.color.text.secondary"))
        ImGui.TextWrapped(ctx, options.detail)
        ImGui.PopStyleColor(ctx)
      end
      local cancel = button.draw({
        id = options.id .. "-cancel", label = options.cancel_label or "Cancel",
        variant = "secondary", disabled = options.running,
      })
      ImGui.SetItemDefaultFocus(ctx)
      if options.alternative_label then
        ImGui.SameLine(ctx, 0, adapter.resolve("semantic.space.control.gap"))
        local alternative = button.draw({
          id = options.id .. "-alternative", label = options.alternative_label,
          variant = "secondary", disabled = options.running,
        })
        if alternative then action = "alternative_selected" end
      end
      ImGui.SameLine(ctx, 0, adapter.resolve("semantic.space.control.gap"))
      local confirm = button.draw({
        id = options.id .. "-confirm", label = options.confirm_label,
        variant = options.danger and "danger" or "primary",
        disabled = options.disabled,
        running = options.running,
        running_label = options.running_label,
      })
      if cancel then action = "cancelled" end
      if confirm then action = "confirmed" end
      if action then
        ImGui.CloseCurrentPopup(ctx)
        was_visible[options.id] = false
      end
      ImGui.EndPopup(ctx)
    elseif was_visible[options.id] and options.open and popup_open == false then
      action = "cancelled"
      was_visible[options.id] = false
    end
    if action then table.insert(events, { type = "dialog." .. action, id = options.id }) end
    return { open = visible and action == nil, action = action, events = events }
  end

  return pattern
end
return M
