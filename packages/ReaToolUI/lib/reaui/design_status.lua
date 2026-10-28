local default_icons = require("reaui.icons")

local M = {}
local ROLES = { neutral="Info", ready="Ready", warning="Attention", blocked="Blocked" }
local GLYPHS = { neutral="dot", ready="check", warning="warning", blocked="cross" }
local FONTS = { inline="body", prominent="status" }

function M.create(ImGui, ctx, adapter, icon_renderer)
  icon_renderer = icon_renderer or default_icons
  local component = {}

  local function with_text(role, renderer)
    if adapter.with_text then return adapter.with_text(role, renderer) end
    return renderer()
  end

  local function validate_role(options)
    if not ROLES[options.role] then error("unsupported status role " .. tostring(options.role)) end
    local label = options.role_label or ROLES[options.role]
    if type(label) ~= "string" or label == "" then error("status role_label must be non-empty") end
    return label
  end

  local function validate(options)
    local label = validate_role(options)
    if type(options.text) ~= "string" or options.text == "" then error("status text is required") end
    local presentation = options.presentation or "inline"
    if not FONTS[presentation] then error("unsupported status presentation " .. tostring(presentation)) end
    return FONTS[presentation], label
  end

  -- Draws the role glyph at the current font's line height.
  local function glyph(role, label, color)
    local size = ImGui.GetTextLineHeight(ctx)
    local x, y = ImGui.GetCursorScreenPos(ctx)
    icon_renderer.draw(ImGui, ImGui.GetWindowDrawList(ctx), GLYPHS[role], x, y, size, color)
    ImGui.Dummy(ctx, size, size)
    if ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, label) end
  end

  function component.draw(options)
    options = options or {}
    local font, label = validate(options)
    local color = adapter.resolve("component.status." .. options.role .. ".foreground")
    with_text(font, function()
      local gap = adapter.resolve("semantic.space.inline.default")
      glyph(options.role, label, color)
      ImGui.SameLine(ctx, 0, gap)
      local available = ImGui.GetContentRegionAvail(ctx)
      ImGui.BeginGroup(ctx)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, color)
      ImGui.TextWrapped(ctx, options.text)
      ImGui.PopStyleColor(ctx)
      if options.detail then
        local text_width = ImGui.CalcTextSize(ctx, options.text)
        local text_height = ImGui.GetTextLineHeight(ctx)
        with_text("metadata", function()
          -- The detail follows the text on its line when both fit; otherwise
          -- it takes its own line below.
          if text_width + gap + ImGui.CalcTextSize(ctx, options.detail) <= available then
            ImGui.SameLine(ctx, 0, gap)
            ImGui.SetCursorPosY(ctx, ImGui.GetCursorPosY(ctx) + text_height - ImGui.GetTextLineHeight(ctx))
          end
          ImGui.PushStyleColor(ctx, ImGui.Col_Text, adapter.resolve("semantic.color.text.secondary"))
          ImGui.TextWrapped(ctx, options.detail)
          ImGui.PopStyleColor(ctx)
        end)
      end
      ImGui.EndGroup(ctx)
    end)
  end

  -- The glyph alone, in body size, for components that place their own text.
  function component.draw_glyph(options)
    options = options or {}
    local label = validate_role(options)
    with_text("body", function()
      glyph(options.role, label, adapter.resolve("component.status." .. options.role .. ".foreground"))
    end)
  end

  function component.measure(options)
    options = options or {}
    local font = validate(options)
    return with_text(font, function()
      return ImGui.GetTextLineHeight(ctx) + adapter.resolve("semantic.space.inline.default") +
        ImGui.CalcTextSize(ctx, options.text)
    end)
  end

  return component
end
return M
