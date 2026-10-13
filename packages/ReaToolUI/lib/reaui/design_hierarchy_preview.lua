local disclosure_module = require("reaui.design_disclosure")
local status_module = require("reaui.design_status")

local M = {}
local STATES = { ready = true, loading = true, empty = true, failed = true, stale = true, partial = true }

local function required_string(value, name)
  if type(value) ~= "string" or value == "" then error(name .. " is required") end
end

function M.create(ImGui, ctx, adapter, disclosure, status)
  disclosure = disclosure or disclosure_module.create(ImGui, ctx, adapter)
  status = status or status_module.create(ImGui, ctx, adapter)
  local pattern = {}

  local function validate_nodes(nodes)
    local ids, tables = {}, {}
    local count, deepest = 0, 0
    local function visit(node, depth)
      if type(node) ~= "table" then error("hierarchy preview nodes must be tables") end
      if tables[node] then error("hierarchy preview cannot contain cyclic node tables") end
      tables[node] = true
      required_string(node.id, "hierarchy preview node id")
      required_string(node.label, "hierarchy preview node label")
      if ids[node.id] then error("duplicate hierarchy preview node id " .. node.id) end
      ids[node.id] = true
      if node.children ~= nil and type(node.children) ~= "table" then
        error("hierarchy preview node children must be a table or nil")
      end
      count, deepest = count + 1, math.max(deepest, depth)
      if depth > 64 then error("hierarchy preview exceeds 64 levels") end
      for _, child in ipairs(node.children or {}) do visit(child, depth + 1) end
      tables[node] = nil
    end
    for _, node in ipairs(nodes) do visit(node, 1) end
    return count, deepest
  end

  local function state_message(options, state)
    if state == "loading" then return options.message or "Loading hierarchy...", "neutral" end
    if state == "empty" then return options.message or "No hierarchy to preview", "neutral" end
    if state == "failed" then return options.message or "Could not load hierarchy", "blocked" end
    if state == "stale" then return options.message or "Showing a previous hierarchy", "warning" end
    if state == "partial" then return options.message or "Some hierarchy data is unavailable", "warning" end
    return nil, nil
  end

  function pattern.draw(options)
    options = options or {}
    required_string(options.id, "hierarchy preview id")
    if type(options.nodes) ~= "table" then error("hierarchy preview nodes are required") end
    if options.render_detail ~= nil and type(options.render_detail) ~= "function" then
      error("hierarchy preview render_detail must be a function")
    end
    local state = options.data_state or "ready"
    if not STATES[state] then error("unsupported hierarchy preview data_state " .. tostring(state)) end
    if state == "ready" and #options.nodes == 0 then
      error("ready hierarchy preview requires nodes")
    end
    if (state == "loading" or state == "empty") and #options.nodes > 0 then
      error(state .. " hierarchy preview cannot contain nodes")
    end
    local count, deepest = validate_nodes(options.nodes)
    local message, role = state_message(options, state)
    if message then status.draw({ role = role, text = message }) end

    local function draw_node(node, depth)
      local children = node.children or {}
      if #children > 0 then
        disclosure.draw({
          id = options.id .. "-" .. node.id,
          label = node.label,
          description = node.description,
          default_open = node.default_open == true,
          disabled = options.disabled == true,
        }, function()
          if options.render_detail then options.render_detail(node, depth) end
          for _, child in ipairs(children) do draw_node(child, depth + 1) end
        end)
      else
        ImGui.TextWrapped(ctx, node.label)
        if node.description and node.description ~= "" then ImGui.TextWrapped(ctx, node.description) end
        if options.render_detail then options.render_detail(node, depth) end
      end
    end
    for _, node in ipairs(options.nodes) do draw_node(node, 1) end
    return { data_state = state, node_count = count, max_depth = deepest, events = {} }
  end

  return pattern
end

return M
