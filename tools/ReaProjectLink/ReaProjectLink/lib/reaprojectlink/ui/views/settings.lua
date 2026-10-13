local constants = require("reaprojectlink.constants")
local view_models = require("reaprojectlink.ui.view_models")
local workflow = require("reaprojectlink.ui.workflow")

local M = {}

local THEMES = {
  { id = "auto", label = "Auto" },
  { id = "light", label = "Light" },
  { id = "dark", label = "Dark" },
}

local RESET_MESSAGE = "Remove all ReaProjectLink data from this project, including its " ..
  "published package? Audio and video Items in the project are kept."
local RESET_DETAIL = "This can't be undone: REAPER Undo does not restore the project's " ..
  "ReaProjectLink data. Save a copy of the project first if you might need it."

local function draw_reference(env, state)
  local adapter = env.adapter
  local components = env.design_system.components
  local patterns = env.design_system.patterns
  local connected = state.reference_manifest_path ~= nil and state.reference_manifest_path ~= ""

  env.settings_compat.section("Reference")
  local path = patterns.path_selection.draw({
    id = "settings-reference-path",
    label = "reference.json",
    kind = "file",
    value = connected and state.reference_manifest_path or "Not Connected",
    read_only = true,
    browse_label = connected and "Change..." or "Choose...",
    reserve_message = false,
  })
  if path.browse_requested then workflow.choose_reference(env) end

  local mode = adapter.get_project_value(constants.PROJECT_KEYS.reference_alignment_mode) or "mirror"
  local alignment = components.checkbox.draw({
    id = "settings-mirror-master-timeline",
    label = "Mirror Master Timeline",
    checked = mode ~= "relative",
  })
  if alignment.changed then
    local result, err = env.services.reference_subscription.set_alignment_mode(
      adapter, alignment.checked and "mirror" or "relative"
    )
    workflow.apply(env, result, err)
  end
end

function M.create()
  local view = { reset_open = false }

  function view:reset()
    self.reset_open = false
  end

  function view:draw(env, state)
    local ImGui = env.ImGui
    local theme = env.theme
    local design_system = env.design_system
    local components, patterns = design_system.components, design_system.patterns
    local compat = env.settings_compat
    local source = state.project_type == constants.PROJECT_TYPES.source
    local back = false

    design_system.adapter.set_theme(theme.mode)
    design_system.adapter.push_base()
    workflow.draw_notices(env)
    if compat.begin_page("settings") then
      local header = patterns.review_header.draw({ id = "settings", title = "Settings" })
      back = header.back_requested

      compat.section("Project")
      compat.copy_value("project-name", "Name", view_models.project_name(state.path))
      compat.copy_value("project-path", "Project File", state.path ~= "" and state.path or "Not Saved")
      compat.copy_value("project-id", "Project ID", state.project_id or "Not Assigned")
      if source then
        compat.copy_value("delivery-id", "Delivery ID",
          env.adapter.get_project_value(constants.PROJECT_KEYS.delivery_id) or "Not Assigned")
        draw_reference(env, state)
      else
        compat.copy_value("reference-id", "Reference ID", state.reference_id or "Not Published")
      end

      compat.section("Appearance")
      local appearance = components.segmented_control.draw_field({
        id = "settings-theme",
        label = "Theme",
        value = theme.preference,
        options = THEMES,
        reserve_message = false,
      })
      if appearance.changed then
        theme:set_preference(appearance.value)
        design_system.adapter.set_theme(theme.mode)
      end

      compat.section("About")
      local _, _, reaimgui_version = ImGui.GetVersion()
      compat.key_value("ReaProjectLink", env.version)
      compat.key_value("REAPER", env.reaper.GetAppVersion())
      compat.key_value("ReaImGui", tostring(reaimgui_version))

      compat.section("Reset")
      compat.explanation("Removes ReaProjectLink data from this project: its type, " ..
        "subscriptions, revisions, the IDs on Tracks and Items, and this project's " ..
        "published package. Audio and video Items in the project are kept.")
      if components.button.draw({
          id = "settings-reset", label = "Reset ReaProjectLink State...", variant = "danger",
        }) then
        self.reset_open = true
      end
    end
    compat.end_page()

    local confirmation = patterns.confirmation_dialog.draw({
      id = "settings-reset",
      open = self.reset_open,
      title = "Reset ReaProjectLink State",
      message = RESET_MESSAGE,
      detail = RESET_DETAIL,
      confirm_label = "Reset ReaProjectLink State",
      danger = true,
    })
    if confirmation.action == "cancelled" then
      self.reset_open = false
    elseif confirmation.action == "confirmed" then
      self.reset_open = false
      local result, err = env.services.project_service.reset(env.adapter, env.fs)
      if result then
        env.app:reset()
        env.app:request_check()
      else
        env.app:notify(err, true)
      end
    end
    design_system.adapter.pop_base()

    if back then
      self.reset_open = false
      env.app:back()
    end
  end

  return view
end

return M
