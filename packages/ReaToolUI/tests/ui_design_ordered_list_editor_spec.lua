local module = require("reaui.design_ordered_list_editor")

local function equal(actual, expected, label)
  if actual ~= expected then
    error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

local ITEMS = {
  { id = "source", label = "Source path" },
  { id = "rename", label = "Rename object" },
  { id = "transfer", label = "Transfer audio" },
}

local function dependencies()
  local calls = { buttons = {}, available = 500 }
  local ImGui = {
    GetContentRegionAvail = function() return calls.available end,
    CalcTextSize = function(_, value) return #value * 7 end,
    SameLine = function() calls.same_lines = (calls.same_lines or 0) + 1 end,
  }
  local adapter = {
    resolve = function(id) return id:find("compact_gap", 1, true) and 4 or 12 end,
  }
  local list = {
    draw_field = function(options)
      calls.list_options = options
      local value = calls.selected_value or options.value
      local item
      for _, candidate in ipairs(options.items) do
        if candidate.id == value then item = candidate end
      end
      return {
        value = value, item = item, changed = calls.selected_value ~= nil,
        events = calls.list_events or {},
      }
    end,
  }
  local button = {
    draw = function(options)
      table.insert(calls.buttons, options)
      if calls.click == options.id and not options.disabled then return { type = "button.activated" } end
    end,
  }
  return ImGui, adapter, list, button, calls
end

local tests = {}

function tests.forwards_selection_before_action_and_uses_new_selection()
  local ImGui, adapter, list, button, calls = dependencies()
  calls.selected_value = "rename"
  calls.list_events = { { type = "selection.changed", value = "rename" } }
  calls.click = "steps-down"
  local result = module.create(ImGui, "ctx", adapter, list, button).draw({
    id = "steps", label = "Transfer steps", value = "source", items = ITEMS,
  })
  equal(result.value, "rename", "value")
  equal(result.index, 2, "index")
  equal(result.events[1].type, "selection.changed", "selection first")
  equal(result.events[2].type, "ordered_list.move_requested", "move second")
  equal(result.events[2].direction, "down", "direction")
end

function tests.add_is_available_without_selection_and_delete_is_blocked()
  local ImGui, adapter, list, button, calls = dependencies()
  calls.click = "steps-add"
  local result = module.create(ImGui, "ctx", adapter, list, button).draw({
    id = "steps", label = "Transfer steps", items = ITEMS,
  })
  equal(result.events[1].type, "ordered_list.add_requested", "add event")
  equal(calls.buttons[2].disabled, true, "delete disabled")
  equal(calls.buttons[3].disabled, true, "up disabled")
  equal(calls.buttons[4].disabled, true, "down disabled")
end

function tests.boundary_moves_and_global_disabled_are_enforced()
  local ImGui, adapter, list, button, calls = dependencies()
  module.create(ImGui, "ctx", adapter, list, button).draw({
    id = "steps", label = "Transfer steps", value = "source", items = ITEMS,
  })
  equal(calls.buttons[3].disabled, true, "first cannot move up")
  equal(calls.buttons[4].disabled, false, "first can move down")

  ImGui, adapter, list, button, calls = dependencies()
  module.create(ImGui, "ctx", adapter, list, button).draw({
    id = "steps", label = "Transfer steps", value = "transfer", items = ITEMS,
    disabled = true,
  })
  for index, call in ipairs(calls.buttons) do
    equal(call.disabled, true, "disabled action " .. index)
  end
end

function tests.editor_receives_selected_item_and_index()
  local ImGui, adapter, list, button = dependencies()
  local rendered_item, rendered_index
  module.create(ImGui, "ctx", adapter, list, button).draw({
    id = "steps", label = "Transfer steps", value = "rename", items = ITEMS,
    render_editor = function(item, index)
      rendered_item, rendered_index = item, index
    end,
  })
  equal(rendered_item.id, "rename", "editor item")
  equal(rendered_index, 2, "editor index")
end

function tests.actions_wrap_when_width_is_narrow()
  local ImGui, adapter, list, button, calls = dependencies()
  calls.available = 65
  module.create(ImGui, "ctx", adapter, list, button).draw({
    id = "steps", label = "Transfer steps", value = "rename", items = ITEMS,
  })
  equal(calls.same_lines, nil, "narrow actions wrap")
end

function tests.rejects_missing_identity_and_invalid_editor()
  local ImGui, adapter, list, button = dependencies()
  local pattern = module.create(ImGui, "ctx", adapter, list, button)
  assert(not pcall(function() pattern.draw({ label = "Rows", items = ITEMS }) end), "id")
  assert(not pcall(function() pattern.draw({ id = "rows", items = ITEMS }) end), "label")
  assert(not pcall(function()
    pattern.draw({ id = "rows", label = "Rows", items = ITEMS, render_editor = true })
  end), "editor")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
