local segmented_module = require("reaprojectlink.ui.design_segmented_control")

local function equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

local function dependencies()
  local calls = { buttons = {}, same_line = 0, colors = 0, popped = 0 }
  local ImGui = {
    Col_Button = 1, Col_ButtonHovered = 2, Col_ButtonActive = 3,
    Col_Text = 4, Col_Border = 5,
  }
  function ImGui.GetContentRegionAvail() return calls.available or 500 end
  function ImGui.CalcTextSize(_, value) return #value * 7 end
  function ImGui.SameLine() calls.same_line = calls.same_line + 1 end
  function ImGui.PushStyleColor() calls.colors = calls.colors + 1 end
  function ImGui.PopStyleColor(_, count) calls.popped = calls.popped + count end
  function ImGui.BeginDisabled() calls.disabled_begin = true end
  function ImGui.EndDisabled() calls.disabled_end = true end
  function ImGui.Button(_, label, width, height)
    table.insert(calls.buttons, { label = label, width = width, height = height })
    return calls.click and label:find(calls.click, 1, true) ~= nil
  end
  local adapter = {}
  function adapter.resolve(id)
    local values = {
      ["semantic.space.control.padding_x"] = 12,
      ["semantic.space.control.compact_gap"] = 4,
      ["semantic.size.control.medium"] = 32,
    }
    return values[id] or 0x112233ff
  end
  local shell = {}
  function shell.draw(options, renderer)
    calls.shell_options = options
    return renderer("##field-" .. options.id)
  end
  return ImGui, adapter, shell, calls
end

local OPTIONS = {
  { id = "auto", label = "Auto" },
  { id = "light", label = "Light" },
  { id = "dark", label = "Dark" },
}

local tests = {}

function tests.selects_an_unselected_option()
  local ImGui, adapter, shell, calls = dependencies()
  calls.click = "Dark"
  local segmented = segmented_module.create(ImGui, "ctx", adapter, shell)
  local result = segmented.draw({ id = "theme", value = "auto", options = OPTIONS })
  equal(result.value, "dark", "selected value")
  equal(result.events[1].type, "selection.changed", "event type")
  equal(result.events[1].option.label, "Dark", "selected option")
  equal(calls.buttons[1].width, calls.buttons[2].width, "equal widths")
  equal(calls.popped, calls.colors, "style balance")
end

function tests.selected_and_disabled_activation_are_suppressed()
  local ImGui, adapter, shell, calls = dependencies()
  calls.click = "Auto"
  local segmented = segmented_module.create(ImGui, "ctx", adapter, shell)
  local selected = segmented.draw({ id = "theme", value = "auto", options = OPTIONS })
  equal(selected.changed, false, "selected unchanged")
  calls.click = "Dark"
  local disabled = segmented.draw({
    id = "disabled", value = "auto", options = OPTIONS, disabled = true,
  })
  equal(disabled.changed, false, "disabled unchanged")
  equal(calls.disabled_begin, true, "disabled opened")
  equal(calls.disabled_end, true, "disabled closed")
end

function tests.narrow_layout_stacks_full_width_options()
  local ImGui, adapter, shell, calls = dependencies()
  calls.available = 100
  local segmented = segmented_module.create(ImGui, "ctx", adapter, shell)
  local result = segmented.draw({ id = "theme", value = "auto", options = OPTIONS })
  equal(result.layout, "stacked", "layout")
  equal(calls.buttons[1].width, -1, "full width")
  equal(calls.same_line, 0, "no inline options")
end

function tests.field_composition_preserves_validation()
  local ImGui, adapter, shell, calls = dependencies()
  local segmented = segmented_module.create(ImGui, "ctx", adapter, shell)
  segmented.draw_field({
    id = "theme", label = "Theme", value = "auto", options = OPTIONS,
    validation = { state = "invalid", message = "Choose a supported theme." },
  })
  equal(calls.shell_options.validation.state, "invalid", "validation")
end

function tests.rejects_invalid_options_and_values()
  local ImGui, adapter, shell = dependencies()
  local segmented = segmented_module.create(ImGui, "ctx", adapter, shell)
  assert(not pcall(function()
    segmented.draw({ id = "x", value = "a", options = { { id = "a", label = "A" } } })
  end), "one option rejected")
  assert(not pcall(function()
    segmented.draw({ id = "x", value = "missing", options = OPTIONS })
  end), "missing value rejected")
  assert(not pcall(function()
    segmented.draw({
      id = "x", value = "a",
      options = { { id = "a", label = "A" }, { id = "a", label = "Again" } },
    })
  end), "duplicate option rejected")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
