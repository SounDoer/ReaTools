local module=require("reaprojectlink.ui.design_token_insert_group")
local function equal(a,b,l)if a~=b then error(l..": expected "..tostring(b)..", got "..tostring(a))end end
local function deps()
  local c={buttons={},available=500};local I={GetContentRegionAvail=function()return c.available end,CalcTextSize=function(_,v)return #v*7 end,SameLine=function()c.same=(c.same or 0)+1 end}
  local field={draw=function(o)return{value=o.value or"",events=c.field_events or{},changed=false,committed=false}end}
  local button={draw=function(o)table.insert(c.buttons,o);if o.id==c.click and not o.disabled then return{}end end}
  local adapter={resolve=function(id)return id:find("compact",1,true)and 4 or 12 end};return I,adapter,field,button,c
end
local TOKENS={{id="track",label="$track",value="$track"},{id="marker",label="$marker",value="$marker"}}
local tests={}
function tests.appends_token_and_emits_ordered_events()
  local I,a,f,b,c=deps();c.click="name-token-marker";local r=module.create(I,"ctx",a,f,b).draw({id="name",label="Name",value="$track_",tokens=TOKENS})
  equal(r.value,"$track_$marker","value");equal(r.inserted_token,"marker","token");equal(r.events[1].type,"token.inserted","insert event");equal(r.events[2].type,"field.changed","change event");equal(r.events[3].type,"field.committed","commit event")
end
function tests.forwards_field_events_before_token_events()
  local I,a,f,b,c=deps();c.field_events={{type="field.changed"}};c.click="name-token-track";local r=module.create(I,"ctx",a,f,b).draw({id="name",value="",tokens=TOKENS})
  equal(r.events[1],c.field_events[1],"forwarded event");equal(r.events[2].type,"token.inserted","insert after input")
end
function tests.disabled_token_and_narrow_wrap_are_supported()
  local I,a,f,b,c=deps();c.available=70;c.click="name-token-marker";local tokens={{id="track",label="$track",value="$track"},{id="marker",label="$marker",value="$marker",disabled=true}}
  local r=module.create(I,"ctx",a,f,b).draw({id="name",value="",tokens=tokens});equal(r.inserted_token,nil,"disabled token");equal(c.same,nil,"wrapped rows")
end
function tests.rejects_empty_and_duplicate_tokens()
  local I,a,f,b=deps();local p=module.create(I,"ctx",a,f,b);assert(not pcall(function()p.draw({tokens={}})end),"empty")
  assert(not pcall(function()p.draw({tokens={{id="x",label="X",value="x"},{id="x",label="Y",value="y"}}})end),"duplicate")
end
local passed=0;for n,t in pairs(tests)do local ok,e=pcall(t);if not ok then error(n..": "..tostring(e))end;passed=passed+1 end;return passed
