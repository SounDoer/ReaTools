local M={}
function M.create(ImGui,ctx,adapter)
  local component={}
  function component.draw(options,render_content)
    options=options or {};if type(options.id)~="string" or options.id=="" then error("disclosure id is required")end
    if type(options.label)~="string" or options.label=="" then error("disclosure label is required")end
    if render_content~=nil and type(render_content)~="function" then error("disclosure content renderer must be a function")end
    local flags=ImGui.TreeNodeFlags_SpanAvailWidth
    if options.default_open then flags=flags|ImGui.TreeNodeFlags_DefaultOpen end
    if options.disabled then ImGui.BeginDisabled(ctx,true)end
    local open=ImGui.TreeNodeEx(ctx,"##disclosure-"..options.id,options.label,flags)
    if options.disabled then ImGui.EndDisabled(ctx)end
    local ok,result=true,nil
    if open then
      if options.description and options.description~="" then
        ImGui.PushStyleColor(ctx,ImGui.Col_Text,adapter.resolve("semantic.color.text.secondary"));ImGui.TextWrapped(ctx,options.description);ImGui.PopStyleColor(ctx)
      end
      if render_content then ok,result=pcall(render_content)end
      ImGui.TreePop(ctx)
    end
    if not ok then error(result,0)end
    return {open=open,result=result}
  end
  return component
end
return M
