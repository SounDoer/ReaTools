local source = debug.getinfo(1, "S").source:sub(2)
local tests_dir = assert(source:match("^(.*)[/\\]"))
local root = assert(tests_dir:match("^(.*)[/\\]tests$"))
package.path = root .. "/ReaProjectLink/lib/?.lua;" .. root .. "/ReaProjectLink/lib/?/init.lua;" .. package.path

local components = require("reaprojectlink.ui.components")

local tests = {}

function tests.clipped_lists_reuse_one_attached_clipper()
  local created, attached = 0, 0
  local ImGui = {}

  function ImGui.CreateListClipper(ctx)
    created = created + 1
    return { ctx = ctx }
  end

  function ImGui.Attach(ctx, clipper)
    assert(clipper.ctx == ctx, "clipper attached to its context")
    attached = attached + 1
  end

  function ImGui.ListClipper_Begin(clipper, count)
    clipper.count = count
    clipper.pending = true
  end

  function ImGui.ListClipper_Step(clipper)
    if not clipper.pending then return false end
    clipper.pending = false
    return true
  end

  function ImGui.ListClipper_GetDisplayRange(clipper)
    return 0, clipper.count
  end

  local c = components.create(ImGui, "context", {
    adapter = {}, components = {}, patterns = {},
  })
  local drawn = {}
  c.clipped(2, function(index) table.insert(drawn, index) end)
  c.clipped(1, function(index) table.insert(drawn, index) end)

  assert(created == 1, "one clipper is created for repeated list draws")
  assert(attached == 1, "the clipper is attached to the UI context")
  assert(table.concat(drawn, ",") == "1,2,1", "both lists are drawn")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
