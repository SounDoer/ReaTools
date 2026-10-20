local module=require("reaui.design_status")
local function equal(a,b,l) if a~=b then error(l..": expected "..tostring(b)..", got "..tostring(a)) end end

local function fake(options)
  options=options or {}
  local calls={pushed=0,popped=0,text={},roles={},colors={},groups=0}
  local I={Col_Text=1}
  function I.PushStyleColor(_,_,color) calls.pushed=calls.pushed+1; table.insert(calls.colors,color) end
  function I.PopStyleColor() calls.popped=calls.popped+1 end
  function I.TextWrapped(_,v) table.insert(calls.text,v) end
  function I.GetTextLineHeight() return 16 end
  function I.GetCursorScreenPos() return 10,20 end
  function I.GetWindowDrawList() return "draw-list" end
  function I.Dummy(_,w,h) calls.dummy={w,h} end
  function I.SameLine(_,_,spacing) calls.spacing=spacing end
  function I.BeginGroup() calls.groups=calls.groups+1 end
  function I.EndGroup() calls.groups=calls.groups-1 end
  function I.IsItemHovered() return options.hovered==true end
  function I.SetTooltip(_,v) calls.tooltip=v end
  function I.CalcTextSize() return 100,16 end
  local adapter={
    resolve=function(id) if id=="semantic.space.inline.default" then return 8 end return id end,
    with_text=function(role,renderer) table.insert(calls.roles,role) return renderer() end,
  }
  local icons={draw=function(_,_,name,_,_,size,color) calls.icon={name=name,size=size,color=color} return true end}
  return module.create(I,"ctx",adapter,icons),calls
end

local tests={}
function tests.glyph_replaces_visible_prefix()
  for role,icon in pairs({neutral="dot",ready="check",warning="warning",blocked="cross"}) do
    local S,calls=fake(); S.draw({role=role,text="Example"})
    equal(calls.icon.name,icon,role.." icon")
    equal(calls.icon.size,16,role.." icon size")
    equal(calls.icon.color,"component.status."..role..".foreground",role.." icon color")
    equal(calls.text[1],"Example",role.." text")
    equal(calls.spacing,8,role.." gap")
    equal(calls.pushed,calls.popped,role.." style stack")
    equal(calls.groups,0,role.." group stack")
  end
end
function tests.role_label_is_tooltip()
  local S,calls=fake({hovered=true}); S.draw({role="neutral",role_label="Note",text="Details"})
  equal(calls.tooltip,"Note","custom label")
  S,calls=fake({hovered=true}); S.draw({role="warning",text="Details"})
  equal(calls.tooltip,"Attention","default label")
  S,calls=fake(); S.draw({role="warning",text="Details"})
  equal(calls.tooltip,nil,"no tooltip without hover")
end
function tests.prominent_uses_status_font_and_detail_uses_metadata()
  local S,calls=fake(); S.draw({role="ready",text="Ready to publish",presentation="prominent",detail="Last check 2 min ago"})
  equal(calls.roles[1],"status","prominent font")
  equal(calls.roles[2],"metadata","detail font")
  equal(calls.text[2],"Last check 2 min ago","detail text")
  equal(calls.colors[2],"semantic.color.text.secondary","detail color")
  S,calls=fake(); S.draw({role="ready",text="Ready"})
  equal(calls.roles[1],"body","inline font")
end
function tests.measure_is_glyph_gap_and_text()
  local S,calls=fake()
  equal(S.measure({role="ready",text="Ready",presentation="prominent"}),124,"width")
  equal(calls.roles[1],"status","measure font")
end
function tests.rejects_unknown_role_empty_text_and_presentation()
  local S=fake()
  assert(not pcall(function()S.draw({role="success",text="X"})end),"role rejected")
  assert(not pcall(function()S.draw({role="ready",text=""})end),"text rejected")
  assert(not pcall(function()S.draw({role="ready",text="X",role_label=""})end),"label rejected")
  assert(not pcall(function()S.draw({role="ready",text="X",presentation="banner"})end),"presentation rejected")
end
local passed=0; for n,t in pairs(tests)do local ok,e=pcall(t);if not ok then error(n..": "..tostring(e))end;passed=passed+1 end;return passed
