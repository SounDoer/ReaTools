local constants = require("reaprojectlink.constants")
local theme_module = require("reaprojectlink.ui.theme")
local components = require("reaprojectlink.ui.components")
local app_state = require("reaprojectlink.ui.app_state")
local checks = require("reaprojectlink.ui.checks")
local workflow = require("reaprojectlink.ui.workflow")
local jobs = require("reaprojectlink.jobs")
local setup = require("reaprojectlink.ui.views.setup")
local settings = require("reaprojectlink.ui.views.settings")
local source_main = require("reaprojectlink.ui.views.source_main")
local master_main = require("reaprojectlink.ui.views.master_main")

local REVIEWS = {
  reference_update = require("reaprojectlink.ui.views.reference_update_review"),
  delivery_publish = require("reaprojectlink.ui.views.delivery_publish_review"),
  reference_publish = require("reaprojectlink.ui.views.reference_publish_review"),
  delivery_import = require("reaprojectlink.ui.views.delivery_sync_review"),
  delivery_update = require("reaprojectlink.ui.views.delivery_sync_review"),
}

local M = {}

-- deps: ImGui, ctx, reaper, adapter, fs, services, version, display_name.
function M.create(deps)
  local ImGui, ctx, adapter = deps.ImGui, deps.ctx, deps.adapter
  local display_name = assert(deps.display_name, "display_name is required")
  local theme = theme_module.create(ImGui, ctx, deps.reaper)
  local design_system = assert(deps.design_system, "ReaToolUI design system is required")
  local settings_view = settings.create()
  local env = {
    ImGui = ImGui,
    ctx = ctx,
    reaper = deps.reaper,
    adapter = adapter,
    fs = deps.fs,
    services = deps.services,
    version = deps.version,
    theme = theme,
    design_system = design_system,
    c = components.create(ImGui, ctx, design_system),
    app = app_state.new(deps.reaper.time_precise),
    jobs = jobs.create({ fs = deps.fs, adapter = adapter }),
  }
  local shell = { open = true, env = env }
  local project_token = adapter.project_token()
  local fixed_width
  env.app:request_check()

  local function run_due_check(state)
    if not env.app:check_due() then return end
    if state.project_type == constants.PROJECT_TYPES.source then
      checks.run_source(env)
    elseif state.project_type == constants.PROJECT_TYPES.master then
      checks.run_master(env)
    end
    env.app:finish_check()
  end

  local function draw_body(state)
    local app = env.app
    if not state.project_type or state.project_type == "" then
      setup.draw(env, state)
    elseif app.view == "settings" then
      settings_view:draw(env, state)
    elseif app.review and REVIEWS[app.review.kind] then
      REVIEWS[app.review.kind].draw(env, state)
      return app.review ~= nil
    elseif state.project_type == constants.PROJECT_TYPES.source then
      source_main.draw(env, state)
    elseif state.project_type == constants.PROJECT_TYPES.master then
      master_main.draw(env, state)
    else
      ImGui.TextWrapped(ctx, "Unsupported project type: " .. tostring(state.project_type))
    end
  end

  -- A job whose review is gone (for example after a project tab switch):
  -- checks are dropped, while a publish keeps running behind a banner.
  local function unowned_job()
    local job = env.jobs.current
    if not job or (env.app.review and env.app.review.job == job) then return nil end
    if job.kind ~= "publish" then
      env.jobs:discard()
      return nil
    end
    if job.state == "succeeded" then
      env.jobs:dismiss()
      return nil
    end
    return job
  end

  local function draw_job_banner(job)
    local running = job.state == "running"
    local result = design_system.patterns.external_operation_status.draw({
      id = "background-publish",
      label = "Publishing " .. job.project_name,
      message = running and workflow.job_message(job) or job.error or "Publish failed.",
      state = job.state,
      progress = running and jobs.progress(job) or nil,
      can_cancel = running and job.phase ~= "finishing",
      can_dismiss = not running,
      detail = running and "Wait for Publish to finish." or nil,
    })
    if result.action == "cancel" then
      env.jobs:cancel()
    elseif result.action == "dismiss" then
      env.jobs:dismiss()
    end
  end

  local function handle_close_request()
    local job = env.jobs.current
    if not env.jobs:busy() then return end
    if job.kind ~= "publish" then
      env.jobs:discard()
      return
    end
    shell.open = true
    if job.phase == "finishing" then
      shell.close_after_job = true
      return
    end
    env.c.request_confirmation({
      id = "close-during-publish",
      title = "Cancel Publish and Close",
      message = "Publishing is still running. Closing cancels it and removes the partial upload.",
      confirm_label = "Cancel Publish and Close",
      danger = true,
    }, function()
      env.jobs:cancel()
      shell.close_after_job = true
    end)
  end

  function shell.draw()
    local token = adapter.project_token()
    if token ~= project_token then
      project_token = token
      env.app:reset()
      settings_view:reset()
      env.app:request_check()
    end
    -- After the reset, so a toast reported by a job that ends this frame survives it.
    env.jobs:step()
    theme:refresh()
    if fixed_width then
      ImGui.SetNextWindowSize(ctx, fixed_width, 720, ImGui.Cond_Always)
    else
      ImGui.SetNextWindowSize(ctx, 1040, 720, ImGui.Cond_FirstUseEver)
    end
    design_system.adapter.set_theme(theme.mode)
    design_system.adapter.push_base()
    -- Settings and Reviews scroll inside their own centered child; an outer
    -- scrollbar would shift that centering by half its width every time it
    -- appears (for example while a toast is shown).
    local app = env.app
    local own_scrolling = app.view == "settings" or (app.review and REVIEWS[app.review.kind])
    local flags = own_scrolling and (ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse) or 0
    local visible
    visible, shell.open = ImGui.Begin(ctx, display_name, shell.open, flags)
    if not shell.open then handle_close_request() end
    if visible then
      local state = deps.services.project_service.project_state(adapter)
      run_due_check(state)
      if state.project_type == constants.PROJECT_TYPES.master then
        master_main.confirm_moved_items(env)
      end
      local job = unowned_job()
      if job then draw_job_banner(job) end
      local locked = job ~= nil and job.state == "running"
      if locked then ImGui.BeginDisabled(ctx, true) end
      local review_drawn = draw_body(state)
      if locked then ImGui.EndDisabled(ctx) end
      -- Drawn last so it floats over the view instead of moving it.
      local toast = env.app:visible_toast()
      if toast and env.c.toast_overlay(toast, review_drawn) then env.app:dismiss_toast() end
      env.c.draw_confirmation()
      -- ReaImGui only accepts End() when Begin() returned true, unlike Dear ImGui.
      ImGui.End(ctx)
    end
    design_system.adapter.pop_base()
    if shell.close_after_job and not env.jobs:busy() then shell.open = false end
  end

  local real_services = env.services
  local smoke_values = {}

  local function set_project_value(key, value)
    deps.reaper.SetProjExtState(0, constants.EXTENSION_NAME,
      assert(constants.PROJECT_KEYS[key], "unknown project key " .. key), value)
  end

  -- Prepares one smoke-test frame: project type, theme, width, and view.
  -- `project_values` (PROJECT_KEYS name -> string) and `services` (service
  -- name -> overriding functions) populate the main views; both are undone
  -- by the next scenario.
  function shell.apply_smoke(scenario)
    set_project_value("project_type", scenario.project_type)
    for key in pairs(smoke_values) do set_project_value(key, "") end
    smoke_values = scenario.project_values or {}
    for key, value in pairs(smoke_values) do set_project_value(key, value) end
    env.services = real_services
    if scenario.services then
      env.services = setmetatable({}, { __index = real_services })
      for name, overrides in pairs(scenario.services) do
        env.services[name] = setmetatable({}, { __index = function(_, key)
          if overrides[key] ~= nil then return overrides[key] end
          return real_services[name][key]
        end })
      end
    end
    theme:use(scenario.theme)
    fixed_width = scenario.width
    env.app:reset()
    for key, value in pairs(scenario.collapsed_groups or {}) do env.app.collapsed_groups[key] = value end
    settings_view:reset()
    env.app:request_check()
    -- Force the "shown" phase so the pointer check runs during this scenario's
    -- frame, exercising checks.run_source/run_master and the checked states.
    env.app.check_phase = "shown"
    -- Renders the toast overlay in every scenario; narrow frames use the error
    -- variant so its Dismiss button is drawn too.
    env.app:notify("Smoke toast", scenario.width == 320)
    if scenario.view == "settings" then
      env.app:open_settings()
    elseif scenario.review then
      env.app:open_review(scenario.review.kind, scenario.review.fields())
    end
  end

  return shell
end

return M
