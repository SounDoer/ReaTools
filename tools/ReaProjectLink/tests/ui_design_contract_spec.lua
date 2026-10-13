local contract = require("reaprojectlink.ui.design_contract")
local system_module = require("reaprojectlink.ui.design_system")

local function equal(actual, expected, label)
  if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local function contains(values, fragment)
  for _, value in ipairs(values) do if value:find(fragment, 1, true) then return true end end
  return false
end

local tests = {}

function tests.development_metadata_is_explicit_and_complete()
  equal(contract.STATUS, "development", "status")
  equal(contract.VERSION, nil, "unpublished version")
  equal(contract.ADAPTER.name, "ReaImGui", "adapter")
  equal(contract.ADAPTER.api_version, "0.9", "API")
  assert(#contract.COMPONENTS >= 16, "component catalog")
  assert(#contract.PATTERNS >= 12, "pattern catalog")
end

function tests.consumer_declaration_requires_traceability_fields()
  local valid = {
    schema_version = 1,
    contract_status = "development",
    implementation_revision = "9eb56ee",
    adapter = { name = "ReaImGui", api_version = "0.9" },
    exceptions = {},
  }
  equal(#contract.validate_consumer(valid), 0, "valid declaration")
  local errors = contract.validate_consumer({
    schema_version = 2, contract_status = "published", contract_version = "0.1.0",
    adapter = { name = "Other", api_version = "1" },
  })
  assert(contains(errors, "schema_version"), "schema")
  assert(contains(errors, "published version"), "version")
  assert(contains(errors, "implementation_revision"), "revision")
  assert(contains(errors, "exceptions"), "exceptions")
end

function tests.factory_exposes_every_registered_public_family()
  local ImGui = setmetatable({
    CreateFont = function() return "font" end,
    Attach = function() end,
    Col_NavHighlight = 1,
  }, { __index = function() return 1 end })
  local system = system_module.create(ImGui, "ctx", "light")
  equal(system.contract, contract, "contract")
  for _, name in ipairs({
    "button", "field_shell", "text_field", "number_field", "path_field", "checkbox",
    "dropdown", "segmented_control", "single_selection_list", "card", "status", "notice",
    "menu", "disclosure",
  }) do assert(type(system.components[name]) == "table", "component " .. name) end
  for _, name in ipairs({
    "path_selection", "token_insert_group", "ordered_list_editor", "preset_manager",
    "hierarchy_preview", "external_operation_status", "review_header", "review_footer",
    "stale_review", "review_shell", "confirmation_dialog", "inline_review",
  }) do assert(type(system.patterns[name]) == "table", "pattern " .. name) end
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
