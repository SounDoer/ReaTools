local notice_module=require("reaui.design_notice")
local menu_module=require("reaui.design_menu")
local disclosure_module=require("reaui.design_disclosure")
local function equal(a,b,l)if a~=b then error(l..": expected "..tostring(b)..", got "..tostring(a))end end
local tests={}

function tests.notice_emits_actions_and_balances_container()
  local c={colors=0,popped=0,vars=0,popped_vars=0,ended=0,buttons={}};local I={Col_ChildBg=1,Col_Border=2,Col_Text=3,StyleVar_WindowPadding=4}
  function I.PushStyleColor()c.colors=c.colors+1 end;function I.PopStyleColor(_,n)c.popped=c.popped+(n or 1)end
  function I.PushStyleVar()c.vars=c.vars+1 end;function I.PopStyleVar(_,n)c.popped_vars=c.popped_vars+(n or 1)end
  function I.BeginChild()return true end;function I.EndChild()c.ended=c.ended+1 end;function I.TextWrapped(_,v)c.text=v end
  function I.GetContentRegionAvail()return 500 end;function I.CalcTextSize(_,v)return #v*7 end;function I.SameLine()end
  local button={draw=function(o)table.insert(c.buttons,o);if o.id=="blocked-retry"then return{}end end}
  local status={draw=function(o)c.status=o end}
  local adapter={resolve=function(id)if id:find("space",1,true)then return 8 end return 1 end}
  local result=notice_module.create(I,"ctx",adapter,button,status).draw({id="blocked",role="blocked",text="Destination unavailable.",role_label="Offline",actions={{id="retry",label="Retry"}}})
  equal(result.action,"retry","notice action");equal(result.events[1].type,"notice.action_selected","notice event");equal(c.ended,1,"notice child")
  equal(c.colors,c.popped,"notice colors");equal(c.vars,c.popped_vars,"notice vars")
  equal(c.status.role,"blocked","glyph status role");equal(c.status.text,"Destination unavailable.","status text without prefix")
  equal(c.status.role_label,"Offline","role label becomes the glyph tooltip");equal(c.status.presentation,"inline","inline status")
  equal(c.text,nil,"no visible role prefix")
end

local function disclosure_fake(options)
  options=options or {}
  local W=400
  local c={flags=nil,colors={},vars={},texts={},glyphs={},pop=0,x=0,right=0,y=50,set_y={}}
  local role="body"
  local I={TreeNodeFlags_SpanAvailWidth=1,TreeNodeFlags_DefaultOpen=2,TreeNodeFlags_Framed=4,Col_Text=3,
    Col_Header=5,Col_HeaderHovered=6,Col_HeaderActive=7,StyleVar_FramePadding=8,StyleVar_FrameRounding=9}
  function I.TreeNodeEx(_,_,label,flags)c.flags=flags;c.label=label;c.right=20+#label*7;return options.open==true end
  function I.TreePop()c.pop=c.pop+1 end
  function I.GetItemRectSize()return W,40 end
  function I.PushStyleColor(_,slot,color)c.colors[slot]=color end;function I.PopStyleColor(_,n)c.popped_colors=(c.popped_colors or 0)+(n or 1)end
  function I.PushStyleVar(_,var,x,y)c.vars[var]={x,y}end;function I.PopStyleVar(_,n)c.popped_vars=(c.popped_vars or 0)+(n or 1)end
  function I.GetTextLineHeight()return role=="metadata" and 12 or 16 end
  function I.CalcTextSize(_,text)return #text*7,16 end
  function I.SameLine(_,_,spacing)c.x=c.right+(spacing or 8)end
  function I.NewLine()c.x=0 end
  function I.GetContentRegionAvail()return W-c.x,100 end
  function I.GetCursorPosX()return c.x end;function I.SetCursorPosX(_,x)c.x=x end
  function I.GetCursorPosY()return c.y end;function I.SetCursorPosY(_,y)c.y=y;table.insert(c.set_y,y)end
  function I.Text(_,text)table.insert(c.texts,{text=text,x=c.x,y=c.y,role=role,color=c.colors[I.Col_Text]});c.right=c.x+#text*7 end
  function I.TextWrapped(_,text)table.insert(c.texts,{text=text,role=role})end
  local tokens={["semantic.space.inset.padding_x"]=12,["semantic.size.row.single"]=40,["semantic.space.inline.default"]=12,["semantic.space.control.gap"]=8}
  local adapter={resolve=function(id)return tokens[id] or id end,with_text=function(next_role,renderer)local p=role;role=next_role;local r=renderer();role=p;return r end}
  local status={draw_glyph=function(o)table.insert(c.glyphs,{options=o,x=c.x,y=c.y});c.right=c.x+16 end}
  return disclosure_module.create(I,"ctx",adapter,{status=status}),c,I,W
end

function tests.inset_disclosure_auto_opens_for_blocked_role()
  for _,case in ipairs({{"inset","blocked",true},{"inset","warning",true},{"inset","ready",false},{"default","blocked",false},{"inset",nil,false}})do
    local disclosure,c,I=disclosure_fake()
    disclosure.draw({id="tracks",label="Tracks · 4",variant=case[1],role=case[2]})
    equal((c.flags&I.TreeNodeFlags_DefaultOpen)~=0,case[3],tostring(case[1]).."/"..tostring(case[2]).." default open")
    if case[2] then equal(c.glyphs[1].options.role,case[2],"glyph role");equal(c.glyphs[1].y,50+(40-16)/2,"glyph centered on the row")
    else equal(#c.glyphs,0,"no glyph without role")end
  end
  local disclosure,c,I=disclosure_fake()
  disclosure.draw({id="tracks",label="Tracks",variant="inset"})
  equal((c.flags&I.TreeNodeFlags_Framed)~=0,true,"inset header is framed")
  equal(c.colors[I.Col_Header],"semantic.color.surface.inset","inset surface")
  equal(c.vars[I.StyleVar_FrameRounding][1],"semantic.radius.control","control radius")
  equal(c.vars[I.StyleVar_FramePadding][1],12,"inset padding x")
  equal(c.vars[I.StyleVar_FramePadding][2],(40-16)/2,"row single height")
  equal(c.popped_vars,2,"vars popped");equal(c.popped_colors,3,"colors popped")
  local plain,pc,PI=disclosure_fake()
  plain.draw({id="details",label="Details",default_open=true})
  equal((pc.flags&PI.TreeNodeFlags_Framed)~=0,false,"default variant unframed")
  equal(pc.popped_vars,nil,"no style vars for default variant")
end

function tests.inset_disclosure_detail_is_right_aligned()
  local disclosure,c,_,W=disclosure_fake()
  disclosure.draw({id="tracks",label="Tracks · 4",variant="inset",role="warning",detail="2 changed"})
  local detail=c.texts[1]
  equal(detail.text,"2 changed","detail text")
  equal(detail.role,"metadata","detail font")
  equal(detail.color,"semantic.color.text.secondary","detail color")
  equal(detail.x+#"2 changed"*7,W-12,"detail ends inside the inset padding")
  equal(detail.y,50+(40-12)/2,"detail centered on the row")
  assert(c.glyphs[1].x<detail.x,"glyph follows the label before the detail")
end

function tests.menu_handles_separator_disabled_and_danger_items()
  local c={popup=true,menu={}};local I={Col_Text=1}
  function I.OpenPopup(_,id)c.opened=id end;function I.BeginPopup()return c.popup end;function I.EndPopup()c.ended=true end;function I.Separator()c.separator=true end
  function I.BeginDisabled()c.disabled=true end;function I.EndDisabled()end;function I.PushStyleColor()c.danger=true end;function I.PopStyleColor()end
  function I.MenuItem(_,label)table.insert(c.menu,label);return label=="Delete snapshot" end
  local button={draw_icon=function(o)c.trigger=o;return{}end};local adapter={resolve=function()return 1 end}
  local result=menu_module.create(I,"ctx",adapter,button).draw({id="more",size="compact",items={{id="rename",label="Rename"},{separator=true},{id="delete",label="Delete snapshot",danger=true}}})
  equal(result.action,"delete","menu action");equal(result.events[1].type,"menu.action_selected","menu event");assert(c.separator and c.danger and c.ended,"menu lifecycle")
  equal(c.trigger.size,"compact","trigger size forwarded")
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
  assert(not pcall(function()D.draw({id="x",label="x",variant="boxed"})end),"disclosure variant")
  assert(not pcall(function()D.draw({id="x",label="x",role="danger"})end),"disclosure role")
end
local passed=0;for n,t in pairs(tests)do local ok,e=pcall(t);if not ok then error(n..": "..tostring(e))end;passed=passed+1 end;return passed
