local module=require("reaprojectlink.ui.design_path_selection")
local function equal(a,b,l)if a~=b then error(l..": expected "..tostring(b)..", got "..tostring(a))end end
local tests={}
function tests.maps_lifecycle_to_path_field_validation()
  for state,expected in pairs({checking="pending",valid="valid",invalid="invalid",unavailable="invalid"})do
    local calls={};local field={draw=function(o)calls.options=o;return{events={},value=o.value or""}end}
    local result=module.create({},"ctx",{},field).draw({id="path",label="Path",kind="folder",state=state,message="State message"})
    equal(calls.options.validation.state,expected,state.." validation");equal(result.state,state,state.." result")
    if state=="unavailable"then equal(calls.options.browse_disabled,true,"unavailable browse")end
  end
end
function tests.idle_forwards_events_without_validation()
  local event={type="path.browse_requested"};local calls={};local field={draw=function(o)calls.options=o;return{events={event},value="x"}end}
  local result=module.create({},"ctx",{},field).draw({id="path",label="Path",kind="file"})
  equal(calls.options.validation,nil,"idle validation");equal(result.events[1],event,"event forwarding");equal(result.state,"idle","idle state")
end
function tests.rejects_unknown_missing_and_conflicting_state()
  local P=module.create({},"ctx",{},{draw=function()return{}end})
  assert(not pcall(function()P.draw({state="loading"})end),"unknown state")
  assert(not pcall(function()P.draw({state="checking"})end),"missing message")
  assert(not pcall(function()P.draw({state="valid",message="ok",validation={state="valid"}})end),"conflicting validation")
end
local passed=0;for n,t in pairs(tests)do local ok,e=pcall(t);if not ok then error(n..": "..tostring(e))end;passed=passed+1 end;return passed
