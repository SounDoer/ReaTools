local function equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

-- `observed` scripts the fakes (token, poll_status, window_closed,
-- confirm_action) and records what was drawn.
local function create_shell(display_name, observed)
  observed.token = observed.token or "project"
  observed.poll_status = observed.poll_status or "running"
  observed.banners, observed.confirmations = {}, {}
  local disabled = 0
  local ImGui = {
    CreateListClipper = function() return {} end,
    Attach = function() end,
    Cond_Always = function() return 1 end,
    Cond_FirstUseEver = function() return 2 end,
    SetNextWindowSize = function() end,
    Begin = function(_, title)
      observed.title = title
      if observed.visible then return true, not observed.window_closed end
      return false, true
    end,
    End = function() end,
    BeginDisabled = function() disabled = disabled + 1 end,
    EndDisabled = function() disabled = disabled - 1 end,
    TextWrapped = function() observed.body_disabled = disabled > 0 end,
  }
  local adapter = {
    project_token = function() return observed.token end,
    project_is_open = function() return true end,
    with_project = function(_, fn, ...) return fn(...) end,
  }
  local fs = {
    start_copy = function() return {} end,
    poll = function() return observed.poll_status end,
  }
  local design_system = {
    adapter = {
      set_theme = function() end,
      push_base = function() end,
      pop_base = function() end,
    },
    components = {},
    patterns = {
      external_operation_status = {
        draw = function(options)
          table.insert(observed.banners, options)
          return {}
        end,
      },
      confirmation_dialog = {
        draw = function(options)
          table.insert(observed.confirmations, options)
          return { action = observed.confirm_action }
        end,
      },
    },
  }
  return require("reaprojectlink.ui.app").create({
    ImGui = ImGui,
    ctx = {},
    reaper = {
      GetExtState = function() return "dark" end,
      time_precise = function() return 0 end,
    },
    adapter = adapter,
    fs = fs,
    services = {
      project_service = { project_state = function() return { project_type = "test" } end },
    },
    version = "test",
    display_name = display_name,
    design_system = design_system,
  })
end

local function start_copy_job(shell, kind)
  return shell.env.jobs:start({
    kind = kind,
    label = "Publishing",
    project = "project-1",
    project_name = "Mix",
    run = function(job_fs)
      job_fs.copy_file("a.wav", "b.wav")
      return true
    end,
  })
end

local tests = {}

function tests.panel_uses_runtime_display_name()
  local observed = {}
  local shell = create_shell("ReaProjectLink [Dev]", observed)
  shell.draw()
  equal(observed.title, "ReaProjectLink [Dev]", "panel title")
end

function tests.tab_switch_keeps_publish_job_and_shows_banner()
  local observed = { visible = true }
  local shell = create_shell("ReaProjectLink", observed)
  local job = start_copy_job(shell, "publish")
  shell.draw()
  observed.token = "other-project"
  shell.draw()
  equal(shell.env.jobs.current, job, "job kept")
  equal(job.state, "running", "job state")
  local banner = observed.banners[#observed.banners]
  equal(banner and banner.label, "Publishing Mix", "banner label")
  equal(banner.can_cancel, true, "banner cancel")
  equal(observed.body_disabled, true, "body disabled")
end

function tests.tab_switch_discards_check_job()
  local observed = { visible = true }
  local shell = create_shell("ReaProjectLink", observed)
  start_copy_job(shell, "check")
  shell.draw()
  observed.token = "other-project"
  shell.draw()
  equal(shell.env.jobs.current, nil, "check discarded")
  equal(#observed.banners, 0, "no banner")
  equal(observed.body_disabled, false, "body enabled")
end

function tests.close_during_publish_asks_then_cancels()
  local observed = { visible = true }
  local shell = create_shell("ReaProjectLink", observed)
  local job = start_copy_job(shell, "publish")
  shell.draw()
  observed.window_closed, observed.confirm_action = true, "confirmed"
  shell.draw()
  equal(shell.open, true, "window kept open")
  equal(observed.confirmations[1] and observed.confirmations[1].id, "close-during-publish", "confirmation")
  equal(job.phase, "cancelling", "cancel requested")
  observed.window_closed, observed.poll_status = false, "done"
  shell.draw()
  equal(job.state, "cancelled", "job cancelled")
  equal(shell.open, false, "window closed after the job")
end

function tests.close_while_finishing_waits()
  local observed = { visible = true }
  local shell = create_shell("ReaProjectLink", observed)
  local job = start_copy_job(shell, "publish")
  shell.draw()
  job.phase = "finishing"
  observed.window_closed = true
  shell.draw()
  equal(shell.open, true, "window kept open")
  equal(#observed.confirmations, 0, "no confirmation")
  observed.window_closed, observed.poll_status = false, "done"
  shell.draw()
  equal(job.state, "succeeded", "job finished")
  equal(shell.open, false, "window closed after the job")
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end

return passed
