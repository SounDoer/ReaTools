local button_module = require("reaui.design_button")
local M = {}
local ROLES = { neutral="Info", ready="Ready", warning="Attention", blocked="Blocked" }
local FLAGS = (1 << 0) | (1 << 1) | (1 << 5)

function M.create(ImGui,ctx,adapter,button)
  button=button or button_module.create(ImGui,ctx,adapter); local component={}
  local function resolve(id)return adapter.resolve(id)end
  function component.draw(options)
    options=options or {}; local prefix=ROLES[options.role]
    if not prefix then error("unsupported notice role "..tostring(options.role))end
    if type(options.id)~="string" or options.id=="" then error("notice id is required")end
    if type(options.text)~="string" or options.text=="" then error("notice text is required")end
    local actions=options.actions or {}; local ids={}
    for _,action in ipairs(actions)do
      if type(action.id)~="string" or action.id=="" or type(action.label)~="string" or action.label=="" then error("notice actions require id and label")end
      if ids[action.id]then error("duplicate notice action "..action.id)end;ids[action.id]=true
    end
    ImGui.PushStyleColor(ctx,ImGui.Col_ChildBg,resolve("component.notice.background"))
    ImGui.PushStyleColor(ctx,ImGui.Col_Border,resolve("component.notice."..options.role..".border"))
    local padding=resolve("semantic.space.container.padding")
    ImGui.PushStyleVar(ctx,ImGui.StyleVar_WindowPadding,padding,padding)
    local visible=ImGui.BeginChild(ctx,"##notice-"..options.id,0,0,FLAGS)
    ImGui.PopStyleVar(ctx);ImGui.PopStyleColor(ctx,2)
    local chosen
    if visible then
      ImGui.PushStyleColor(ctx,ImGui.Col_Text,resolve("component.notice."..options.role..".foreground"))
      ImGui.TextWrapped(ctx,(options.role_label or prefix)..": "..options.text)
      ImGui.PopStyleColor(ctx)
      local available=ImGui.GetContentRegionAvail(ctx);local gap=resolve("semantic.space.control.gap")
      local total=gap*math.max(0,#actions-1)
      for _,a in ipairs(actions)do total=total+ImGui.CalcTextSize(ctx,a.label)+resolve("semantic.space.control.padding_x")*2 end
      local inline=total<=available
      for index,a in ipairs(actions)do
        if inline and index>1 then ImGui.SameLine(ctx,0,gap)end
        local event=button.draw({id=options.id.."-"..a.id,label=a.label,variant=a.variant or "secondary",disabled=options.disabled or a.disabled,stretch=not inline})
        if event then chosen=a end
      end
    end
    if visible then ImGui.EndChild(ctx) end
    local events={};if chosen then table.insert(events,{type="notice.action_selected",id=options.id,action=chosen.id})end
    return {action=chosen and chosen.id or nil,events=events}
  end
  return component
end
return M
