local status_module=require("reaui.design_status")
local layout_module=require("reaui.design_layout")

local M={}
local VARIANTS={default=true,inset=true}
local ROLES={neutral=true,ready=true,warning=true,blocked=true}
local ISSUE_ROLES={warning=true,blocked=true}

function M.create(ImGui,ctx,adapter,deps)
  deps=deps or {}
  local status=deps.status or status_module.create(ImGui,ctx,adapter)
  local layout=deps.layout or layout_module.create(ImGui,ctx,adapter)
  local component={}
  local function resolve(id)return adapter.resolve(id)end
  local function with_text(role,renderer)
    if adapter.with_text then return adapter.with_text(role,renderer)end
    return renderer()
  end
  local function line_height(role)return with_text(role,function()return ImGui.GetTextLineHeight(ctx)end)end

  local function draw_trailing(options,row_top,row_height,inset)
    if options.role then
      ImGui.SameLine(ctx,0,resolve("semantic.space.inline.default"))
      ImGui.SetCursorPosY(ctx,row_top+(row_height-line_height("body"))/2)
      status.draw_glyph({role=options.role})
    end
    if options.detail then
      local width=with_text("metadata",function()return ImGui.CalcTextSize(ctx,options.detail)end)
      layout.trailing(width+(inset and resolve("semantic.space.inset.padding_x") or 0))
      with_text("metadata",function()
        ImGui.SetCursorPosY(ctx,row_top+(row_height-ImGui.GetTextLineHeight(ctx))/2)
        ImGui.PushStyleColor(ctx,ImGui.Col_Text,resolve("semantic.color.text.secondary"))
        ImGui.Text(ctx,options.detail)
        ImGui.PopStyleColor(ctx)
      end)
    end
  end

  function component.draw(options,render_content)
    options=options or {};if type(options.id)~="string" or options.id=="" then error("disclosure id is required")end
    if type(options.label)~="string" or options.label=="" then error("disclosure label is required")end
    if render_content~=nil and type(render_content)~="function" then error("disclosure content renderer must be a function")end
    local variant=options.variant or "default"
    if not VARIANTS[variant] then error("unsupported disclosure variant "..tostring(variant))end
    if options.role~=nil and not ROLES[options.role] then error("unsupported disclosure role "..tostring(options.role))end
    if options.detail~=nil and (type(options.detail)~="string" or options.detail=="") then error("disclosure detail must be non-empty")end
    local inset=variant=="inset"
    local flags=ImGui.TreeNodeFlags_SpanAvailWidth
    if options.default_open or (inset and ISSUE_ROLES[options.role]) then flags=flags|ImGui.TreeNodeFlags_DefaultOpen end
    local row_top=(options.role or options.detail) and ImGui.GetCursorPosY(ctx)
    if inset then
      flags=flags|ImGui.TreeNodeFlags_Framed
      ImGui.PushStyleColor(ctx,ImGui.Col_Header,resolve("semantic.color.surface.inset"))
      ImGui.PushStyleColor(ctx,ImGui.Col_HeaderHovered,resolve("semantic.color.action.quiet.background.hover"))
      ImGui.PushStyleColor(ctx,ImGui.Col_HeaderActive,resolve("semantic.color.action.quiet.background.pressed"))
      ImGui.PushStyleVar(ctx,ImGui.StyleVar_FramePadding,resolve("semantic.space.inset.padding_x"),
        (resolve("semantic.size.row.single")-line_height("body"))/2)
      ImGui.PushStyleVar(ctx,ImGui.StyleVar_FrameRounding,resolve("semantic.radius.control"))
    end
    if options.disabled then ImGui.BeginDisabled(ctx,true)end
    local open=ImGui.TreeNodeEx(ctx,"##disclosure-"..options.id,options.label,flags)
    if options.disabled then ImGui.EndDisabled(ctx)end
    if inset then ImGui.PopStyleVar(ctx,2);ImGui.PopStyleColor(ctx,3)end
    local ok,result=true,nil
    if row_top then
      local _,row_height=ImGui.GetItemRectSize(ctx)
      ok,result=pcall(draw_trailing,options,row_top,row_height,inset)
    end
    if open then
      if ok and options.description and options.description~="" then
        ImGui.PushStyleColor(ctx,ImGui.Col_Text,resolve("semantic.color.text.secondary"));ImGui.TextWrapped(ctx,options.description);ImGui.PopStyleColor(ctx)
      end
      if ok and render_content then ok,result=pcall(render_content)end
      ImGui.TreePop(ctx)
    end
    if not ok then error(result,0)end
    return {open=open,result=result}
  end
  return component
end
return M
