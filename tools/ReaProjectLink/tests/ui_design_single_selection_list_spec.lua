local list_module = require("reaprojectlink.ui.design_single_selection_list")

local function equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

local function dependencies()
  local calls = {
    selectables = {}, wrapped = {}, colored = {}, tooltips = {},
    colors = 0, popped = 0,
  }
  local ImGui = {
    Col_ChildBg = 1, Col_Text = 2, Col_Border = 3,
    Col_Header = 4, Col_HeaderHovered = 5, Col_HeaderActive = 6,
  }
  function ImGui.PushStyleColor() calls.colors = calls.colors + 1 end
  function ImGui.PopStyleColor(_, count) calls.popped = calls.popped + count end
  function ImGui.BeginDisabled() calls.disabled_begin = true end
  function ImGui.EndDisabled() calls.disabled_end = true end
  function ImGui.BeginChild(_, id, width, height, flags)
    calls.child = { id = id, width = width, height = height, flags = flags }
    return calls.child_visible ~= false
  end
  function ImGui.EndChild() calls.child_ended = true end
  function ImGui.Selectable(_, label, selected)
    table.insert(calls.selectables, { label = label, selected = selected })
    return calls.choose and label:find(calls.choose, 1, true) ~= nil
  end
  function ImGui.IsItemHovered() return calls.hovered == true end
  function ImGui.SetTooltip(_, value) table.insert(calls.tooltips, value) end
  function ImGui.SetItemDefaultFocus() calls.default_focus = true end
  function ImGui.TextWrapped(_, value) table.insert(calls.wrapped, value) end
  function ImGui.TextColored(_, _, value) table.insert(calls.colored, value) end
  local adapter = {}
  function adapter.resolve(id)
    if id == "component.single_selection_list.height.compact" then return 120 end
    if id == "component.single_selection_list.height.standard" then return 200 end
    return 0x112233ff
  end
  local shell = {}
  function shell.draw(options, renderer)
    calls.shell_options = options
    return renderer("##field-" .. options.id)
  end
  return ImGui, adapter, shell, calls
end

local ITEMS = {
  { id = "actor-mixer", label = "Actor-Mixer Hierarchy" },
  { id = "events", label = "Events and named routing objects" },
  { id = "soundbanks", label = "SoundBanks" },
}

local tests = {}

function tests.selection_emits_event_and_non_color_cue()
  local ImGui, adapter, shell, calls = dependencies()
  calls.choose = "Events"
  local list = list_module.create(ImGui, "ctx", adapter, shell)
  local result = list.draw({ id = "structure", value = "actor-mixer", items = ITEMS })
  equal(result.value, "events", "selected value")
  equal(result.events[1].type, "selection.changed", "event type")
  assert(calls.selectables[1].label:find("(selected)", 1, true), "selection cue")
  equal(calls.popped, calls.colors, "style balance")
end

function tests.dynamic_states_are_explicit_and_blocked()
  for _, fixture in ipairs({
    { state = "loading", message = "Loading items...", items = ITEMS },
    { state = "empty", message = "No items", items = {} },
    { state = "failed", message = "Could not load items", items = ITEMS },
  }) do
    local ImGui, adapter, shell, calls = dependencies()
    local list = list_module.create(ImGui, "ctx", adapter, shell)
    local result = list.draw({
      id = fixture.state, items = fixture.items, data_state = fixture.state,
    })
    equal(calls.wrapped[1], fixture.message, fixture.state .. " message")
    equal(result.changed, false, fixture.state .. " unchanged")
  end
end

function tests.stale_selection_is_named_and_recoverable()
  local ImGui, adapter, shell, calls = dependencies()
  calls.choose = "SoundBanks"
  local list = list_module.create(ImGui, "ctx", adapter, shell)
  local result = list.draw({
    id = "structure", value = "removed", stale_label = "Old routing row", items = ITEMS,
  })
  equal(calls.colored[1], "Old routing row (unavailable)", "stale cue")
  equal(result.value, "soundbanks", "recovered value")
  equal(result.stale, false, "recovered stale")
end

function tests.compact_size_and_tooltip_are_applied()
  local ImGui, adapter, shell, calls = dependencies()
  calls.hovered = true
  local list = list_module.create(ImGui, "ctx", adapter, shell)
  list.draw({ id = "structure", value = "events", items = ITEMS, size = "compact" })
  equal(calls.child.height, 120, "compact height")
  equal(calls.tooltips[1], ITEMS[1].label, "complete label tooltip")
end

function tests.disabled_list_suppresses_selection()
  local ImGui, adapter, shell, calls = dependencies()
  calls.choose = "Events"
  local list = list_module.create(ImGui, "ctx", adapter, shell)
  local result = list.draw({
    id = "structure", value = "actor-mixer", items = ITEMS, disabled = true,
  })
  equal(result.changed, false, "disabled unchanged")
  equal(calls.disabled_begin, true, "disabled opened")
  equal(calls.disabled_end, true, "disabled closed")
end

function tests.does_not_end_child_when_content_is_clipped()
  local ImGui, adapter, shell, calls = dependencies()
  calls.child_visible = false
  local list = list_module.create(ImGui, "ctx", adapter, shell)
  local result = list.draw({ id = "structure", value = "events", items = ITEMS })
  equal(calls.child_ended, nil, "clipped child not opened")
  equal(result.value, "events", "selection preserved")
end

function tests.rejects_invalid_items_and_states()
  local ImGui, adapter, shell = dependencies()
  local list = list_module.create(ImGui, "ctx", adapter, shell)
  assert(not pcall(function()
    list.draw({ id = "x", items = {}, data_state = "ready" })
  end), "empty ready rejected")
  assert(not pcall(function()
    list.draw({ id = "x", items = ITEMS, data_state = "empty" })
  end), "populated empty rejected")
  assert(not pcall(function()
    list.draw({ id = "x", items = ITEMS, value = "missing" })
  end), "unnamed stale value rejected")
  assert(not pcall(function()
    list.draw({
      id = "x", items = { { id = "a", label = "A" }, { id = "a", label = "Again" } },
    })
  end), "duplicate items rejected")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
