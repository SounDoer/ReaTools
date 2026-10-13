local M = {}

local REQUIREMENTS = { required = true, optional = true }
local VALIDATION_STATES = { pending = true, valid = true, invalid = true }

local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter)
  local shell = {}
  local function with_text(role, renderer)
    if adapter.with_text then return adapter.with_text(role, renderer) end
    return renderer()
  end

  local function colored_wrapped(token_id, value)
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, adapter.resolve(token_id))
    ImGui.TextWrapped(ctx, value)
    ImGui.PopStyleColor(ctx)
  end

  function shell.draw(options, draw_control)
    options = options or {}
    required_string(options.id, "field id")
    required_string(options.label, "field label")
    if type(draw_control) ~= "function" then error("field control renderer is required") end
    if options.requirement and not REQUIREMENTS[options.requirement] then
      error("unsupported field requirement " .. tostring(options.requirement))
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

    local label = options.label
    if options.requirement then label = label .. " (" .. options.requirement .. ")" end
    with_text("label", function()
      ImGui.TextColored(ctx,
        adapter.resolve("component.field_shell.label.foreground.default"), label)
    end)
    if options.description and options.description ~= "" then
      colored_wrapped("component.field_shell.description.foreground.default",
        options.description)
    end

    local result = draw_control("##field-" .. options.id)

    if validation and validation.message and validation.message ~= "" then
      colored_wrapped(
        "component.field_shell.message." .. validation.state .. ".foreground.default",
        validation.message)
    elseif options.reserve_message ~= false then
      ImGui.Dummy(ctx, 0, ImGui.GetTextLineHeight(ctx))
    end
    return result
  end

  return shell
end

return M
