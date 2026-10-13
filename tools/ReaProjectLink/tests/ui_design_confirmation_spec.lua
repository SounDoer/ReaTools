local dialog_module = require("reaui.design_confirmation_dialog")
local inline_module = require("reaui.design_inline_review")

local function equal(actual, expected, label)
  if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local function dialog_dependencies()
  local calls = { buttons = {}, visible = true, popup_open = true }
  local ImGui = {
    WindowFlags_AlwaysAutoResize = 1, Col_Text = 2,
    OpenPopup = function(_, id) calls.opened = id end,
    BeginPopupModal = function() return calls.visible, calls.popup_open end,
    EndPopup = function() calls.ended = true end,
    CloseCurrentPopup = function() calls.closed = true end,
    TextWrapped = function(_, value) calls.text = value end,
    PushStyleColor = function() end, PopStyleColor = function() end,
    SetItemDefaultFocus = function() calls.default_focus = true end,
    SameLine = function() end,
  }
  local adapter = { resolve = function() return 8 end }
  local button = { draw = function(options)
    table.insert(calls.buttons, options)
    if calls.click == options.id and not options.disabled and not options.running then return {} end
  end }
  return ImGui, adapter, button, calls
end

local tests = {}

function tests.dialog_opens_on_request_and_cancel_is_safe_default()
  local ImGui, adapter, button, calls = dialog_dependencies()
  local dialog = dialog_module.create(ImGui, "ctx", adapter, button)
  dialog.draw({ id = "delete", open = true, title = "Delete preset", message = "Deletes Night Mix.", confirm_label = "Delete preset", danger = true })
  assert(calls.opened:find("confirmation-delete", 1, true), "opened")
  equal(calls.buttons[1].label, "Cancel", "cancel first")
  equal(calls.default_focus, true, "safe focus")
  equal(calls.buttons[2].variant, "danger", "danger confirm")
end

function tests.dialog_emits_specific_confirm_cancel_and_alternative_events()
  for _, fixture in ipairs({
    { click = "reset-confirm", event = "dialog.confirmed" },
    { click = "reset-cancel", event = "dialog.cancelled" },
    { click = "reset-alternative", event = "dialog.alternative_selected", alternative = "Export settings" },
  }) do
    local ImGui, adapter, button, calls = dialog_dependencies()
    calls.click = fixture.click
    local result = dialog_module.create(ImGui, "ctx", adapter, button).draw({
      id = "reset", open = true, title = "Reset local state", message = "Removes local settings.",
      confirm_label = "Reset state", alternative_label = fixture.alternative,
    })
    equal(result.events[1].type, fixture.event, fixture.event)
    equal(calls.closed, true, "closed")
  end
end

function tests.dialog_rejects_generic_wording_and_missing_running_label()
  local ImGui, adapter, button = dialog_dependencies()
  local dialog = dialog_module.create(ImGui, "ctx", adapter, button)
  local base = { id = "x", open = true, title = "Delete preset", message = "Deletes X.", confirm_label = "Delete preset" }
  assert(not pcall(function() local o = {}; for k,v in pairs(base) do o[k]=v end; o.title="Warning"; dialog.draw(o) end), "title")
  assert(not pcall(function() local o = {}; for k,v in pairs(base) do o[k]=v end; o.confirm_label="OK"; dialog.draw(o) end), "action")
  assert(not pcall(function() local o = {}; for k,v in pairs(base) do o[k]=v end; o.running=true; dialog.draw(o) end), "running")
end

local function inline_dependencies()
  local calls = { buttons = {}, available = 500 }
  local ImGui = {
    GetContentRegionAvail = function() return calls.available end,
    CalcTextSize = function(_, value) return #value * 7 end,
    SameLine = function() calls.same = true end,
  }
  local adapter = { resolve = function() return 8 end }
  local status = { draw = function(options) calls.status = options end }
  local button = { draw = function(options)
    table.insert(calls.buttons, options)
    if calls.click == options.id and not options.disabled and not options.running then return {} end
  end }
  return ImGui, adapter, status, button, calls
end

function tests.inline_review_blocks_confirmation_and_forwards_content_first()
  local ImGui, adapter, status, button, calls = inline_dependencies()
  calls.click = "transfer-confirm"
  local result = inline_module.create(ImGui, "ctx", adapter, status, button).draw({
    id = "transfer", title = "Review transfer", message = "Two targets need attention.",
    confirm_label = "Replace Wwise objects", blocker_count = 2, warning_count = 1, danger = true,
  }, function() return { events = { { type = "decision.changed" } } } end)
  equal(result.role, "blocked", "role")
  equal(calls.buttons[2].disabled, true, "confirm blocked")
  equal(result.events[1].type, "decision.changed", "content event")
  equal(#result.events, 1, "no confirm")
end

function tests.inline_review_confirms_when_ready_and_stacks_narrow_actions()
  local ImGui, adapter, status, button, calls = inline_dependencies()
  calls.available = 80
  calls.click = "transfer-confirm"
  local result = inline_module.create(ImGui, "ctx", adapter, status, button).draw({
    id = "transfer", title = "Review transfer", message = "All targets are ready.",
    confirm_label = "Transfer to Wwise",
  })
  equal(result.events[1].type, "inline_review.confirmed", "confirm")
  equal(calls.buttons[1].stretch, true, "cancel stacked")
  equal(calls.buttons[2].stretch, true, "confirm stacked")
  equal(calls.same, nil, "not inline")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
