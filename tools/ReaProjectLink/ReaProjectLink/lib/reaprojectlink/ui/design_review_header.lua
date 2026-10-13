local button_module = require("reaprojectlink.ui.design_button")

local M = {}
local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter, button)
  button = button or button_module.create(ImGui, ctx, adapter)
  local pattern = {}
  local function with_text(role, renderer)
    if adapter.with_text then return adapter.with_text(role, renderer) end
    return renderer()
  end
  function pattern.draw(options)
    options = options or {}
    required_string(options.id, "review header id")
    required_string(options.title, "review header title")
    local back = button.draw_icon({
      id = options.id .. "-back", icon = "back",
      accessible_label = options.back_label or "Back", disabled = options.disabled,
    })
    ImGui.SameLine(ctx, 0, adapter.resolve("semantic.space.control.gap"))
    with_text("title", function() ImGui.TextWrapped(ctx, options.title) end)
    if options.summary and options.summary ~= "" then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, adapter.resolve("semantic.color.text.secondary"))
      with_text("metadata", function() ImGui.TextWrapped(ctx, options.summary) end)
      ImGui.PopStyleColor(ctx)
    end
    local events = {}
    if back then table.insert(events, { type = "review.back_requested", id = options.id }) end
    return { events = events, back_requested = back ~= nil }
  end
  return pattern
end
return M
