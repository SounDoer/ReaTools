local path_field_module=require("reaui.design_path_field")
local M={}
local STATES={idle=true,checking=true,valid=true,invalid=true,unavailable=true}
function M.create(ImGui,ctx,adapter,path_field)
  path_field=path_field or path_field_module.create(ImGui,ctx,adapter);local pattern={}
  function pattern.draw(options)
    options=options or {};local state=options.state or "idle"
    if not STATES[state]then error("unsupported path selection state "..tostring(state))end
    if options.validation~=nil then error("path selection owns validation presentation")end
    if state~="idle" and (type(options.message)~="string" or options.message=="")then error("path selection message is required for "..state)end
    local field_options={};for k,v in pairs(options)do field_options[k]=v end
    field_options.state=nil;field_options.message=nil
    if state=="checking"then field_options.validation={state="pending",message=options.message}
    elseif state=="valid"then field_options.validation={state="valid",message=options.message}
    elseif state=="invalid"then field_options.validation={state="invalid",message=options.message}
    elseif state=="unavailable"then field_options.validation={state="invalid",message=options.message};field_options.browse_disabled=true end
    local result=path_field.draw(field_options);result.state=state;return result
  end
  return pattern
end
return M
