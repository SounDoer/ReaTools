local path_field_module = require("reaui.design_path_field")

local function equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

local function dependencies()
  local calls = { buttons = {}, same_line = 0 }
  local ImGui = {}
  function ImGui.GetContentRegionAvail() return calls.available or 600 end
  function ImGui.CalcTextSize(_, value) return #value * 7 end
  function ImGui.SameLine() calls.same_line = calls.same_line + 1 end
  local adapter = {}
  function adapter.resolve(id)
    local values = {
      ["semantic.space.control.gap"] = 8,
      ["semantic.space.control.padding_x"] = 12,
      ["semantic.size.field.minimum_input"] = 96,
      ["component.path_field.layout.inline_min_width"] = 360,
    }
    return assert(values[id], id)
  end
  local shell = {}
  function shell.draw(options, renderer)
    calls.shell_options = options
    return renderer("##field-" .. options.id)
  end
  local input = {}
  function input.draw(options)
    calls.input_options = options
    return calls.input_result or {
      value = options.value, changed = false, committed = false,
    }
  end
  local button = {}
  function button.draw(options)
    table.insert(calls.buttons, options)
    if calls.browse_clicked and not options.disabled then
      return { type = "button.activated", id = options.id }
    end
    return nil
  end
  return ImGui, adapter, shell, input, button, calls
end

local tests = {}

function tests.edit_and_browse_events_preserve_order_and_kind()
  local ImGui, adapter, shell, input, button, calls = dependencies()
  calls.input_result = {
    value = "C:/Audio/Game.wproj", changed = true, committed = true,
  }
  calls.browse_clicked = true
  local field = path_field_module.create(ImGui, "ctx", adapter, shell, input, button)
  local result = field.draw({
    id = "wwise-project", label = "Wwise project", kind = "file",
    value = "C:/Audio/Old.wproj",
  })
  equal(result.events[1].type, "field.changed", "change event")
  equal(result.events[2].type, "field.committed", "commit event")
  equal(result.events[3].type, "path.browse_requested", "browse event")
  equal(result.events[3].kind, "file", "path kind")
  equal(result.events[3].value, "C:/Audio/Game.wproj", "current path")
end

function tests.read_only_path_remains_browsable()
  local ImGui, adapter, shell, input, button, calls = dependencies()
  calls.browse_clicked = true
  local field = path_field_module.create(ImGui, "ctx", adapter, shell, input, button)
  local result = field.draw({
    id = "project", label = "Selected project", kind = "file",
    value = "C:/Audio/Project.rpp", read_only = true, browse_label = "Change...",
  })
  equal(calls.input_options.read_only, true, "read-only input")
  equal(calls.buttons[1].disabled, false, "browse available")
  equal(calls.buttons[1].label, "Change...", "browse wording")
  equal(result.browse_requested, true, "browse event")
end

function tests.disabled_boundaries_suppress_browse()
  local ImGui, adapter, shell, input, button, calls = dependencies()
  calls.browse_clicked = true
  local field = path_field_module.create(ImGui, "ctx", adapter, shell, input, button)
  local disabled = field.draw({
    id = "disabled", label = "Disabled", kind = "folder", disabled = true,
  })
  equal(calls.buttons[1].disabled, true, "disabled field button")
  equal(disabled.browse_requested, false, "disabled browse")
  calls.buttons = {}
  local unavailable = field.draw({
    id = "unavailable", label = "Unavailable", kind = "folder",
    browse_disabled = true,
  })
  equal(calls.buttons[1].disabled, true, "browse-disabled button")
  equal(unavailable.browse_requested, false, "browse-disabled event")
end

function tests.invalid_state_reaches_input_border()
  local ImGui, adapter, shell, input, button, calls = dependencies()
  local field = path_field_module.create(ImGui, "ctx", adapter, shell, input, button)
  field.draw({
    id = "originals", label = "Originals folder", kind = "folder",
    validation = { state = "invalid", message = "Choose a folder inside Originals." },
  })
  equal(calls.input_options.invalid, true, "invalid input")
end

function tests.narrow_layout_stacks_full_width_action()
  local ImGui, adapter, shell, input, button, calls = dependencies()
  calls.available = 300
  local field = path_field_module.create(ImGui, "ctx", adapter, shell, input, button)
  local result = field.draw({ id = "folder", label = "Folder", kind = "folder" })
  equal(result.layout, "stacked", "layout")
  equal(calls.input_options.width, -1, "input width")
  equal(calls.buttons[1].stretch, true, "button stretch")
  equal(calls.same_line, 0, "no inline placement")
end

function tests.long_values_are_returned_without_rewriting()
  local ImGui, adapter, shell, input, button = dependencies()
  local field = path_field_module.create(ImGui, "ctx", adapter, shell, input, button)
  local path = "//Studio-NAS/Projects/Trailer/Audio/Originals/SFX/Forest/Night"
  local result = field.draw({
    id = "long", label = "Long path", kind = "folder", value = path,
  })
  equal(result.value, path, "complete path")
end

function tests.rejects_invalid_options()
  local ImGui, adapter, shell, input, button = dependencies()
  local field = path_field_module.create(ImGui, "ctx", adapter, shell, input, button)
  assert(not pcall(function()
    field.draw({ id = "x", label = "X", kind = "drive" })
  end), "unknown kind rejected")
  assert(not pcall(function()
    field.draw({ id = "x", label = "X", kind = "file", value = 1 })
  end), "non-string value rejected")
  assert(not pcall(function()
    field.draw({ id = "x", label = "X", kind = "file", browse_label = "" })
  end), "empty browse label rejected")
  assert(not pcall(function()
    field.draw({
      id = "x", label = "X", kind = "file", disabled = true, read_only = true,
    })
  end), "disabled read-only combination rejected")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
