local module = require("reaprojectlink.ui.design_hierarchy_preview")

local function equal(actual, expected, label)
  if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local NODES = {
  { id = "root", label = "Actor-Mixer Hierarchy", default_open = true, children = {
    { id = "weapons", label = "Weapons", children = {
      { id = "rifle", label = "Rifle shot" },
    } },
    { id = "ambience", label = "Ambience" },
  } },
}

local function dependencies()
  local calls = { text = {}, disclosures = {}, statuses = {}, details = {} }
  local ImGui = { TextWrapped = function(_, value) table.insert(calls.text, value) end }
  local disclosure = {
    draw = function(options, renderer)
      table.insert(calls.disclosures, options)
      return { open = true, result = renderer and renderer() }
    end,
  }
  local status = { draw = function(options) table.insert(calls.statuses, options) end }
  return ImGui, disclosure, status, calls
end

local tests = {}

function tests.renders_nested_nodes_and_reports_shape()
  local ImGui, disclosure, status, calls = dependencies()
  local result = module.create(ImGui, "ctx", {}, disclosure, status).draw({
    id = "structure", nodes = NODES,
    render_detail = function(node, depth) table.insert(calls.details, node.id .. ":" .. depth) end,
  })
  equal(result.node_count, 4, "count")
  equal(result.max_depth, 3, "depth")
  equal(calls.disclosures[1].id, "structure-root", "scoped id")
  equal(calls.disclosures[1].default_open, true, "default open")
  equal(calls.text[1], "Rifle shot", "leaf text")
  equal(#calls.details, 4, "details")
end

function tests.lifecycle_states_use_explicit_non_color_status()
  for _, fixture in ipairs({
    { state = "loading", nodes = {}, role = "neutral" },
    { state = "empty", nodes = {}, role = "neutral" },
    { state = "failed", nodes = NODES, role = "blocked" },
    { state = "stale", nodes = NODES, role = "warning" },
    { state = "partial", nodes = NODES, role = "warning" },
  }) do
    local ImGui, disclosure, status, calls = dependencies()
    local result = module.create(ImGui, "ctx", {}, disclosure, status).draw({
      id = fixture.state, nodes = fixture.nodes, data_state = fixture.state,
    })
    equal(result.data_state, fixture.state, fixture.state)
    equal(calls.statuses[1].role, fixture.role, fixture.state .. " role")
  end
end

function tests.disabled_state_reaches_disclosures()
  local ImGui, disclosure, status, calls = dependencies()
  module.create(ImGui, "ctx", {}, disclosure, status).draw({ id = "tree", nodes = NODES, disabled = true })
  for _, options in ipairs(calls.disclosures) do equal(options.disabled, true, "disabled") end
end

function tests.rejects_invalid_states_duplicates_and_cycles()
  local ImGui, disclosure, status = dependencies()
  local pattern = module.create(ImGui, "ctx", {}, disclosure, status)
  assert(not pcall(function() pattern.draw({ id = "tree", nodes = {} }) end), "empty ready")
  assert(not pcall(function()
    pattern.draw({ id = "tree", nodes = NODES, data_state = "loading" })
  end), "loading data")
  assert(not pcall(function()
    pattern.draw({ id = "tree", nodes = { { id = "x", label = "X" }, { id = "x", label = "Y" } } })
  end), "duplicates")
  local cyclic = { id = "cycle", label = "Cycle" }
  cyclic.children = { cyclic }
  assert(not pcall(function() pattern.draw({ id = "tree", nodes = { cyclic } }) end), "cycle")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
