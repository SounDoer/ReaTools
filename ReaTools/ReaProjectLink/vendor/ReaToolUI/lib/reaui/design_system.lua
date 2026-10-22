local contract = require("reaui.design_contract")
local adapter_module = require("reaui.design_adapter")

local M = {}

local function create_family(entries, ImGui, ctx, adapter)
  local family = {}
  for _, entry in ipairs(entries) do
    if not family[entry.factory_key] then
      family[entry.factory_key] = require("reaui." .. entry.module)
        .create(ImGui, ctx, adapter)
    end
  end
  return family
end

function M.create(ImGui, ctx, theme)
  if type(ImGui) ~= "table" then error("design system ImGui API is required") end
  if ctx == nil then error("design system context is required") end
  local adapter = adapter_module.create(ImGui, ctx, theme)
  local components = create_family(contract.CATALOG.components, ImGui, ctx, adapter)
  local patterns = create_family(contract.CATALOG.patterns, ImGui, ctx, adapter)
  return { contract = contract, adapter = adapter, components = components, patterns = patterns }
end

return M
