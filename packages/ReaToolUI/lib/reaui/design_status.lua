local M = {}
local ROLES = { neutral="Info", ready="Ready", warning="Attention", blocked="Blocked" }

function M.create(ImGui, ctx, adapter)
  local component = {}
  function component.draw(options)
    options = options or {}
    if not ROLES[options.role] then error("unsupported status role " .. tostring(options.role)) end
    if type(options.text) ~= "string" or options.text == "" then error("status text is required") end
    local prefix = options.role_label or ROLES[options.role]
    if type(prefix) ~= "string" or prefix == "" then error("status role_label must be non-empty") end
    ImGui.PushStyleColor(ctx, ImGui.Col_Text,
      adapter.resolve("component.status." .. options.role .. ".foreground"))
    ImGui.TextWrapped(ctx, prefix .. ": " .. options.text)
    ImGui.PopStyleColor(ctx)
  end
  return component
end
return M
