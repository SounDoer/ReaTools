local notice_module=require("reaprojectlink.ui.design_notice")
local menu_module=require("reaprojectlink.ui.design_menu")
local disclosure_module=require("reaprojectlink.ui.design_disclosure")
local function equal(a,b,l)if a~=b then error(l..": expected "..tostring(b)..", got "..tostring(a))end end
local tests={}

function tests.notice_emits_actions_and_balances_container()
  local c={colors=0,popped=0,vars=0,popped_vars=0,ended=0,buttons={}};local I={Col_ChildBg=1,Col_Border=2,Col_Text=3,StyleVar_WindowPadding=4}
  function I.PushStyleColor()c.colors=c.colors+1 end;function I.PopStyleColor(_,n)c.popped=c.popped+(n or 1)end
  function I.PushStyleVar()c.vars=c.vars+1 end;function I.PopStyleVar(_,n)c.popped_vars=c.popped_vars+(n or 1)end
  function I.BeginChild()return true end;function I.EndChild()c.ended=c.ended+1 end;function I.TextWrapped(_,v)c.text=v end
  function I.GetContentRegionAvail()return 500 end;function I.CalcTextSize(_,v)return #v*7 end;function I.SameLine()end
  local button={draw=function(o)table.insert(c.buttons,o);if o.id=="blocked-retry"then return{}end end}
  local adapter={resolve=function(id)if id:find("space",1,true)then return 8 end return 1 end}
  local result=notice_module.create(I,"ctx",adapter,button).draw({id="blocked",role="blocked",text="Destination unavailable.",actions={{id="retry",label="Retry"}}})
  equal(result.action,"retry","notice action");equal(result.events[1].type,"notice.action_selected","notice event");equal(c.ended,1,"notice child")
  equal(c.colors,c.popped,"notice colors");equal(c.vars,c.popped_vars,"notice vars")
end

function tests.menu_handles_separator_disabled_and_danger_items()
  local c={popup=true,menu={}};local I={Col_Text=1}
  function I.OpenPopup(_,id)c.opened=id end;function I.BeginPopup()return c.popup end;function I.EndPopup()c.ended=true end;function I.Separator()c.separator=true end
  function I.BeginDisabled()c.disabled=true end;function I.EndDisabled()end;function I.PushStyleColor()c.danger=true end;function I.PopStyleColor()end
  function I.MenuItem(_,label)table.insert(c.menu,label);return label=="Delete snapshot" end
  local button={draw_icon=function()return{}end};local adapter={resolve=function()return 1 end}
  local result=menu_module.create(I,"ctx",adapter,button).draw({id="more",items={{id="rename",label="Rename"},{separator=true},{id="delete",label="Delete snapshot",danger=true}}})
  equal(result.action,"delete","menu action");equal(result.events[1].type,"menu.action_selected","menu event");assert(c.separator and c.danger and c.ended,"menu lifecycle")
end

function tests.disclosure_closes_tree_on_success_and_failure()
  local c={pop=0};local I={TreeNodeFlags_SpanAvailWidth=1,TreeNodeFlags_DefaultOpen=2,Col_Text=3}
  function I.TreeNodeEx()return true end;function I.TreePop()c.pop=c.pop+1 end;function I.PushStyleColor()end;function I.PopStyleColor()end;function I.TextWrapped(_,v)c.description=v end
  local disclosure=disclosure_module.create(I,"ctx",{resolve=function()return 1 end})
  local result=disclosure.draw({id="details",label="Details",description="Technical data",default_open=true},function()return"ok"end)
  equal(result.open,true,"open");equal(result.result,"ok","content result");equal(c.pop,1,"tree pop")
  local ok=pcall(function()disclosure.draw({id="bad",label="Bad"},function()error("failed")end)end)
  equal(ok,false,"failure rethrown");equal(c.pop,2,"failure tree pop")
end

function tests.information_components_reject_invalid_inputs()
  local N=notice_module.create({},"ctx",{},{});assert(not pcall(function()N.draw({id="x",role="danger",text="x"})end),"notice role")
  local M=menu_module.create({},"ctx",{},{});assert(not pcall(function()M.draw({id="x",items={}})end),"empty menu")
  local D=disclosure_module.create({},"ctx",{});assert(not pcall(function()D.draw({id="x",label=""})end),"disclosure label")
end
local passed=0;for n,t in pairs(tests)do local ok,e=pcall(t);if not ok then error(n..": "..tostring(e))end;passed=passed+1 end;return passed
