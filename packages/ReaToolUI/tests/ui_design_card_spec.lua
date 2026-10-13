local card_module = require("reaui.design_card")

local function equal(actual, expected, label)
  if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local function dependencies()
  local calls = { tokens = {}, colors = 0, popped_colors = 0, vars = 0, popped_vars = 0, ended = 0, wrapped = {} }
  local ImGui = { Col_ChildBg = 1, Col_Border = 2, Col_Text = 3, StyleVar_ChildBorderSize = 4, StyleVar_WindowPadding = 5 }
  function ImGui.PushStyleColor() calls.colors = calls.colors + 1 end
  function ImGui.PopStyleColor(_, n) calls.popped_colors = calls.popped_colors + (n or 1) end
  function ImGui.PushStyleVar() calls.vars = calls.vars + 1 end
  function ImGui.PopStyleVar(_, n) calls.popped_vars = calls.popped_vars + (n or 1) end
  function ImGui.BeginChild(_, id, width, height, flags) calls.child = { id=id, width=width, height=height, flags=flags }; return true end
  function ImGui.EndChild() calls.ended = calls.ended + 1 end
  function ImGui.TextColored(_, _, value) calls.title = value end
  function ImGui.TextWrapped(_, value) table.insert(calls.wrapped, value) end
  local adapter = {}
  function adapter.resolve(id) table.insert(calls.tokens, id); return id:find("width",1,true) and 1 or 0x112233ff end
  return ImGui, adapter, calls
end

local tests = {}
function tests.renders_content_and_balances_stacks()
  local ImGui, adapter, calls = dependencies()
  local card = card_module.create(ImGui, "ctx", adapter)
  local result = card.draw({ id="project", title="Source project", description="Current local project.", width=320 }, function() return "content" end)
  equal(result, "content", "result"); equal(calls.child.width, 320, "width"); equal(calls.title, "Source project", "title")
  equal(calls.wrapped[1], "Current local project.", "description"); equal(calls.ended, 1, "child end")
  equal(calls.colors, calls.popped_colors, "color stack"); equal(calls.vars, calls.popped_vars, "var stack")
end
function tests.emphasized_variant_uses_emphasis_tokens()
  local ImGui, adapter, calls = dependencies(); local card = card_module.create(ImGui, "ctx", adapter)
  card.draw({ id="current", variant="emphasized" })
  local joined = table.concat(calls.tokens, "\n")
  assert(joined:find("component.card.border.emphasized",1,true), "emphasis border")
  assert(joined:find("semantic.border.emphasis.width",1,true), "emphasis width")
end
function tests.content_failure_closes_child_and_rethrows()
  local ImGui, adapter, calls = dependencies(); local card = card_module.create(ImGui, "ctx", adapter)
  local ok, err = pcall(function() card.draw({ id="bad" }, function() error("content failed") end) end)
  equal(ok, false, "failure"); assert(tostring(err):find("content failed",1,true), "original error"); equal(calls.ended, 1, "child closed")
end
function tests.rejects_invalid_inputs()
  local ImGui, adapter = dependencies(); local card = card_module.create(ImGui, "ctx", adapter)
  assert(not pcall(function() card.draw({ id="" }) end), "id rejected")
  assert(not pcall(function() card.draw({ id="x", variant="selected" }) end), "variant rejected")
  assert(not pcall(function() card.draw({ id="x", width=-1 }) end), "width rejected")
end
local passed=0; for name,test in pairs(tests) do local ok,err=pcall(test); if not ok then error(name..": "..tostring(err)) end; passed=passed+1 end; return passed
