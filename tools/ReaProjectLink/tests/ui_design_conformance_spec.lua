local contract = require("reaprojectlink.ui.design_contract")

local source = debug.getinfo(1, "S").source:sub(2)
local tests_dir = source:match("^(.*)[/\\]")
local root = assert(tests_dir and tests_dir:match("^(.*)[/\\]tests$"), "repository root")

local function read(path)
  local file = assert(io.open(path, "r"), "missing file " .. path)
  local content = file:read("*a")
  file:close()
  return content
end

local function join(...)
  return table.concat({ ... }, "/")
end

local tests = {}

function tests.public_catalog_has_unique_traceable_entries()
  local ids, names = {}, {}
  for family, entries in pairs(contract.CATALOG) do
    for _, entry in ipairs(entries) do
      assert(entry.id:match("^[a-z][a-z0-9_]*$"), family .. " canonical id")
      assert(not ids[entry.id], "duplicate public id " .. entry.id)
      assert(not names[entry.name], "duplicate public name " .. entry.name)
      ids[entry.id], names[entry.name] = true, true
      assert(type(entry.factory_key) == "string" and entry.factory_key ~= "", entry.id .. " factory")
      assert(type(entry.fixture) == "string" and entry.fixture ~= "", entry.id .. " fixture")
      local module = require("reaprojectlink.ui." .. entry.module)
      assert(type(module.create) == "function", entry.id .. " module create")
      local specification = read(join(root, "docs/design-system", entry.spec))
      assert(specification:match("^# "), entry.id .. " specification title")
    end
  end
end

function tests.every_public_item_has_a_registered_gallery_fixture()
  local gallery = read(join(root, "tests/design_system_gallery.lua"))
  for family, entries in pairs(contract.CATALOG) do
    for _, entry in ipairs(entries) do
      assert(gallery:find(entry.fixture, 1, true),
        family .. " " .. entry.id .. " missing Gallery marker " .. entry.fixture)
    end
  end
end

function tests.public_implementation_does_not_consume_primitive_tokens_or_raw_colors()
  local checked = {}
  for _, entries in pairs(contract.CATALOG) do
    for _, entry in ipairs(entries) do
      if not checked[entry.module] then
        local path = join(root, "ReaProjectLink/lib/reaprojectlink/ui", entry.module .. ".lua")
        local implementation = read(path)
        assert(not implementation:find('"primitive%.', 1), entry.module .. " consumes Primitive token")
        assert(not implementation:find("0x%x+"), entry.module .. " embeds a raw color literal")
        checked[entry.module] = true
      end
    end
  end
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
