local design_button = require("reaui.design_button")

local function equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

local function fake_dependencies()
  local calls = {
    buttons = {}, colors = {}, popped_colors = 0,
    disabled_begin = 0, disabled_end = 0, icons = {}, tooltips = {},
  }
  local ImGui = {
    Col_Button = 1,
    Col_ButtonHovered = 2,
    Col_ButtonActive = 3,
    Col_Text = 4,
    Col_Border = 5,
  }
  function ImGui.PushStyleColor(_, key, value)
    table.insert(calls.colors, { key = key, value = value })
  end
  function ImGui.PopStyleColor(_, count) calls.popped_colors = calls.popped_colors + count end
  function ImGui.BeginDisabled() calls.disabled_begin = calls.disabled_begin + 1 end
  function ImGui.EndDisabled() calls.disabled_end = calls.disabled_end + 1 end
  function ImGui.CalcTextSize(_, text) return #text * 7, 13 end
  function ImGui.GetContentRegionAvail() return 240 end
  function ImGui.Button(_, label, width, height)
    table.insert(calls.buttons, { label = label, width = width, height = height })
    return calls.next_click == true
  end
  function ImGui.GetCursorScreenPos() return 10, 20 end
  function ImGui.GetWindowDrawList() return "draw-list" end
  function ImGui.IsItemHovered() return calls.hovered == true end
  function ImGui.SetTooltip(_, text) table.insert(calls.tooltips, text) end

  local adapter = {}
  function adapter.resolve(id)
    calls.last_token = id
    if id == "semantic.size.control.medium" then return 32 end
    if id == "semantic.size.control.compact" then return 28 end
    if id:find("padding_x", 1, true) then return 12 end
    if id:find("icon.medium", 1, true) then return 16 end
    return 0x112233ff
  end

  local icon_renderer = {}
  function icon_renderer.draw(_, draw_list, name, x, y, size, color)
    table.insert(calls.icons, {
      draw_list = draw_list, name = name, x = x, y = y, size = size, color = color,
    })
    return name ~= "missing"
  end

  return ImGui, adapter, icon_renderer, calls
end

local tests = {}

function tests.emits_a_semantic_activation_event()
  local ImGui, adapter, icons, calls = fake_dependencies()
  calls.next_click = true
  local button = design_button.create(ImGui, "ctx", adapter, icons)
  local event = button.draw({ id = "publish", label = "Publish", variant = "primary" })
  equal(event.type, "button.activated", "event type")
  equal(event.id, "publish", "event id")
  equal(calls.buttons[1].height, 32, "button height")
  equal(calls.buttons[1].width, 7 * #"Publish" + 24, "content width")
  equal(calls.popped_colors, 5, "styles restored")
end

function tests.button_text_uses_the_body_role()
  local ImGui, adapter, icons = fake_dependencies()
  local roles = {}
  function adapter.with_text(role, renderer) table.insert(roles, role); return renderer() end
  design_button.create(ImGui, "ctx", adapter, icons).draw({ id = "publish", label = "Publish" })
  equal(roles[1], "body", "button typography role")
end

function tests.stretch_fills_the_available_width()
  local ImGui, adapter, icons, calls = fake_dependencies()
  local button = design_button.create(ImGui, "ctx", adapter, icons)
  button.draw({ id = "retry", label = "Retry", variant = "secondary", stretch = true })
  equal(calls.buttons[1].width, 240, "stretched width")
end

function tests.disabled_and_running_buttons_do_not_activate()
  local ImGui, adapter, icons, calls = fake_dependencies()
  calls.next_click = true
  local button = design_button.create(ImGui, "ctx", adapter, icons)
  local event = button.draw({ id = "disabled", label = "Retry", disabled = true })
  equal(event, nil, "disabled event")
  event = button.draw({
    id = "running", label = "Publish", running = true, running_label = "Publishing...",
  })
  equal(event, nil, "running event")
  equal(calls.disabled_begin, 2, "disabled scopes")
  equal(calls.disabled_end, 2, "closed disabled scopes")
  equal(calls.buttons[2].label, "Publishing...##running", "running label")
  equal(calls.buttons[2].width, 7 * #"Publishing..." + 24, "stable running width")
end

function tests.validates_button_inputs()
  local ImGui, adapter, icons = fake_dependencies()
  local button = design_button.create(ImGui, "ctx", adapter, icons)
  assert(not pcall(function() button.draw({ id = "missing-label" }) end), "label is required")
  assert(not pcall(function()
    button.draw({ id = "bad", label = "Bad", variant = "loud" })
  end), "unknown variant is rejected")
  assert(not pcall(function()
    button.draw({ id = "running", label = "Run", running = true })
  end), "running label is required")
end

function tests.draws_icon_buttons_with_labels_and_tooltips()
  local ImGui, adapter, icons, calls = fake_dependencies()
  calls.next_click = true
  calls.hovered = true
  local button = design_button.create(ImGui, "ctx", adapter, icons)
  local event = button.draw_icon({
    id = "settings", icon = "gear", accessible_label = "Open settings", variant = "quiet",
  })
  equal(event.type, "button.activated", "icon event type")
  equal(event.id, "settings", "icon event id")
  equal(calls.buttons[1].width, 32, "icon hit width")
  equal(calls.buttons[1].height, 32, "icon hit height")
  equal(calls.icons[1].name, "gear", "icon name")
  equal(calls.icons[1].size, 16, "icon size")
  equal(calls.tooltips[1], "Open settings", "tooltip")
end

function tests.compact_size_uses_the_compact_control_height()
  local ImGui, adapter, icons, calls = fake_dependencies()
  local button = design_button.create(ImGui, "ctx", adapter, icons)
  button.draw({ id = "detach", label = "Detach", size = "compact" })
  button.draw_icon({ id = "more", icon = "more", accessible_label = "More", size = "compact" })
  equal(calls.buttons[1].height, 28, "compact button height")
  equal(calls.buttons[2].width, 28, "compact icon width")
  equal(calls.buttons[2].height, 28, "compact icon height")
  equal(calls.icons[1].x, 10 + 6, "compact icon centered")
  assert(not pcall(function() button.draw({ id = "x", label = "X", size = "large" }) end), "size rejected")
end

function tests.validates_icon_button_inputs_and_variants()
  local ImGui, adapter, icons = fake_dependencies()
  local button = design_button.create(ImGui, "ctx", adapter, icons)
  assert(not pcall(function()
    button.draw_icon({ id = "x", icon = "gear", variant = "quiet" })
  end), "accessible label is required")
  assert(not pcall(function()
    button.draw_icon({ id = "x", icon = "gear", accessible_label = "Settings", variant = "primary" })
  end), "primary icon button is rejected")
  assert(not pcall(function()
    button.draw_icon({ id = "x", icon = "missing", accessible_label = "Missing" })
  end), "unknown icon is rejected")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
