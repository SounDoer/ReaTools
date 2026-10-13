local M = {}

local VALIDATION_STATES = { pending = true, valid = true, invalid = true }

local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter)
  local component = {}

  local function resolve(id) return adapter.resolve(id) end
  local function with_text(role, renderer)
    if adapter.with_text then return adapter.with_text(role, renderer) end
    return renderer()
  end

  local function colored_wrapped(token_id, value)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, resolve(token_id))
    ImGui.TextWrapped(ctx, value)
    ImGui.PopStyleColor(ctx)
  end

  function component.draw(options)
    options = options or {}
    required_string(options.id, "checkbox id")
    required_string(options.label, "checkbox label")
    if options.checked ~= nil and type(options.checked) ~= "boolean" then
      error("checkbox checked must be a boolean")
    end
    local validation = options.validation
    if validation then
      if not VALIDATION_STATES[validation.state] then
        error("unsupported validation state " .. tostring(validation.state))
      end
      if validation.state == "invalid" then
        required_string(validation.message, "invalid validation message")
      end
    end

    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg,
      resolve("component.checkbox.background.default"))
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgHovered,
      resolve("component.checkbox.background.hover"))
    ImGui.PushStyleColor(ctx, ImGui.Col_FrameBgActive,
      resolve("component.checkbox.background.pressed"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Text,
      resolve("component.checkbox.foreground.default"))
    ImGui.PushStyleColor(ctx, ImGui.Col_CheckMark,
      resolve("component.checkbox.check_mark.default"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Border, resolve(
      "component.checkbox.border." ..
      (validation and validation.state == "invalid" and "invalid" or "default")))
    if options.disabled then ImGui.BeginDisabled(ctx, true) end
    local changed, checked = with_text("label", function()
      return ImGui.Checkbox(ctx,
        options.label .. "##checkbox-" .. options.id, options.checked == true)
    end)
    if options.disabled then ImGui.EndDisabled(ctx) end
    ImGui.PopStyleColor(ctx, 6)

    if options.description and options.description ~= "" then
      colored_wrapped("component.field_shell.description.foreground.default",
        options.description)
    end
    if validation and validation.message and validation.message ~= "" then
      colored_wrapped(
        "component.field_shell.message." .. validation.state .. ".foreground.default",
        validation.message)
    elseif options.reserve_message == true then
      ImGui.Dummy(ctx, 0, ImGui.GetTextLineHeight(ctx))
    end

    changed = changed == true and options.disabled ~= true
    if options.disabled then
      checked = options.checked == true
    else
      checked = checked == true
    end
    local events = {}
    if changed then
      table.insert(events, {
        type = "checkbox.changed",
        id = options.id,
        checked = checked,
      })
    end
    return { checked = checked, changed = changed, events = events }
  end

  return component
end

return M
