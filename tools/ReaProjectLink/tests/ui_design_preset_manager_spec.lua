local module = require("reaprojectlink.ui.design_preset_manager")

local function equal(actual, expected, label)
  if actual ~= expected then
    error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

local PRESETS = {
  { id = "dialogue", label = "Dialogue transfer" },
  { id = "ambience", label = "Ambience transfer" },
}

local function dependencies()
  local calls = { buttons = {}, available = 500 }
  local ImGui = {
    GetContentRegionAvail = function() return calls.available end,
    CalcTextSize = function(_, value) return #value * 7 end,
    SameLine = function() calls.same = (calls.same or 0) + 1 end,
  }
  local adapter = { resolve = function(id) return id:find("gap", 1, true) and 4 or 12 end }
  local dropdown = {
    draw_field = function(options)
      calls.dropdown = options
      local value = calls.selection or options.value
      local item
      for _, candidate in ipairs(options.options) do if candidate.id == value then item = candidate end end
      return { value = value, option = item, changed = calls.selection ~= nil, events = calls.select_events or {} }
    end,
  }
  local field = {
    draw = function(options)
      calls.field = options
      return { value = calls.name or options.value, changed = calls.name ~= nil, events = calls.name_events or {} }
    end,
  }
  local button = {
    draw = function(options)
      table.insert(calls.buttons, options)
      if calls.click == options.id and not options.disabled and not options.running then return {} end
    end,
  }
  return ImGui, adapter, dropdown, field, button, calls
end

local tests = {}

function tests.forwards_input_events_before_save_request()
  local ImGui, adapter, dropdown, field, button, calls = dependencies()
  calls.select_events = { { type = "selection.changed" } }
  calls.name_events = { { type = "field.changed" } }
  calls.selection = "ambience"
  calls.name = "Night ambience"
  calls.click = "presets-save"
  local result = module.create(ImGui, "ctx", adapter, dropdown, field, button).draw({
    id = "presets", label = "Transfer preset", presets = PRESETS, value = "dialogue",
  })
  equal(result.events[1].type, "selection.changed", "selection first")
  equal(result.events[2].type, "field.changed", "name second")
  equal(result.events[3].type, "preset.save_requested", "save last")
  equal(result.events[3].name, "Night ambience", "save name")
  equal(result.events[3].value, "ambience", "save selection")
end

function tests.no_selection_blocks_load_and_delete_but_named_save_remains()
  local ImGui, adapter, dropdown, field, button, calls = dependencies()
  calls.name = "New preset"
  module.create(ImGui, "ctx", adapter, dropdown, field, button).draw({
    id = "presets", label = "Preset", presets = PRESETS,
  })
  equal(calls.buttons[1].disabled, false, "save enabled")
  equal(calls.buttons[2].disabled, true, "load disabled")
  equal(calls.buttons[3].disabled, true, "delete disabled")
end

function tests.blank_name_blocks_save_and_busy_blocks_everything()
  local ImGui, adapter, dropdown, field, button, calls = dependencies()
  calls.name = "   "
  module.create(ImGui, "ctx", adapter, dropdown, field, button).draw({
    id = "presets", label = "Preset", presets = PRESETS, value = "dialogue",
  })
  equal(calls.buttons[1].disabled, true, "blank save disabled")

  ImGui, adapter, dropdown, field, button, calls = dependencies()
  module.create(ImGui, "ctx", adapter, dropdown, field, button).draw({
    id = "presets", label = "Preset", presets = PRESETS, value = "dialogue",
    busy = true, busy_action = "save",
  })
  equal(calls.dropdown.disabled, true, "busy selection disabled")
  equal(calls.field.disabled, true, "busy name disabled")
  for index, call in ipairs(calls.buttons) do equal(call.disabled, true, "busy action " .. index) end
end

function tests.load_and_delete_include_selected_item()
  for _, action in ipairs({ "load", "delete" }) do
    local ImGui, adapter, dropdown, field, button, calls = dependencies()
    calls.click = "presets-" .. action
    local result = module.create(ImGui, "ctx", adapter, dropdown, field, button).draw({
      id = "presets", label = "Preset", presets = PRESETS, value = "dialogue",
    })
    equal(result.events[1].type, "preset." .. action .. "_requested", action .. " type")
    equal(result.events[1].item.id, "dialogue", action .. " item")
  end
end

function tests.narrow_actions_wrap_and_invalid_inputs_fail()
  local ImGui, adapter, dropdown, field, button, calls = dependencies()
  calls.available = 50
  local pattern = module.create(ImGui, "ctx", adapter, dropdown, field, button)
  pattern.draw({ id = "presets", label = "Preset", presets = PRESETS, value = "dialogue" })
  equal(calls.same, nil, "wrapped")
  assert(not pcall(function() pattern.draw({ label = "Preset", presets = PRESETS }) end), "id")
  assert(not pcall(function() pattern.draw({ id = "x", presets = PRESETS }) end), "label")
  assert(not pcall(function()
    pattern.draw({ id = "x", label = "Preset", presets = PRESETS, draft_name = 2 })
  end), "name")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
