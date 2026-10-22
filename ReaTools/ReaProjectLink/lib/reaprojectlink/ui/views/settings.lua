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

local function project_rows(env, state, source)
  local rows = {
    { id = "project-name", title = "Name", detail = view_models.project_name(state.path) },
    { id = "project-path", title = "Project File", detail = state.path ~= "" and state.path or "Not Saved" },
    { id = "project-id", title = "Project ID", detail = state.project_id or "Not Assigned" },
  }
  if source then
    table.insert(rows, { id = "delivery-id", title = "Delivery ID",
      detail = env.adapter.get_project_value(constants.PROJECT_KEYS.delivery_id) or "Not Assigned" })
  else
    table.insert(rows, { id = "reference-id", title = "Reference ID", detail = state.reference_id or "Not Published" })
  end
  local values = {}
  for _, row in ipairs(rows) do
    row.kind = "row"
    row.action = { id = "copy", label = "Copy" }
    values[row.id] = row.detail
  end
  return rows, values
end

function M.create()
  local view = { reset_open = false }

  function view:reset()
    self.reset_open = false
  end

  function view:draw(env, state)
    local ImGui, ctx, c = env.ImGui, env.ctx, env.c
    local theme = env.theme
    local design_system = env.design_system
    local components, patterns = design_system.components, design_system.patterns
    local source = state.project_type == constants.PROJECT_TYPES.source
    local back = false
    local function section(id, title, render, first)
      components.section_heading.draw({ id = "settings-" .. id, title = title, gap_above = not first }, render)
    end

    workflow.draw_notices(env)
    if c.begin_page("settings", true) then
      back = components.page_header.draw({ id = "settings", title = "Settings", back_label = "Back" }).back_requested

      section("project", "Project", function()
        local rows, values = project_rows(env, state, source)
        local action = components.list.draw({ id = "settings-project", variant = "standard", items = rows }).action
        if action and action.id == "copy" then ImGui.SetClipboardText(ctx, tostring(values[action.row])) end
      end, true)
      if source then section("reference", "Reference", function() draw_reference(env, state) end) end

      section("appearance", "Appearance", function()
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
      end)

      section("about", "About", function()
        local _, _, reaimgui_version = ImGui.GetVersion()
        components.list.draw({ id = "settings-about", variant = "standard", items = {
          { kind = "row", id = "about-reaprojectlink", title = "ReaProjectLink", detail = env.version },
          { kind = "row", id = "about-reaper", title = "REAPER", detail = env.reaper.GetAppVersion() },
          { kind = "row", id = "about-reaimgui", title = "ReaImGui", detail = tostring(reaimgui_version) },
        } })
      end)

      section("reset", "Reset", function()
        c.small("Removes ReaProjectLink data from this project: its type, " ..
          "subscriptions, revisions, the IDs on Tracks and Items, and this project's " ..
          "published package. Audio and video Items in the project are kept.")
        if components.button.draw({
            id = "settings-reset", label = "Reset ReaProjectLink State...", variant = "danger",
          }) then
          self.reset_open = true
        end
      end)
    end
    c.end_page()

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
    if back then
      self.reset_open = false
      env.app:back()
    end
  end

  return view
end

return M
