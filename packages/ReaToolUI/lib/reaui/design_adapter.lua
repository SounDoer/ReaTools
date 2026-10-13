local design_tokens = require("reaui.design_tokens")

local M = {}

function M.create(ImGui, ctx, initial_theme)
  local current_theme = initial_theme or "dark"
  local pushed = 0
  local nav_color = ImGui.Col_NavHighlight
  local base_color_count = nav_color and 14 or 13
  local base_style_var_count = 12

  local function resolve(id)
    local value, err = design_tokens.resolve(id, current_theme)
    if value == nil then error(err) end
    return value
  end

  local fonts = {}
  for _, role in ipairs({ "title", "heading", "body", "label", "metadata", "code" }) do
    local weight = resolve("semantic.typography." .. role .. ".font_weight")
    fonts[role] = ImGui.CreateFont(
      resolve("semantic.typography." .. role .. ".font_family"),
      resolve("semantic.typography." .. role .. ".font_size"),
      weight == "bold" and ImGui.FontFlags_Bold or nil
    )
    ImGui.Attach(ctx, fonts[role])
  end

  local adapter = {}

  function adapter.theme() return current_theme end

  function adapter.set_theme(theme)
    local _, err = design_tokens.resolve("semantic.color.text.primary", theme)
    if err then error(err) end
    current_theme = theme
  end

  function adapter.resolve(id) return resolve(id) end

  function adapter.push_text(role)
    if not fonts[role] then error("unsupported typography role " .. tostring(role)) end
    ImGui.PushFont(ctx, fonts[role])
  end

  function adapter.pop_text() ImGui.PopFont(ctx) end

  function adapter.with_text(role, renderer)
    if type(renderer) ~= "function" then error("typography renderer must be a function") end
    adapter.push_text(role)
    local result = table.pack(pcall(renderer))
    adapter.pop_text()
    if not result[1] then error(result[2], 0) end
    return table.unpack(result, 2, result.n)
  end

  function adapter.push_base()
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, resolve("semantic.color.text.primary"))
    ImGui.PushStyleColor(ctx, ImGui.Col_TextDisabled, resolve("semantic.color.text.disabled"))
    ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, resolve("semantic.color.surface.canvas"))
    ImGui.PushStyleColor(ctx, ImGui.Col_PopupBg, resolve("semantic.color.surface.popup"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Border, resolve("semantic.color.border.subtle"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Separator, resolve("semantic.color.border.divider"))
    ImGui.PushStyleColor(ctx, ImGui.Col_ScrollbarBg, resolve("semantic.color.scrollbar.track"))
    ImGui.PushStyleColor(ctx, ImGui.Col_ScrollbarGrab, resolve("semantic.color.scrollbar.grab"))
    ImGui.PushStyleColor(ctx, ImGui.Col_ScrollbarGrabHovered,
      resolve("semantic.color.scrollbar.hover"))
    ImGui.PushStyleColor(ctx, ImGui.Col_ScrollbarGrabActive,
      resolve("semantic.color.scrollbar.active"))
    ImGui.PushStyleColor(ctx, ImGui.Col_Header, resolve("semantic.color.selection.default"))
    ImGui.PushStyleColor(ctx, ImGui.Col_HeaderHovered, resolve("semantic.color.selection.hover"))
    ImGui.PushStyleColor(ctx, ImGui.Col_HeaderActive, resolve("semantic.color.selection.pressed"))
    if nav_color then
      ImGui.PushStyleColor(ctx, nav_color, resolve("semantic.color.focus.ring"))
    end
    local padding = resolve("semantic.space.page.padding")
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, padding, padding)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing,
      resolve("semantic.space.item.horizontal"),
      resolve("semantic.space.item.vertical"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemInnerSpacing,
      resolve("semantic.space.inline.tight"),
      resolve("semantic.space.inline.tight"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_IndentSpacing,
      resolve("semantic.space.indent.default"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_DisabledAlpha,
      resolve("semantic.opacity.disabled"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ScrollbarSize,
      resolve("semantic.size.scrollbar.standard"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ScrollbarRounding,
      resolve("semantic.radius.control"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameBorderSize,
      resolve("semantic.border.control.width"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowRounding,
      resolve("semantic.radius.container"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildRounding,
      resolve("semantic.radius.container"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding,
      resolve("semantic.radius.control"))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_PopupRounding,
      resolve("semantic.radius.popup"))
    ImGui.PushFont(ctx, fonts.body)
    pushed = pushed + 1
  end

  function adapter.pop_base()
    if pushed == 0 then error("design adapter pop_base without matching push_base") end
    ImGui.PopFont(ctx)
    ImGui.PopStyleVar(ctx, base_style_var_count)
    ImGui.PopStyleColor(ctx, base_color_count)
    pushed = pushed - 1
  end

  return adapter
end

return M
