local module=require("reaprojectlink.ui.design_status")
local function equal(a,b,l) if a~=b then error(l..": expected "..tostring(b)..", got "..tostring(a)) end end
local tests={}
function tests.roles_render_readable_prefixes_and_balance_style()
  for role,prefix in pairs({neutral="Info",ready="Ready",warning="Attention",blocked="Blocked"}) do
    local calls={pushed=0,popped=0}; local I={Col_Text=1}
    function I.PushStyleColor() calls.pushed=calls.pushed+1 end; function I.PopStyleColor() calls.popped=calls.popped+1 end
    function I.TextWrapped(_,v) calls.text=v end
    local S=module.create(I,"ctx",{resolve=function(id) calls.token=id; return 1 end})
    S.draw({role=role,text="Example condition"}); equal(calls.text,prefix..": Example condition",role.." text")
    equal(calls.token,"component.status."..role..".foreground",role.." token"); equal(calls.pushed,calls.popped,"stack")
  end
end
function tests.custom_role_label_is_supported()
  local text; local I={Col_Text=1,PushStyleColor=function()end,PopStyleColor=function()end,TextWrapped=function(_,v) text=v end}
  module.create(I,"ctx",{resolve=function()return 1 end}).draw({role="neutral",role_label="Note",text="Details"})
  equal(text,"Note: Details","custom label")
end
function tests.rejects_unknown_role_and_empty_text()
  local I={}; local S=module.create(I,"ctx",{})
  assert(not pcall(function()S.draw({role="success",text="X"})end),"role rejected")
  assert(not pcall(function()S.draw({role="ready",text=""})end),"text rejected")
end
local passed=0; for n,t in pairs(tests)do local ok,e=pcall(t);if not ok then error(n..": "..tostring(e))end;passed=passed+1 end;return passed
