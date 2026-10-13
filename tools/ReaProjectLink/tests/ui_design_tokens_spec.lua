local design_tokens = require("reaui.design_tokens")

local function equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

local function contains(values, fragment)
  for _, value in ipairs(values) do
    if tostring(value):find(fragment, 1, true) then return true end
  end
  return false
end

local tests = {}

local function linear(channel)
  local value = channel / 255
  if value <= 0.04045 then return value / 12.92 end
  return ((value + 0.055) / 1.055) ^ 2.4
end

local function luminance(color)
  local red = (color >> 24) & 0xff
  local green = (color >> 16) & 0xff
  local blue = (color >> 8) & 0xff
  return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
end

local function contrast(first, second)
  local a, b = luminance(first), luminance(second)
  if a < b then a, b = b, a end
  return (a + 0.05) / (b + 0.05)
end

function tests.default_registry_is_valid()
  local errors = design_tokens.validate()
  equal(#errors, 0, "default token errors")
end

function tests.resolves_theme_specific_semantic_tokens()
  equal(design_tokens.resolve("semantic.color.text.primary", "light"), 0x20242aff,
    "light primary text")
  equal(design_tokens.resolve("semantic.color.text.primary", "dark"), 0xf2f4f7ff,
    "dark primary text")
  equal(design_tokens.resolve("semantic.space.container.padding", "light"), 12,
    "shared semantic spacing")
end

function tests.foundation_scales_and_roles_are_registered()
  equal(design_tokens.resolve("semantic.space.section.default", "light"), 16,
    "section spacing")
  equal(design_tokens.resolve("semantic.border.focus.width", "light"), 2,
    "focus width")
  equal(design_tokens.resolve("semantic.radius.control", "light"), 4,
    "control radius")
  equal(design_tokens.resolve("semantic.radius.container", "light"), 8,
    "container radius")
  equal(design_tokens.resolve("semantic.typography.title.font_weight", "light"), "bold",
    "title weight")
  equal(design_tokens.resolve("semantic.typography.code.font_family", "light"), "monospace",
    "code family")
end

function tests.rejects_unknown_tokens_and_themes()
  local value, err = design_tokens.resolve("semantic.color.missing", "light")
  equal(value, nil, "missing token value")
  assert(err and err:find("unknown token", 1, true), "missing token error")
  value, err = design_tokens.resolve("semantic.color.text.primary", "sepia")
  equal(value, nil, "unknown theme value")
  assert(err and err:find("unknown theme", 1, true), "unknown theme error")
end

function tests.detects_missing_theme_values()
  local registry = {
    primitive = {
      color = { neutral = { [0] = { type = "color", value = 0xffffffff } } },
    },
    semantic = {
      color = { text = { primary = {
        type = "color", themes = { light = "primitive.color.neutral.0" },
      } } },
    },
    component = {},
  }
  local errors = design_tokens.validate(registry)
  assert(contains(errors, "missing theme dark"), "missing dark theme is reported")
end

function tests.detects_reference_cycles()
  local registry = {
    primitive = {},
    semantic = {
      space = {
        first = { type = "logical_unit", ref = "semantic.space.second" },
        second = { type = "logical_unit", ref = "semantic.space.first" },
      },
    },
    component = {},
  }
  local errors = design_tokens.validate(registry)
  assert(contains(errors, "reference cycle"), "cycle is reported")
end

function tests.rejects_product_primitive_references()
  local errors = design_tokens.validate_product_references({
    "semantic.color.text.primary",
    "component.button.primary.background.default",
    "primitive.color.neutral.950",
  })
  equal(#errors, 1, "product reference errors")
  assert(errors[1]:find("primitive.color.neutral.950", 1, true), "primitive ID is named")
end

function tests_lists_canonical_ids_in_stable_order()
  local ids = design_tokens.ids()
  assert(#ids > 0, "token IDs exist")
  for index = 2, #ids do
    assert(ids[index - 1] < ids[index], "token IDs are sorted")
  end
  assert(contains(ids, "semantic.color.text.primary"), "semantic text token is listed")
end

function tests.button_text_and_focus_meet_contrast_baselines()
  for _, theme in ipairs(design_tokens.THEMES) do
    local canvas = assert(design_tokens.resolve("semantic.color.surface.canvas", theme))
    local focus = assert(design_tokens.resolve("semantic.color.focus.ring", theme))
    assert(contrast(focus, canvas) >= 3, theme .. " focus contrast")
    for _, variant in ipairs({ "primary", "secondary", "quiet", "danger" }) do
      local foreground = assert(design_tokens.resolve(
        "component.button." .. variant .. ".foreground.default", theme))
      for _, state in ipairs({ "default", "hover", "pressed" }) do
        local background = assert(design_tokens.resolve(
          "component.button." .. variant .. ".background." .. state, theme))
        if (background & 0xff) == 0 then background = canvas end
        assert(contrast(foreground, background) >= 4.5,
          theme .. " " .. variant .. " " .. state .. " text contrast")
      end
    end
  end
end

function tests.field_text_and_statuses_meet_contrast_baselines()
  for _, theme in ipairs(design_tokens.THEMES) do
    local canvas = assert(design_tokens.resolve("semantic.color.surface.canvas", theme))
    for _, role in ipairs({ "description", "message.pending", "message.valid", "message.invalid" }) do
      local token = role == "description"
        and "component.field_shell.description.foreground.default"
        or "component.field_shell." .. role .. ".foreground.default"
      local foreground = assert(design_tokens.resolve(token, theme))
      assert(contrast(foreground, canvas) >= 4.5,
        theme .. " field shell " .. role .. " contrast")
    end

    local foreground = assert(design_tokens.resolve(
      "component.input_control.foreground.default", theme))
    for _, state in ipairs({ "default", "hover", "focused", "read_only" }) do
      local background = assert(design_tokens.resolve(
        "component.input_control.background." .. state, theme))
      assert(contrast(foreground, background) >= 4.5,
        theme .. " text field " .. state .. " contrast")
    end
  end
end

function tests.checkbox_mark_meets_non_text_contrast_baseline()
  for _, theme in ipairs(design_tokens.THEMES) do
    local mark = assert(design_tokens.resolve("component.checkbox.check_mark.default", theme))
    for _, state in ipairs({ "default", "hover", "pressed" }) do
      local background = assert(design_tokens.resolve(
        "component.checkbox.background." .. state, theme))
      assert(contrast(mark, background) >= 3,
        theme .. " checkbox " .. state .. " mark contrast")
    end
  end
end

function tests.segmented_control_text_meets_contrast_baselines()
  for _, theme in ipairs(design_tokens.THEMES) do
    for _, selection in ipairs({ "selected", "unselected" }) do
      local foreground = assert(design_tokens.resolve(
        "component.segmented_control." .. selection .. ".foreground", theme))
      for _, state in ipairs({ "default", "hover", "pressed" }) do
        local background = assert(design_tokens.resolve(
          "component.segmented_control." .. selection .. ".background." .. state, theme))
        assert(contrast(foreground, background) >= 4.5,
          theme .. " segmented " .. selection .. " " .. state .. " contrast")
      end
    end
  end
end

function tests.selection_components_meet_text_contrast_baselines()
  for _, theme in ipairs(design_tokens.THEMES) do
    local dropdown_foreground = assert(design_tokens.resolve(
      "component.dropdown.foreground.default", theme))
    for _, state in ipairs({ "default", "hover", "pressed" }) do
      local background = assert(design_tokens.resolve(
        "component.dropdown.background." .. state, theme))
      assert(contrast(dropdown_foreground, background) >= 4.5,
        theme .. " dropdown " .. state .. " contrast")
    end
    for _, state in ipairs({ "selected", "hover", "pressed" }) do
      local background = assert(design_tokens.resolve(
        "component.single_selection_list.row." .. state, theme))
      local foreground = assert(design_tokens.resolve(
        "component.single_selection_list.foreground", theme))
      assert(contrast(foreground, background) >= 4.5,
        theme .. " selection list " .. state .. " contrast")
    end
  end
end

function tests.status_roles_meet_text_contrast_baseline()
  for _,theme in ipairs(design_tokens.THEMES) do
    local canvas=assert(design_tokens.resolve("semantic.color.surface.canvas",theme))
    for _,role in ipairs({"neutral","ready","warning","blocked"}) do
      local foreground=assert(design_tokens.resolve("component.status."..role..".foreground",theme))
      assert(contrast(foreground,canvas)>=4.5,theme.." "..role.." status contrast")
    end
  end
end

function tests.notice_roles_meet_text_contrast_baseline()
  for _,theme in ipairs(design_tokens.THEMES) do
    local background=assert(design_tokens.resolve("component.notice.background",theme))
    for _,role in ipairs({"neutral","ready","warning","blocked"}) do
      local foreground=assert(design_tokens.resolve("component.notice."..role..".foreground",theme))
      assert(contrast(foreground,background)>=4.5,theme.." "..role.." notice contrast")
    end
  end
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
