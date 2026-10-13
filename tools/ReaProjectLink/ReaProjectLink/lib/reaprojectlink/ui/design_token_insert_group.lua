local text_field_module=require("reaprojectlink.ui.design_text_field")
local button_module=require("reaprojectlink.ui.design_button")
local M={}
function M.create(ImGui,ctx,adapter,text_field,button)
  text_field=text_field or text_field_module.create(ImGui,ctx,adapter)
  button=button or button_module.create(ImGui,ctx,adapter);local pattern={}
  function pattern.draw(options)
    options=options or {};if type(options.tokens)~="table" or #options.tokens==0 then error("token insert group tokens are required")end
    local ids={};for _,token in ipairs(options.tokens)do
      if type(token.id)~="string" or token.id=="" or type(token.label)~="string" or token.label=="" or type(token.value)~="string" or token.value=="" then error("token insert items require id, label, and value")end
      if ids[token.id]then error("duplicate token insert item "..token.id)end;ids[token.id]=true
    end
    local result=text_field.draw(options);local events={}
    for _,event in ipairs(result.events)do table.insert(events,event)end
    local available=ImGui.GetContentRegionAvail(ctx);local gap=adapter.resolve("semantic.space.control.compact_gap");local padding=adapter.resolve("semantic.space.control.padding_x")
    local row_width=0;local inserted
    for index,token in ipairs(options.tokens)do
      local width=ImGui.CalcTextSize(ctx,token.label)+padding*2
      if index>1 and row_width+gap+width<=available then ImGui.SameLine(ctx,0,gap);row_width=row_width+gap+width else row_width=width end
      local event=button.draw({id=options.id.."-token-"..token.id,label=token.label,variant="secondary",disabled=options.disabled or token.disabled})
      if event then inserted=token end
    end
    if inserted then
      result.value=result.value..(options.separator or "")..inserted.value;result.changed=true;result.committed=true
      table.insert(events,{type="token.inserted",id=options.id,token=inserted.id,value=inserted.value})
      table.insert(events,{type="field.changed",id=options.id,value=result.value})
      table.insert(events,{type="field.committed",id=options.id,value=result.value})
    end
    result.events=events;result.inserted_token=inserted and inserted.id or nil;return result
  end
  return pattern
end
return M
