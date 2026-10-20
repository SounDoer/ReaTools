local design_adapter = require("reaui.design_adapter")

local function equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

local function fake_imgui()
  local calls = {
    colors = {}, vars = {}, fonts = {},
    popped_colors = 0, popped_vars = 0, popped_fonts = 0,
  }
  local ImGui = {
    Col_Text = 1,
    Col_WindowBg = 2,
    Col_NavHighlight = 6,
    Col_TextDisabled = 13,
    Col_PopupBg = 14,
    Col_Border = 15,
    Col_Separator = 16,
    Col_ScrollbarBg = 17,
    Col_ScrollbarGrab = 18,
    Col_ScrollbarGrabHovered = 19,
    Col_ScrollbarGrabActive = 20,
    Col_Header = 21,
    Col_HeaderHovered = 22,
    Col_HeaderActive = 23,
    StyleVar_WindowPadding = 3,
    StyleVar_ItemSpacing = 4,
    StyleVar_ItemInnerSpacing = 5,
    StyleVar_IndentSpacing = 6,
    StyleVar_FrameBorderSize = 7,
    StyleVar_WindowRounding = 8,
    StyleVar_ChildRounding = 9,
    StyleVar_FrameRounding = 10,
    StyleVar_PopupRounding = 11,
    StyleVar_DisabledAlpha = 13,
    StyleVar_ScrollbarSize = 14,
    StyleVar_ScrollbarRounding = 15,
    FontFlags_Bold = 12,
  }
  function ImGui.CreateFont(family, size)
    calls.created_font = { family = family, size = size }
    calls.created_count = (calls.created_count or 0) + 1
    return family .. "-" .. size
  end
  function ImGui.Attach(ctx, font)
    calls.attached = { ctx = ctx, font = font }
  end
  function ImGui.PushStyleColor(ctx, key, value)
    table.insert(calls.colors, { ctx = ctx, key = key, value = value })
  end
  function ImGui.PushStyleVar(ctx, key, first, second)
    table.insert(calls.vars, { ctx = ctx, key = key, first = first, second = second })
  end
  function ImGui.PushFont(ctx, font)
    table.insert(calls.fonts, { ctx = ctx, font = font })
  end
  function ImGui.PopStyleColor(_, count) calls.popped_colors = calls.popped_colors + count end
  function ImGui.PopStyleVar(_, count) calls.popped_vars = calls.popped_vars + count end
  function ImGui.PopFont(_) calls.popped_fonts = calls.popped_fonts + 1 end
  return ImGui, calls
end

local tests = {}

function tests.creates_the_system_body_font()
  local ImGui, calls = fake_imgui()
  local adapter = design_adapter.create(ImGui, "ctx", "light")
  equal(calls.created_font.family, "monospace", "last font family")
  equal(calls.created_font.size, 13, "last font size")
  equal(calls.attached.font, "monospace-13", "last attached font")
  equal(adapter.theme(), "light", "initial theme")
end

function tests.pushes_and_restores_the_base_style()
  local ImGui, calls = fake_imgui()
  local adapter = design_adapter.create(ImGui, "ctx", "light")
  adapter.push_base()
  equal(#calls.colors, 14, "pushed colors")
  equal(calls.colors[1].value, 0x1c2024ff, "text color")
  equal(calls.colors[2].value, 0xb9bbc6ff, "disabled text color")
  equal(calls.colors[3].value, 0xfcfcfdff, "canvas color")
  equal(calls.colors[6].value, 0xe0e1e6ff, "divider color")
  equal(calls.colors[14].value, 0x008573ff, "focus color")
  equal(#calls.vars, 12, "pushed vars")
  equal(calls.vars[1].first, 24, "horizontal padding")
  equal(calls.vars[1].second, 24, "vertical padding")
  equal(calls.vars[2].first, 8, "horizontal item spacing")
  equal(calls.vars[2].second, 4, "vertical item spacing")
  equal(calls.vars[3].first, 4, "horizontal inner spacing")
  equal(calls.vars[4].first, 24, "indent spacing")
  equal(#calls.fonts, 1, "pushed fonts")
  adapter.pop_base()
  equal(calls.vars[5].first, 0.60, "disabled alpha")
  equal(calls.vars[6].first, 12, "scrollbar size")
  equal(calls.vars[8].first, 1, "control border width")
  equal(calls.vars[9].first, 8, "window radius")
  equal(calls.vars[11].first, 4, "control radius")
  equal(calls.popped_colors, 14, "popped colors")
  equal(calls.popped_vars, 12, "popped vars")
  equal(calls.popped_fonts, 1, "popped fonts")
end

function tests.exposes_semantic_typography_roles()
  local ImGui, calls = fake_imgui()
  local adapter = design_adapter.create(ImGui, "ctx", "light")
  adapter.push_text("title")
  adapter.pop_text()
  equal(calls.fonts[1].font, "sans-serif-20", "role font pushed")
  equal(calls.popped_fonts, 1, "role font popped")
  assert(not pcall(function() adapter.push_text("missing") end), "unknown role")
  local value = adapter.with_text("heading", function() return "rendered" end)
  equal(value, "rendered", "renderer result")
  local before = calls.popped_fonts
  assert(not pcall(function()
    adapter.with_text("body", function() error("render failed") end)
  end), "renderer error")
  equal(calls.popped_fonts, before + 1, "error restores font")
end

function tests.creates_direction_c_typography_roles()
  local ImGui, calls = fake_imgui()
  local adapter = design_adapter.create(ImGui, "ctx", "light")
  equal(calls.created_count, 8, "one font per typography role")
  adapter.push_text("status")
  equal(calls.fonts[#calls.fonts].font, "sans-serif-15", "status font")
  adapter.push_text("metric")
  equal(calls.fonts[#calls.fonts].font, "sans-serif-22", "metric font")
  adapter.push_text("body")
  equal(calls.fonts[#calls.fonts].font, "sans-serif-14", "body font")
end

function tests.switches_themes_without_recreating_the_contract()
  local ImGui = fake_imgui()
  local adapter = design_adapter.create(ImGui, "ctx", "light")
  adapter.set_theme("dark")
  equal(adapter.theme(), "dark", "changed theme")
  equal(adapter.resolve("semantic.color.text.primary"), 0xedeef0ff, "dark text")
  local ok = pcall(function() adapter.set_theme("sepia") end)
  equal(ok, false, "unknown theme rejected")
end

function tests.prevents_unbalanced_pop()
  local ImGui = fake_imgui()
  local adapter = design_adapter.create(ImGui, "ctx", "light")
  local ok = pcall(adapter.pop_base)
  equal(ok, false, "unbalanced pop rejected")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
