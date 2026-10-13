local button_module=require("reaui.design_button")
local M={}
function M.create(ImGui,ctx,adapter,button)
  button=button or button_module.create(ImGui,ctx,adapter);local component={}
  function component.draw(options)
    options=options or {};if type(options.id)~="string" or options.id=="" then error("menu id is required")end
    if type(options.items)~="table" or #options.items==0 then error("menu items are required")end
    local ids={}
    for _,item in ipairs(options.items)do if not item.separator then
      if type(item.id)~="string" or item.id=="" or type(item.label)~="string" or item.label=="" then error("menu actions require id and label")end
      if ids[item.id]then error("duplicate menu action "..item.id)end;ids[item.id]=true
    end end
    local trigger=button.draw_icon({id=options.id.."-open",icon="more",accessible_label=options.accessible_label or "More actions",variant="quiet",disabled=options.disabled})
    if trigger then ImGui.OpenPopup(ctx,"##menu-"..options.id)end
    local chosen
    if ImGui.BeginPopup(ctx,"##menu-"..options.id)then
      for _,item in ipairs(options.items)do
        if item.separator then ImGui.Separator(ctx) else
          if item.disabled then ImGui.BeginDisabled(ctx,true)end
          if item.danger then ImGui.PushStyleColor(ctx,ImGui.Col_Text,adapter.resolve("component.button.danger.foreground.default"))end
          local clicked=ImGui.MenuItem(ctx,item.label)
          if item.danger then ImGui.PopStyleColor(ctx)end
          if item.disabled then ImGui.EndDisabled(ctx)end
          if clicked and not item.disabled then chosen=item end
        end
      end
      ImGui.EndPopup(ctx)
    end
    local events={};if chosen then table.insert(events,{type="menu.action_selected",id=options.id,action=chosen.id})end
    return {action=chosen and chosen.id or nil,events=events}
  end
  return component
end
return M
