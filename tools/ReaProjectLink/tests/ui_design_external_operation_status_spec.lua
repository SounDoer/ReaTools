local module = require("reaui.design_external_operation_status")

local function equal(actual, expected, label)
  if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual)) end
end

local function dependencies()
  local calls = {}
  local notice = {
    draw = function(options)
      calls.notice = options
      return { action = calls.action, events = {} }
    end,
  }
  return notice, calls
end

local tests = {}

function tests.maps_each_state_to_role_and_visible_label()
  local fixtures = {
    idle = "neutral", running = "neutral", succeeded = "ready",
    failed = "blocked", cancelled = "warning", partial = "warning",
  }
  for state, role in pairs(fixtures) do
    local notice, calls = dependencies()
    module.create({}, "ctx", {}, notice).draw({
      id = "transfer", label = "Wwise transfer", message = "State fixture", state = state,
    })
    equal(calls.notice.role, role, state .. " role")
    assert(calls.notice.role_label ~= "", state .. " label")
    assert(calls.notice.text:find("Wwise transfer", 1, true), state .. " operation label")
  end
end

function tests.running_progress_and_cancel_emit_semantic_request()
  local notice, calls = dependencies()
  calls.action = "cancel"
  local result = module.create({}, "ctx", {}, notice).draw({
    id = "transfer", label = "Wwise transfer", message = "Uploading originals.",
    state = "running", progress = 42.4, can_cancel = true,
  })
  assert(calls.notice.text:find("42%", 1, true), "rounded progress")
  equal(calls.notice.actions[1].id, "cancel", "cancel action")
  equal(result.events[1].type, "operation.cancel_requested", "cancel event")
  equal(result.events[1].state, "running", "event state")
end

function tests.outcome_actions_follow_capabilities()
  local notice, calls = dependencies()
  calls.action = "retry"
  local result = module.create({}, "ctx", {}, notice).draw({
    id = "transfer", label = "Transfer", message = "One target failed.",
    detail = "Completed targets are retained.", state = "partial",
    progress = 75, can_retry = true, can_dismiss = true,
  })
  equal(calls.notice.actions[1].id, "retry", "retry")
  equal(calls.notice.actions[2].id, "dismiss", "dismiss")
  assert(calls.notice.text:find("Completed targets", 1, true), "detail")
  equal(result.events[1].type, "operation.retry_requested", "retry event")
end

function tests.rejects_invalid_capability_and_progress_combinations()
  local notice = dependencies()
  local pattern = module.create({}, "ctx", {}, notice)
  local function draw(extra)
    local options = { id = "x", label = "X", message = "State", state = "succeeded" }
    for key, value in pairs(extra) do options[key] = value end
    pattern.draw(options)
  end
  assert(not pcall(function() draw({ progress = 50 }) end), "success progress")
  assert(not pcall(function() draw({ can_cancel = true }) end), "success cancel")
  assert(not pcall(function() draw({ state = "running", can_retry = true }) end), "running retry")
  assert(not pcall(function() draw({ state = "idle", can_dismiss = true }) end), "idle dismiss")
  assert(not pcall(function() draw({ state = "unknown" }) end), "unknown")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
