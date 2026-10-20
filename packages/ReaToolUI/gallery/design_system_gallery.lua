local design_tokens = require("reaui.design_tokens")
local design_contract = require("reaui.design_contract")
local design_adapter = require("reaui.design_adapter")
local design_button = require("reaui.design_button")
local design_text_field = require("reaui.design_text_field")
local design_number_field = require("reaui.design_number_field")
local design_path_field = require("reaui.design_path_field")
local design_checkbox = require("reaui.design_checkbox")
local design_dropdown = require("reaui.design_dropdown")
local design_segmented_control = require("reaui.design_segmented_control")
local design_single_selection_list = require("reaui.design_single_selection_list")
local design_card = require("reaui.design_card")
local design_card_row = require("reaui.design_card_row")
local design_stat_group = require("reaui.design_stat_group")
local design_list = require("reaui.design_list")
local design_status = require("reaui.design_status")
local design_action_bar = require("reaui.design_action_bar")
local design_issue_item = require("reaui.design_issue_item")
local design_page_header = require("reaui.design_page_header")
local design_notice = require("reaui.design_notice")
local design_menu = require("reaui.design_menu")
local design_disclosure = require("reaui.design_disclosure")
local design_path_selection = require("reaui.design_path_selection")
local design_token_insert_group = require("reaui.design_token_insert_group")
local design_ordered_list_editor = require("reaui.design_ordered_list_editor")
local design_preset_manager = require("reaui.design_preset_manager")
local design_hierarchy_preview = require("reaui.design_hierarchy_preview")
local design_external_operation_status = require("reaui.design_external_operation_status")
local design_stale_review = require("reaui.design_stale_review")
local design_review_shell = require("reaui.design_review_shell")
local design_confirmation_dialog = require("reaui.design_confirmation_dialog")
local design_inline_review = require("reaui.design_inline_review")

local M = {}
local CHILD_BORDERS = 1

local SECTIONS = {
  "Foundations",
  "Components",
  "Patterns",
  "Cross-product Scenarios",
  "Diagnostics",
}

function M.create(deps)
  local ImGui, ctx = deps.ImGui, deps.ctx
  local adapter = design_adapter.create(ImGui, ctx, deps.theme or "light")
  local button = design_button.create(ImGui, ctx, adapter)
  local text_field = design_text_field.create(ImGui, ctx, adapter)
  local number_field = design_number_field.create(ImGui, ctx, adapter)
  local path_field = design_path_field.create(ImGui, ctx, adapter)
  local checkbox = design_checkbox.create(ImGui, ctx, adapter)
  local dropdown = design_dropdown.create(ImGui, ctx, adapter)
  local segmented = design_segmented_control.create(ImGui, ctx, adapter)
  local selection_list = design_single_selection_list.create(ImGui, ctx, adapter)
  local card = design_card.create(ImGui, ctx, adapter)
  local card_row = design_card_row.create(ImGui, ctx, adapter, card)
  local stat_group = design_stat_group.create(ImGui, ctx, adapter)
  local list = design_list.create(ImGui, ctx, adapter)
  local status = design_status.create(ImGui, ctx, adapter)
  local action_bar = design_action_bar.create(ImGui, ctx, adapter)
  local issue_item = design_issue_item.create(ImGui, ctx, adapter)
  local page_header = design_page_header.create(ImGui, ctx, adapter)
  local notice = design_notice.create(ImGui, ctx, adapter)
  local menu = design_menu.create(ImGui, ctx, adapter)
  local disclosure = design_disclosure.create(ImGui, ctx, adapter)
  local path_selection = design_path_selection.create(ImGui, ctx, adapter)
  local token_insert = design_token_insert_group.create(ImGui, ctx, adapter)
  local ordered_list = design_ordered_list_editor.create(ImGui, ctx, adapter)
  local preset_manager = design_preset_manager.create(ImGui, ctx, adapter)
  local hierarchy_preview = design_hierarchy_preview.create(ImGui, ctx, adapter)
  local operation_status = design_external_operation_status.create(ImGui, ctx, adapter)
  local stale_review = design_stale_review.create(ImGui, ctx, adapter)
  local review_shell = design_review_shell.create(ImGui, ctx, adapter)
  local confirmation_dialog = design_confirmation_dialog.create(ImGui, ctx, adapter)
  local inline_review = design_inline_review.create(ImGui, ctx, adapter)
  local shell = { open = true }
  local section = deps.section or "Foundations"
  local preview = deps.preview or "wide"
  local preview_width = 0
  local scroll_frames = 0
  local last_event = "No events"
  local field_values = {
    naming_pattern = "$track_$marker",
    fallback = "",
    target_revision = "7",
    wwise_project = "C:/AudioProjects/Trailer/Trailer.wproj",
    originals_folder = "//Studio-NAS/AudioProjects/Trailer/Originals/SFX/Forest/Night",
  }
  local checkbox_values = { mirror_timeline = true }
  local dropdown_values = { conflict_policy = "merge" }
  local segmented_values = { theme_mode = "auto" }
  local scenario_values = {
    view = "settings",
    page = "connection",
    conflict_policy = "review",
  }
  local list_values = { structure_row = "actor-mixer" }
  local pattern_values = { object_name = "$track_$marker" }
  local ordered_values = { transfer_step = "rename" }
  local preset_values = { selected = "dialogue", name = "Dialogue transfer" }
  local delete_preset_dialog_open = false

  local function record(event)
    if event then last_event = event.type .. " id=" .. event.id end
  end

  local function record_field(key, result)
    field_values[key] = result.value
    for _, event in ipairs(result.events) do
      last_event = event.type .. " id=" .. event.id .. " value=" .. event.value
    end
  end

  local function record_number(key, result)
    field_values[key] = result.buffer
    for _, event in ipairs(result.events) do
      last_event = event.type .. " id=" .. event.id ..
        " buffer=" .. event.buffer .. " state=" .. event.parse_state
    end
  end

  local function record_path(key, result)
    field_values[key] = result.value
    for _, event in ipairs(result.events) do
      last_event = event.type .. " id=" .. event.id ..
        " kind=" .. event.kind .. " value=" .. event.value
    end
  end

  local function record_checkbox(key, result)
    checkbox_values[key] = result.checked
    for _, event in ipairs(result.events) do
      last_event = event.type .. " id=" .. event.id ..
        " checked=" .. tostring(event.checked)
    end
  end

  local function record_dropdown(key, result)
    dropdown_values[key] = result.value
    for _, event in ipairs(result.events) do
      last_event = event.type .. " id=" .. event.id .. " value=" .. event.value
    end
  end

  local function record_segmented(key, result)
    segmented_values[key] = result.value
    for _, event in ipairs(result.events) do
      last_event = event.type .. " id=" .. event.id .. " value=" .. event.value
    end
  end

  local function record_list(key, result)
    list_values[key] = result.value
    for _, event in ipairs(result.events) do
      last_event = event.type .. " id=" .. event.id .. " value=" .. event.value
    end
  end

  local function theme_controls()
    ImGui.Text(ctx, "Theme")
    for index, theme in ipairs(design_tokens.THEMES) do
      if index > 1 then ImGui.SameLine(ctx) end
      local label = theme:sub(1, 1):upper() .. theme:sub(2)
      local event = button.draw({
        id = "theme-" .. theme,
        label = label,
        variant = adapter.theme() == theme and "secondary" or "quiet",
      })
      if event then adapter.set_theme(theme) end
    end
    ImGui.SameLine(ctx)
    ImGui.Text(ctx, "Resolved: " .. adapter.theme())
  end

  local function navigation()
    for index, name in ipairs(SECTIONS) do
      if index > 1 then ImGui.SameLine(ctx) end
      local event = button.draw({
        id = "gallery-section-" .. index,
        label = name,
        variant = section == name and "secondary" or "quiet",
      })
      if event then section = name end
    end
    ImGui.Separator(ctx)
  end

  local function preview_controls()
    ImGui.Text(ctx, "Preview width")
    for index, name in ipairs({ "compact", "standard", "wide" }) do
      if index > 1 then ImGui.SameLine(ctx) end
      local label = name:sub(1, 1):upper() .. name:sub(2)
      local event = button.draw({
        id = "gallery-preview-" .. name,
        label = label,
        variant = preview == name and "secondary" or "quiet",
      })
      if event then preview = name end
    end
    local available = ImGui.GetContentRegionAvail(ctx)
    preview_width = math.min(available, adapter.resolve("semantic.layout.preview." .. preview))
    ImGui.SameLine(ctx)
    ImGui.Text(ctx, tostring(preview_width) .. " logical units")
    ImGui.SameLine(ctx)
    local clear = button.draw({ id = "gallery-clear-events", label = "Clear event", variant = "quiet" })
    if clear then last_event = "No events" end
    ImGui.TextWrapped(ctx, "Event: " .. last_event)
  end

  local function components()
    adapter.with_text("title", function()
      ImGui.Text(ctx, "Component calibration")
    end)
    ImGui.TextColored(ctx, adapter.resolve("semantic.color.text.secondary"),
      "Review shared component anatomy, variants, and states here. Product composition is out of scope.")
    ImGui.Dummy(ctx, 0, adapter.resolve("semantic.space.section.default"))

    ImGui.Text(ctx, "Card")
    card.draw({
      id = "source-project-card",
      title = "Source project",
      description = "Groups project identity and readiness without becoming an action.",
    }, function()
      ImGui.Text(ctx, "Trailer Main")
      ImGui.TextWrapped(ctx, "//Studio-NAS/Shows/Trailer/Reaper/Trailer_Main.rpp")
    end)
    card.draw({
      id = "emphasized-transfer-card",
      title = "Current transfer target",
      variant = "emphasized",
    }, function()
      ImGui.TextWrapped(ctx, "Actor-Mixer Hierarchy / Ambience / Forest / Night")
    end)
    for _, fixture in ipairs({
      { id = "card-trailing-icon", icon = "film", title = "Reference",
        trailing = { kind = "icon_button", id = "check", icon = "check", accessible_label = "Check now" },
        status = { role = "ready", text = "Synchronized" } },
      { id = "card-trailing-menu", icon = "upload", title = "Delivery",
        trailing = { kind = "menu", id = "menu", accessible_label = "Delivery actions",
          items = { { id = "rename", label = "Rename" }, { id = "detach", label = "Detach", danger = true } } },
        status = { role = "warning", text = "2 references changed", detail = "Last published r7 · 3 hours ago" } },
      { id = "card-footer", icon = "film", title = "Reference", variant = "emphasized",
        status = { role = "ready", text = "Ready to publish", detail = "Synchronized r2" },
        footer = { context = "Selected: 2 Tracks", actions = {
          { id = "unregister", label = "Unregister" },
          { id = "register", label = "Register", variant = "primary" },
        } } },
    }) do
      for _, event in ipairs(card.draw(fixture).events) do
        last_event = event.type .. " id=" .. event.id .. " action=" .. event.action
      end
    end
    card.draw({ id = "title-free-card" }, function()
      ImGui.TextWrapped(ctx, "A Card may group content without inventing a heading when its surrounding context already names the region.")
    end)

    ImGui.Text(ctx, "Card Row")
    for _, event in ipairs(card_row.draw({ id = "gallery-card-row", cards = {
      { options = { id = "row-reference", icon = "film", title = "Reference",
          status = { role = "ready", text = "Synchronized", detail = "r7 · 2 minutes ago" } },
        render_body = function()
          ImGui.TextWrapped(ctx, "Trailer_Main.rpp")
          ImGui.TextWrapped(ctx, "4 tracks · 8 markers · 2 regions")
        end },
      { options = { id = "row-delivery", icon = "upload", title = "Delivery", variant = "emphasized",
          status = { role = "warning", text = "2 references changed" },
          footer = { actions = { { id = "publish", label = "Publish", variant = "primary" } } } } },
    } }).events) do
      last_event = event.type .. " id=" .. event.id .. " action=" .. event.action
    end

    ImGui.Text(ctx, "Stat Group")
    stat_group.draw({ id = "stats-two", stats = {
      { label = "Registered tracks", value = 12 }, { label = "Pending changes", value = 2 },
    } })
    stat_group.draw({ id = "stats-three", stats = {
      { label = "Tracks", value = 4 }, { label = "Markers", value = 128 }, { label = "Regions", value = 2 },
    } })

    ImGui.Text(ctx, "List and List Row")
    local function record_list_result(result)
      for _, event in ipairs(result.events) do
        last_event = event.type .. " id=" .. event.id .. (event.action and (" action=" .. event.action) or "")
      end
      if result.overflow_toggled then list_values.expanded = not list_values.expanded end
    end
    local row_menu = { accessible_label = "Row actions", items = { { id = "rename", label = "Rename" } } }
    card.draw({ id = "list-states-card", title = "Deliveries" }, function()
      record_list_result(list.draw({ id = "list-states", items = {
        { kind = "row", id = "music", title = "Music bed", detail = "Published r7 · 2 minutes ago",
          status = { role = "ready", text = "Synchronized" }, menu = row_menu },
        { kind = "row", id = "dialogue", title = "Dialogue", detail = "Not published yet",
          status = { role = "neutral", text = "Draft" }, action = { id = "publish", label = "Publish" } },
        { kind = "row", id = "ambience", title = "Ambience forest night layers with a long descriptive name",
          status = { role = "warning", text = "2 changed" }, action = { id = "review", label = "Review" },
          menu = row_menu },
        { kind = "row", id = "sfx", title = "SFX", detail = "Destination unavailable",
          status = { role = "blocked", text = "Offline" }, action = { id = "retry", label = "Retry", disabled = true } },
      } }))
    end)
    local names = {
      { kind = "group", label = "Project files" },
      { kind = "row", id = "main", title = "Trailer_Main.rpp", action = { id = "remove", label = "Remove...", variant = "quiet" } },
      { kind = "row", id = "alt", title = "Trailer_Alt.rpp", action = { id = "remove", label = "Remove...", variant = "quiet" } },
      { kind = "group", label = "Media" },
      { kind = "row", id = "music", title = "Music_Bed_v3.wav", action = { id = "remove", label = "Remove...", variant = "quiet" } },
    }
    if list_values.expanded then
      names[#names + 1] = { kind = "row", id = "vo", title = "VO_Take_12.wav", action = { id = "remove", label = "Remove...", variant = "quiet" } }
    end
    card.draw({ id = "list-compact-card", title = "Source Reference" }, function()
      record_list_result(list.draw({ id = "list-compact", variant = "compact", items = names,
        overflow = { label = list_values.expanded and "Showing all 4 files" or "+ 1 more file",
          expanded = list_values.expanded == true } }))
    end)

    ImGui.Text(ctx, "Status")
    status.draw({ role = "neutral", text = "No transfer has run in this session." })
    status.draw({ role = "ready", text = "Project requirements are satisfied and publishing can continue." })
    status.draw({ role = "warning", text = "Two changed references should be reviewed before publishing." })
    status.draw({ role = "blocked", text = "Destination is unavailable. Reconnect the NAS to continue." })
    status.draw({ role = "ready", text = "Ready to publish", presentation = "prominent",
      detail = "Last checked 2 minutes ago" })
    status.draw({ role = "warning", text = "Two references changed since the last publish",
      presentation = "prominent", detail = "Review them before publishing revision 8." })

    ImGui.Text(ctx, "Notice")
    for _,fixture in ipairs({
      {id="neutral",role="neutral",text="The next transfer will use the current project settings."},
      {id="ready",role="ready",text="All media is ready for transfer."},
      {id="warning",role="warning",text="Two existing objects may be replaced.",actions={{id="review",label="Review conflicts"}}},
      {id="blocked",role="blocked",text="The Wwise project cannot be reached.",actions={{id="retry",label="Retry"},{id="change",label="Change project..."}}},
    }) do
      local result=notice.draw(fixture);for _,event in ipairs(result.events)do last_event=event.type.." id="..event.id.." action="..event.action end
    end

    ImGui.Text(ctx, "Action Bar")
    for _, fixture in ipairs({
      { id = "bar-publish", context = "2 references changed", actions = {
        { id = "diff", label = "View Changes" }, { id = "check", label = "Check Now" },
        { id = "publish", label = "Publish Reference", variant = "primary" },
      } },
      { id = "bar-blocked", context = "Fix 1 issue to publish", actions = {
        { id = "cancel", label = "Cancel" },
        { id = "publish", label = "Publish", variant = "primary", disabled = true },
      } },
    }) do
      for _, event in ipairs(action_bar.draw(fixture).events) do
        last_event = event.type .. " id=" .. event.id .. " action=" .. event.action
      end
    end

    ImGui.Text(ctx, "Issue Item")
    for _, fixture in ipairs({
      { id = "issue-changed", role = "warning", message = "Two references changed since revision 6" },
      { id = "issue-missing", role = "blocked", message = "Ambience reference is missing",
        detail = "Expected at Refs/Ambience_r6.rpp", actions = { { id = "relink", label = "Relink..." } } },
      { id = "issue-renamed", role = "warning", message = "Dialogue track was renamed",
        detail = "Previously registered as VO_Main", actions = {
          { id = "ignore", label = "Ignore" }, { id = "update", label = "Update Reference" },
        } },
      { id = "issue-offline", role = "blocked", message = "Destination is unavailable" },
    }) do
      for _, event in ipairs(issue_item.draw(fixture).events) do
        last_event = event.type .. " id=" .. event.id .. " action=" .. event.action
      end
    end

    ImGui.Text(ctx, "Page Header")
    for _, fixture in ipairs({
      { id = "header-main", title = "Trailer Main", badge = "Master", meta = "Last published 2 min ago",
        actions = {
          { id = "check", label = "Check Now", icon = "download" },
          { id = "publish", label = "Publish", icon = "upload", variant = "primary" },
        } },
      { id = "header-review", title = "Publish Reference", badge = "r7", back_label = "Back to Main",
        actions = { { id = "cancel", label = "Cancel" } } },
    }) do
      local result = page_header.draw(fixture)
      for _, event in ipairs(result.events) do
        last_event = event.type .. " id=" .. event.id .. (event.action and (" action=" .. event.action) or "")
      end
    end

    ImGui.Text(ctx, "Menu and Disclosure")
    local menu_result=menu.draw({id="project-actions",accessible_label="Project actions",items={{id="rename",label="Rename"},{id="duplicate",label="Duplicate"},{separator=true},{id="delete",label="Delete snapshot",danger=true}}})
    for _,event in ipairs(menu_result.events)do last_event=event.type.." id="..event.id.." action="..event.action end
    disclosure.draw({id="technical-details",label="Technical details",description="Optional diagnostic information for support.",default_open=true},function()
      ImGui.TextWrapped(ctx,"Project ID: 8aa9cb40 · Revision: 14 · Manifest schema: 1")
    end)

    ImGui.Text(ctx, "Button variants")
    for index, variant in ipairs({ "primary", "secondary", "quiet", "danger" }) do
      if index > 1 then ImGui.SameLine(ctx) end
      local label = variant:sub(1, 1):upper() .. variant:sub(2)
      record(button.draw({ id = "variant-" .. variant, label = label, variant = variant }))
    end

    ImGui.Text(ctx, "States")
    button.draw({ id = "disabled", label = "Disabled", variant = "secondary", disabled = true })
    ImGui.SameLine(ctx)
    button.draw({
      id = "running", label = "Publish", variant = "primary",
      running = true, running_label = "Publishing...",
    })

    ImGui.Text(ctx, "Long and stretched content")
    record(button.draw({
      id = "long-label",
      label = "Choose a different project folder...",
      variant = "secondary",
      stretch = true,
    }))

    ImGui.Text(ctx, "Icon Button variants")
    record(button.draw_icon({
      id = "icon-secondary", icon = "gear", accessible_label = "Open settings",
      variant = "secondary",
    }))
    ImGui.SameLine(ctx)
    record(button.draw_icon({
      id = "icon-quiet", icon = "more", accessible_label = "More actions", variant = "quiet",
    }))
    ImGui.SameLine(ctx)
    record(button.draw_icon({
      id = "icon-danger", icon = "cross", accessible_label = "Delete item", variant = "danger",
    }))
    ImGui.SameLine(ctx)
    button.draw_icon({
      id = "icon-disabled", icon = "gear", accessible_label = "Settings unavailable",
      variant = "quiet", disabled = true,
    })

    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Field Shell and Text Field")
    record_field("naming_pattern", text_field.draw({
      id = "naming-pattern",
      label = "Naming pattern",
      description = "Use supported tokens to build Wwise object names.",
      requirement = "required",
      value = field_values.naming_pattern,
    }))
    record_field("fallback", text_field.draw({
      id = "fallback-name",
      label = "Fallback name",
      requirement = "optional",
      value = field_values.fallback,
      placeholder = "Unnamed_01",
    }))
    text_field.draw({
      id = "source-project",
      label = "Source project",
      value = "//Studio-NAS/AudioProjects/TrailerCampaign/Reaper/Sequences/Forest/Night/Trailer_Main_Revision_014.rpp",
      read_only = true,
    })
    text_field.draw({
      id = "unavailable-destination",
      label = "Destination",
      value = "Choose a Wwise project first",
      disabled = true,
    })
    text_field.draw({
      id = "checking-name",
      label = "Remote project name",
      value = "Trailer_Main",
      validation = { state = "pending", message = "Checking project availability..." },
    })
    text_field.draw({
      id = "valid-name",
      label = "Structure name",
      value = "Ambience_Forest",
      validation = { state = "valid", message = "Name is available." },
    })
    text_field.draw({
      id = "invalid-pattern",
      label = "Import naming pattern",
      value = "$track_$unsupported",
      validation = {
        state = "invalid",
        message = "Use a supported token such as $track or $marker before continuing.",
      },
    })

    ImGui.Text(ctx, "Integer Number Field")
    record_number("target_revision", number_field.draw({
      id = "target-revision",
      label = "Target revision",
      description = "Choose a published revision from 1 through 20.",
      buffer = field_values.target_revision,
      minimum = 1,
      maximum = 20,
      step = 1,
    }))
    number_field.draw({
      id = "incomplete-revision",
      label = "Incomplete value",
      buffer = "-",
      show_parse_message = true,
    })
    number_field.draw({
      id = "invalid-revision",
      label = "Invalid value",
      buffer = "2.5",
      show_parse_message = true,
    })
    number_field.draw({
      id = "range-revision",
      label = "Out-of-range value",
      buffer = "42",
      minimum = 1,
      maximum = 20,
      show_parse_message = true,
    })
    number_field.draw({
      id = "readonly-revision",
      label = "Current revision",
      value = 6,
      read_only = true,
    })
    number_field.draw({
      id = "disabled-revision",
      label = "Unavailable revision",
      value = 6,
      disabled = true,
      step = 1,
    })

    ImGui.Text(ctx, "Path Field")
    record_path("wwise_project", path_field.draw({
      id = "wwise-project-path",
      label = "Wwise project",
      description = "Select the .wproj file used for this transfer.",
      kind = "file",
      value = field_values.wwise_project,
      browse_label = "Browse...",
    }))
    record_path("originals_folder", path_field.draw({
      id = "originals-folder-path",
      label = "Originals folder",
      kind = "folder",
      value = field_values.originals_folder,
    }))
    path_field.draw({
      id = "selected-reaper-project",
      label = "Selected REAPER project",
      kind = "file",
      value = "//Studio-NAS/Shows/Trailer/Reaper/Sequences/Forest/Night/Trailer_Main_Revision_014.rpp",
      read_only = true,
      browse_label = "Change...",
    })
    path_field.draw({
      id = "checking-folder",
      label = "Destination folder",
      kind = "folder",
      value = "C:/AudioProjects/Trailer/Originals/Voices",
      validation = { state = "pending", message = "Checking folder access..." },
    })
    path_field.draw({
      id = "invalid-folder",
      label = "Invalid Originals folder",
      kind = "folder",
      value = "C:/Temp/Exports",
      validation = {
        state = "invalid",
        message = "Choose a folder inside the current Wwise project's Originals directory.",
      },
    })
    path_field.draw({
      id = "unavailable-picker",
      label = "Unavailable project file",
      kind = "file",
      placeholder = "No project selected",
      browse_disabled = true,
      validation = {
        state = "invalid",
        message = "File selection is unavailable until the host finishes initializing.",
      },
    })

    ImGui.Text(ctx, "Checkbox")
    record_checkbox("mirror_timeline", checkbox.draw({
      id = "mirror-timeline",
      label = "Mirror the source timeline",
      checked = checkbox_values.mirror_timeline,
      description = "Keep the imported material aligned with the source project's timeline start.",
    }))
    checkbox.draw({
      id = "unchecked-option",
      label = "Create missing parent objects",
      checked = false,
    })
    checkbox.draw({
      id = "disabled-option",
      label = "Replace existing audio files",
      checked = true,
      disabled = true,
      description = "This option is unavailable for the current transfer target.",
    })
    checkbox.draw({
      id = "pending-option",
      label = "Include source metadata",
      checked = true,
      validation = { state = "pending", message = "Checking target support..." },
    })
    checkbox.draw({
      id = "valid-option",
      label = "Preserve region names",
      checked = true,
      validation = { state = "valid", message = "All region names are supported." },
    })
    checkbox.draw({
      id = "invalid-option",
      label = "Synchronize referenced media",
      checked = true,
      validation = {
        state = "invalid",
        message = "Choose an accessible reference location before enabling synchronization.",
      },
    })

    ImGui.Text(ctx, "Dropdown and Select Field")
    local conflict_options = {
      { id = "replace", label = "Replace existing objects" },
      { id = "merge", label = "Merge with existing objects" },
      { id = "skip", label = "Skip objects that already exist" },
    }
    record_dropdown("conflict_policy", dropdown.draw_field({
      id = "conflict-policy",
      label = "Conflict policy",
      description = "Choose what happens when the target object already exists.",
      value = dropdown_values.conflict_policy,
      options = conflict_options,
    }))
    dropdown.draw_field({
      id = "loading-workunit",
      label = "WorkUnit",
      options = {},
      data_state = "loading",
      validation = { state = "pending", message = "Loading WorkUnits from Wwise..." },
    })
    dropdown.draw_field({
      id = "empty-target",
      label = "Transfer target",
      options = {},
      data_state = "empty",
      validation = { state = "invalid", message = "Create or load a transfer target first." },
    })
    dropdown.draw_field({
      id = "failed-preset",
      label = "Preset",
      options = {},
      data_state = "failed",
      failed_label = "Presets could not be loaded",
      validation = { state = "invalid", message = "Retry loading presets before continuing." },
    })
    dropdown.draw_field({
      id = "stale-lane",
      label = "Destination lane",
      value = "removed-lane",
      stale_label = "Dialogue Print (unavailable)",
      options = {
        { id = "mix", label = "Main Mix" },
        { id = "music", label = "Music and score — full-resolution delivery lane" },
      },
      validation = { state = "invalid", message = "Choose an available destination lane." },
    })
    dropdown.draw_field({
      id = "disabled-scope",
      label = "Index scope",
      value = "markers-regions",
      disabled = true,
      options = {
        { id = "markers-regions", label = "Markers and regions" },
        { id = "regions", label = "Regions only" },
      },
    })

    ImGui.Text(ctx, "Segmented Control")
    record_segmented("theme_mode", segmented.draw_field({
      id = "theme-mode",
      label = "Theme mode",
      value = segmented_values.theme_mode,
      options = {
        { id = "auto", label = "Auto" },
        { id = "light", label = "Light" },
        { id = "dark", label = "Dark" },
      },
    }))
    segmented.draw_field({
      id = "parent-location",
      label = "Parent location",
      description = "Choose where new Wwise objects are created.",
      value = "selected-workunit",
      options = {
        { id = "selected-workunit", label = "Selected WorkUnit" },
        { id = "target-parent", label = "Transfer target parent" },
      },
    })
    segmented.draw_field({
      id = "disabled-review-source",
      label = "Revision source",
      value = "latest",
      disabled = true,
      options = {
        { id = "latest", label = "Latest published" },
        { id = "reviewed", label = "Last reviewed" },
      },
    })
    segmented.draw_field({
      id = "invalid-review-source",
      label = "Revision source requiring attention",
      value = "reviewed",
      options = {
        { id = "latest", label = "Latest published revision" },
        { id = "reviewed", label = "Last explicitly reviewed revision" },
      },
      validation = {
        state = "invalid",
        message = "The reviewed revision is no longer available; choose the latest revision.",
      },
    })

    ImGui.Text(ctx, "Single Selection List")
    local structure_items = {
      { id = "actor-mixer", label = "Actor-Mixer Hierarchy" },
      { id = "events", label = "Events and named routing objects" },
      { id = "soundbanks", label = "SoundBanks generated for the current platform and language" },
      { id = "game-parameters", label = "Game Parameters" },
    }
    record_list("structure_row", selection_list.draw_field({
      id = "structure-row",
      label = "Structure row",
      description = "Select one row to edit; selection does not move or transfer it.",
      value = list_values.structure_row,
      items = structure_items,
      size = "compact",
    }))
    selection_list.draw_field({
      id = "stale-structure-row",
      label = "Structure row with stale selection",
      value = "removed-routing-row",
      stale_label = "Legacy routing row",
      items = structure_items,
      size = "compact",
      validation = { state = "invalid", message = "Choose an available structure row." },
    })
    selection_list.draw_field({
      id = "loading-structure-rows",
      label = "Loading structure rows",
      items = structure_items,
      data_state = "loading",
      size = "compact",
      validation = { state = "pending", message = "Loading structure data..." },
    })
    selection_list.draw_field({
      id = "empty-structure-rows",
      label = "Empty structure",
      items = {},
      data_state = "empty",
      size = "compact",
      empty_label = "No structure rows have been added.",
    })
    selection_list.draw_field({
      id = "failed-structure-rows",
      label = "Unavailable structure",
      items = structure_items,
      data_state = "failed",
      size = "compact",
      failed_label = "Structure rows could not be refreshed.",
      validation = { state = "invalid", message = "Retry loading the structure before transfer." },
    })

    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Event log: " .. last_event)
  end

  local function foundations()
    ImGui.Text(ctx, "Typography roles")
    for _, sample in ipairs({
      { "title", "Tool title · 项目工具" },
      { "heading", "Section heading · 结构预览" },
      { "status", "Ready to publish · 可以发布" },
      { "metric", "128" },
      { "body", "Body text explains the current task and consequence." },
      { "label", "Field label" },
      { "metadata", "Metadata · revision 7 · 2026-10-12" },
      { "code", "sha256:6f8a4c2e91bd /mnt/studio/audio" },
    }) do
      adapter.push_text(sample[1])
      ImGui.TextWrapped(ctx, sample[2])
      adapter.pop_text()
    end
    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Inset and tint surfaces")
    for _, surface in ipairs({
      { "inset", "semantic.color.surface.inset", "semantic.color.border.default" },
      { "tint-warning", "semantic.color.tint.warning.background",
        "semantic.color.tint.warning.border" },
      { "tint-blocked", "semantic.color.tint.blocked.background",
        "semantic.color.tint.blocked.border" },
    }) do
      local padding_x = adapter.resolve("semantic.space.inset.padding_x")
      local padding_y = adapter.resolve("semantic.space.inset.padding_y")
      ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, adapter.resolve(surface[2]))
      ImGui.PushStyleColor(ctx, ImGui.Col_Border, adapter.resolve(surface[3]))
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_ChildRounding,
        adapter.resolve("semantic.radius.control"))
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, padding_x, padding_y)
      local visible = ImGui.BeginChild(ctx, "##foundation-surface-" .. surface[1], 0, 0,
        ImGui.ChildFlags_Border | ImGui.ChildFlags_AutoResizeY |
        ImGui.ChildFlags_AlwaysUseWindowPadding)
      ImGui.PopStyleVar(ctx, 2)
      ImGui.PopStyleColor(ctx, 2)
      if visible then
        ImGui.TextWrapped(ctx, surface[2] .. " · primary text stays readable")
        ImGui.EndChild(ctx)
      end
    end
    ImGui.Separator(ctx)
    ImGui.Text(ctx, "Token resolution sample")
    local token_id = "semantic.color.text.primary"
    local value = adapter.resolve(token_id)
    ImGui.Text(ctx, token_id)
    ImGui.TextColored(ctx, value, string.format("Resolved value: #%08X", value))
    ImGui.Text(ctx, "Container padding: " .. tostring(
      adapter.resolve("semantic.space.container.padding")) .. " logical units")
    ImGui.TextWrapped(ctx, "Mixed-language sample: Dialogue 主角 · Ambience 森林 · 効果音 ライフル")
    ImGui.TextWrapped(ctx, "macOS path: /Users/audio/Projects/Trailer/Reference")
    ImGui.TextWrapped(ctx, "Linux path: /mnt/studio/audio/trailer/originals/sfx")
    ImGui.TextWrapped(ctx, "Technical sample: 2026-10-12T23:30:00Z · sha256:6f8a4c2e91bd")
  end

  local function patterns()
    ImGui.Text(ctx,"Path Selection")
    path_selection.draw({id="pattern-reaper-project",label="REAPER project",kind="file",value="//Studio-NAS/Shows/Trailer/Reaper/Trailer_Main.rpp",read_only=true,browse_label="Change...",state="valid",message="Project is accessible."})
    path_selection.draw({id="pattern-wwise-project",label="Wwise project",kind="file",value="C:/AudioProjects/Trailer/Trailer.wproj",state="checking",message="Checking project structure..."})
    path_selection.draw({id="pattern-originals",label="Originals folder",kind="folder",value="C:/Temp/Exports",state="invalid",message="Choose a folder inside the current Wwise project's Originals directory."})
    path_selection.draw({id="pattern-unavailable",label="Destination folder",kind="folder",state="unavailable",message="Folder selection is unavailable until the host finishes initializing."})
    ImGui.Separator(ctx);ImGui.Text(ctx,"Token Insert Group")
    local result=token_insert.draw({id="object-name-pattern",label="Object name pattern",description="Append supported naming tokens.",value=pattern_values.object_name,tokens={{id="item",label="$item",value="$item"},{id="track",label="$track",value="$track"},{id="marker",label="$marker",value="$marker"},{id="region",label="$region",value="$region"},{id="parent",label="$parent",value="$parent"}}})
    pattern_values.object_name=result.value;for _,event in ipairs(result.events)do last_event=event.type.." id="..event.id end
    ImGui.Separator(ctx);ImGui.Text(ctx,"Ordered List Editor")
    local ordered_result=ordered_list.draw({
      id="transfer-steps",label="Transfer steps",value=ordered_values.transfer_step,size="compact",
      description="The product owns the row data and applies action requests.",
      items={{id="source",label="1. Resolve REAPER source"},{id="rename",label="2. Apply Wwise naming pattern"},{id="transfer",label="3. Transfer audio and metadata"}},
      render_editor=function(item,index)
        ImGui.TextWrapped(ctx,"Selected step "..index..": "..item.label)
      end,
    })
    ordered_values.transfer_step=ordered_result.value
    for _,event in ipairs(ordered_result.events)do last_event=event.type.." id="..event.id end
    ImGui.Separator(ctx);ImGui.Text(ctx,"Preset Manager")
    local preset_result=preset_manager.draw({
      id="transfer-presets",label="Transfer preset",value=preset_values.selected,draft_name=preset_values.name,
      description="Preset storage and overwrite policy remain product-owned.",
      presets={{id="dialogue",label="Dialogue transfer"},{id="ambience",label="Ambience transfer"},{id="cinematic",label="Cinematic impacts"}},
    })
    preset_values.selected=preset_result.value;preset_values.name=preset_result.name
    for _,event in ipairs(preset_result.events)do last_event=event.type.." id="..event.id end
    ImGui.Separator(ctx);ImGui.Text(ctx,"Hierarchy Preview")
    hierarchy_preview.draw({id="wwise-preview",data_state="partial",message="One optional WorkUnit is unavailable.",nodes={{id="actor-mixer",label="Actor-Mixer Hierarchy",default_open=true,children={{id="sfx",label="SFX",default_open=true,children={{id="weapons",label="Weapons / Player / Rifle / Automatic / Exterior / Distant"},{id="ambience",label="Ambience / Forest / Night"}}}}},{id="events",label="Events",children={{id="play-rifle",label="Play_Rifle_Automatic_Exterior"}}}}})
    ImGui.Separator(ctx);ImGui.Text(ctx,"External Operation Status")
    for _,fixture in ipairs({
      {id="transfer-running",label="Wwise transfer",message="Transferring audio and metadata.",state="running",progress=42,can_cancel=true},
      {id="publish-success",label="Package publish",message="Revision 7 is available on the NAS.",state="succeeded",can_dismiss=true},
      {id="transfer-failed",label="Wwise transfer",message="WAAPI connection was interrupted.",state="failed",can_retry=true,can_dismiss=true},
      {id="transfer-partial",label="Wwise transfer",message="Three of four targets completed.",detail="Completed targets were retained.",state="partial",progress=75,can_retry=true,can_dismiss=true},
    })do
      local operation_result=operation_status.draw(fixture)
      for _,event in ipairs(operation_result.events)do last_event=event.type.." id="..event.id end
    end
    ImGui.Separator(ctx);ImGui.Text(ctx,"Stale Review")
    local stale_result=stale_review.draw({id="stale-review",title="Review Out of Date",message="The project was edited after this review was made. Existing decisions are unavailable.",refresh_label="Refresh Review"})
    for _,event in ipairs(stale_result.events)do last_event=event.type.." id="..event.id end
    ImGui.Separator(ctx);ImGui.Text(ctx,"Inline Review")
    local inline_result=inline_review.draw({id="replace-targets",title="Review Wwise replacements",message="One conflict must be resolved before four target objects can be replaced.",confirm_label="Replace Wwise objects",blocker_count=1,warning_count=2,danger=true},function()
      notice.draw({id="replace-conflict",role="blocked",text="Two selected sources resolve to the same Wwise object path."})
      disclosure.draw({id="replace-scope",label="Affected objects · 4",description="External target paths remain visible before execution."},function()
        ImGui.TextWrapped(ctx,"\\Actor-Mixer Hierarchy\\SFX\\Weapons\\Rifle")
      end)
      return {events={}}
    end)
    for _,event in ipairs(inline_result.events)do last_event=event.type.." id="..event.id end
    ImGui.Separator(ctx);ImGui.Text(ctx,"Confirmation Dialog")
    if button.draw({id="open-delete-preset",label="Open delete preset confirmation",variant="danger"}) then
      delete_preset_dialog_open = true
    end
    local dialog_result=confirmation_dialog.draw({id="delete-preset",open=delete_preset_dialog_open,title="Delete preset",message="Deletes the saved preset ‘Dialogue transfer’. This cannot be undone.",confirm_label="Delete preset",danger=true})
    delete_preset_dialog_open = dialog_result.open
    for _,event in ipairs(dialog_result.events)do last_event=event.type.." id="..event.id end
  end

  local function cross_product_scenarios()
    adapter.with_text("metadata", function()
      ImGui.TextColored(ctx, adapter.resolve("semantic.color.text.secondary"),
        "PROVISIONAL INTEGRATION FIXTURE · NOT A PRODUCT PAGE SPECIFICATION")
    end)
    ImGui.Dummy(ctx, 0, adapter.resolve("semantic.space.stack.tight"))
    adapter.with_text("title", function()
      ImGui.Text(ctx, "ReaProjectLink")
    end)
    ImGui.TextColored(ctx, adapter.resolve("semantic.color.text.secondary"),
      "Keep the REAPER session and its Wwise workspace connected.")
    ImGui.Dummy(ctx, 0, adapter.resolve("semantic.space.stack.tight"))

    local view_result = segmented.draw({
      id = "reaprojectlink-scenario",
      value = scenario_values.view,
      options = {
        { id = "settings", label = "Project setup" },
        { id = "publish", label = "Publish review" },
      },
    })
    scenario_values.view = view_result.value
    for _, event in ipairs(view_result.events) do
      last_event = event.type .. " id=" .. event.id
    end
    ImGui.Dummy(ctx, 0, adapter.resolve("semantic.space.section.default"))

    if scenario_values.view == "settings" then
      local _, available_height = ImGui.GetContentRegionAvail(ctx)
      local workspace_height = math.max(380, available_height or 380)
      local rail_width = 156
      local gap = adapter.resolve("semantic.space.stack.default")
      local rail_padding = adapter.resolve("semantic.space.container.padding")

      ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg,
        adapter.resolve("semantic.color.surface.panel"))
      -- Borderless child windows otherwise lose their implicit window padding.
      -- Keep spacing and decoration independent so the rail remains inset even
      -- when its boundary is expressed only by the surface color.
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,
        rail_padding, rail_padding)
      local rail_visible = ImGui.BeginChild(ctx, "##reaprojectlink-settings-rail",
        rail_width, workspace_height, ImGui.ChildFlags_AlwaysUseWindowPadding)
      ImGui.PopStyleVar(ctx)
      ImGui.PopStyleColor(ctx)
      if rail_visible then
        adapter.with_text("metadata", function()
          ImGui.TextColored(ctx, adapter.resolve("semantic.color.text.secondary"), "PROJECT SETTINGS")
        end)
        ImGui.Dummy(ctx, 0, adapter.resolve("semantic.space.stack.tight"))
        for _, item in ipairs({
          { id = "connection", label = "Project connection" },
          { id = "naming", label = "Naming rules" },
          { id = "transfer", label = "Transfer defaults" },
          { id = "advanced", label = "Advanced" },
        }) do
          local event = button.draw({
            id = "settings-page-" .. item.id,
            label = item.label,
            variant = scenario_values.page == item.id and "secondary" or "quiet",
            stretch = true,
          })
          if event then scenario_values.page = item.id end
          ImGui.Dummy(ctx, 0, adapter.resolve("semantic.space.inline.tight"))
        end
        ImGui.Dummy(ctx, 0, adapter.resolve("semantic.space.section.default"))
        ImGui.TextColored(ctx, adapter.resolve("semantic.color.text.secondary"), "CURRENT LINK")
        status.draw({ role = "ready", text = "Connected" })
        ImGui.TextWrapped(ctx, "Trailer Main")
        adapter.with_text("metadata", function()
          ImGui.TextColored(ctx, adapter.resolve("semantic.color.text.secondary"),
            "Last checked just now")
        end)
      end
      ImGui.EndChild(ctx)

      ImGui.SameLine(ctx, 0, gap)
      local content_visible = ImGui.BeginChild(ctx, "##reaprojectlink-settings-content",
        0, workspace_height, 0)
      if content_visible then
        if scenario_values.page == "connection" then
          adapter.with_text("title", function() ImGui.Text(ctx, "Project connection") end)
          ImGui.TextColored(ctx, adapter.resolve("semantic.color.text.secondary"),
            "Pair one REAPER session with the Wwise workspace it delivers to.")
          ImGui.Dummy(ctx, 0, adapter.resolve("semantic.space.section.default"))

          adapter.with_text("heading", function() ImGui.Text(ctx, "Workspace pair") end)
          status.draw({ role = "ready", text = "Both projects are online" })
          ImGui.TextColored(ctx, adapter.resolve("semantic.color.text.secondary"), "REAPER")
          ImGui.SameLine(ctx)
          ImGui.Text(ctx, "Trailer_Main.rpp")
          ImGui.SameLine(ctx)
          ImGui.TextColored(ctx, adapter.resolve("semantic.color.focus.ring"), "→")
          ImGui.SameLine(ctx)
          ImGui.TextColored(ctx, adapter.resolve("semantic.color.text.secondary"), "WWISE")
          ImGui.SameLine(ctx)
          ImGui.Text(ctx, "Trailer.wproj")
          ImGui.Dummy(ctx, 0, adapter.resolve("semantic.space.stack.default"))
          path_field.draw({
            id = "settings-reaper-project",
            label = "REAPER source",
            kind = "file",
            value = "//Studio-NAS/Shows/Trailer/Reaper/Trailer_Main.rpp",
            read_only = true,
            browse_label = "Change...",
            reserve_message = false,
          })
          path_field.draw({
            id = "settings-wwise-project",
            label = "Wwise destination",
            kind = "file",
            value = "C:/AudioProjects/Trailer/Trailer.wproj",
            browse_label = "Browse...",
            reserve_message = false,
          })
          ImGui.Dummy(ctx, 0, adapter.resolve("semantic.space.stack.tight"))
          record(button.draw({
            id = "validate-project-link",
            label = "Check connection",
            variant = "secondary",
          }))
        else
          local titles = {
            naming = "Naming rules",
            transfer = "Transfer defaults",
            advanced = "Advanced settings",
          }
          adapter.with_text("title", function()
            ImGui.Text(ctx, titles[scenario_values.page] or "Project settings")
          end)
          ImGui.TextColored(ctx, adapter.resolve("semantic.color.text.secondary"),
            "This area demonstrates task-based navigation without turning settings into one long form.")
          ImGui.Dummy(ctx, 0, adapter.resolve("semantic.space.section.loose"))
          card.draw({
            id = "settings-task-placeholder",
            title = "Focused workspace",
            description = "Only controls for the selected task appear here.",
          }, function()
            ImGui.TextWrapped(ctx,
              "The final controls will be composed when the ReaProjectLink workflow is migrated.")
          end)
        end

        local footer_y = workspace_height - 84
        if ImGui.GetCursorPosY(ctx) < footer_y then
          ImGui.SetCursorPosY(ctx, footer_y)
        else
          ImGui.Dummy(ctx, 0, adapter.resolve("semantic.space.section.loose"))
        end
        ImGui.Separator(ctx)
        ImGui.Dummy(ctx, 0, adapter.resolve("semantic.space.inline.tight"))
        ImGui.TextColored(ctx, adapter.resolve("semantic.color.text.secondary"),
          "Changes apply to this project link only.")
        local action_gap = adapter.resolve("semantic.space.control.gap")
        local action_padding = adapter.resolve("semantic.space.control.padding_x") * 2
        local discard_width = ImGui.CalcTextSize(ctx, "Discard") + action_padding
        local save_width = ImGui.CalcTextSize(ctx, "Save settings") + action_padding
        local actions_width = discard_width + action_gap + save_width
        ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) +
          math.max(0, ImGui.GetContentRegionAvail(ctx) - actions_width))
        record(button.draw({
          id = "discard-project-link", label = "Discard", variant = "quiet",
        }))
        ImGui.SameLine(ctx, 0, action_gap)
        record(button.draw({ id = "save-project-link", label = "Save settings", variant = "primary" }))
      end
      ImGui.EndChild(ctx)
    else
      local result=review_shell.draw({
        id="reference-publish",
        header={title="Publish Reference r7",summary="4 tracks · 8 markers and regions"},
        footer={summary="Fix 1 issue to publish",role="blocked",complete_label="Publish",enabled=false},
        render_body=function()
          local events={}
          local function record(result) for _,event in ipairs(result.events) do table.insert(events,event) end end
          stat_group.draw({id="review-scope",stats={{label="Tracks",value=4},{label="Markers",value=8},{label="Regions",value=2}}})
          review_shell.section({id="issues",title="Issues"},function()
            record(issue_item.draw({id="review-save-as",role="blocked",message="Project was saved under a new name",
              detail="Choose how its identity should continue.",actions={{id="continue",label="Continue Existing"},{id="new",label="Start New"}}}))
            record(issue_item.draw({id="review-changed",role="warning",message="Two tracks changed since revision 6"}))
          end)
          review_shell.section({id="decisions",title="Decisions"},function()
            segmented.draw_field({id="review-reference",label="Checked against reference",value="r6",options={{id="r6",label="Reference r6"},{id="none",label="Not checked"}}})
          end)
          review_shell.section({id="details",title="Details"},function()
            disclosure.draw({id="review-tracks",label="Tracks",variant="inset",role="warning",detail="4 · 2 changed"},function()
              ImGui.TextWrapped(ctx,"Dialogue / Main Character / Alternate Language / Close Perspective")
              ImGui.TextWrapped(ctx,"Ambience / Forest / Night / Distant Perspective")
            end)
            disclosure.draw({id="review-markers",label="Markers and regions",variant="inset",detail="10"},function()
              ImGui.TextWrapped(ctx,"8 markers · 2 regions")
            end)
          end)
          return {events=events}
        end,
      })
      for _,event in ipairs(result.events)do last_event=event.type.." id="..event.id end
    end
  end

  local function placeholder(name)
    ImGui.Text(ctx, name)
    ImGui.TextWrapped(ctx, "This section is reserved for contract-backed examples. " ..
      "No product operation is connected to the Gallery.")
  end

  local function diagnostics()
    local _, _, imgui_version = ImGui.GetVersion()
    ImGui.Text(ctx, "Contract: " .. (design_contract.VERSION or "unreleased"))
    ImGui.Text(ctx, "Contract status: " .. design_contract.STATUS)
    ImGui.Text(ctx, "Contract schema: " .. tostring(design_contract.SCHEMA_VERSION))
    ImGui.Text(ctx, "Token schema: " .. tostring(design_tokens.SCHEMA_VERSION))
    ImGui.Text(ctx, "ReaImGui: " .. tostring(imgui_version or "unknown"))
    ImGui.Text(ctx, "ReaImGui API target: " .. design_contract.ADAPTER.api_version)
    ImGui.Text(ctx, "Platform: " .. tostring(deps.platform or "unknown"))
    ImGui.Text(ctx, "Viewport DPI scale: " .. tostring(ImGui.GetWindowDpiScale(ctx)))
    ImGui.Text(ctx, "Theme: " .. adapter.theme())
    ImGui.Text(ctx, "Preview: " .. preview .. " · " .. tostring(preview_width) .. " logical units")
    ImGui.Text(ctx, "Token count: " .. tostring(#design_tokens.ids()))
  end

  function shell.draw()
    ImGui.SetNextWindowSize(ctx, 900, 640, ImGui.Cond_FirstUseEver)
    adapter.push_base()
    local visible
    visible, shell.open = ImGui.Begin(ctx, "ReaToolUI Design System Gallery", shell.open)
    if visible then
      adapter.with_text("title", function()
        ImGui.Text(ctx, "ReaToolUI Gallery")
      end)
      ImGui.TextColored(ctx, adapter.resolve("semantic.color.text.secondary"),
        "Design review workspace · development only")
      theme_controls()
      navigation()
      preview_controls()
      local _, available_height = ImGui.GetContentRegionAvail(ctx)
      local preview_padding = adapter.resolve("semantic.space.page.padding")
      ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding,
        preview_padding, preview_padding)
      local preview_visible = ImGui.BeginChild(ctx, "##gallery-preview", preview_width,
        available_height, ImGui.ChildFlags_AlwaysUseWindowPadding)
      ImGui.PopStyleVar(ctx)
      if preview_visible then
        if section == "Foundations" then
          foundations()
        elseif section == "Components" then
          components()
        elseif section == "Patterns" then
          patterns()
        elseif section == "Cross-product Scenarios" then
          cross_product_scenarios()
        elseif section == "Diagnostics" then
          diagnostics()
        else
          placeholder(section)
        end
        -- Review captures start scrolled; content height is known only after a frame.
        if deps.scroll_y and scroll_frames < 30 then
          ImGui.SetScrollY(ctx, deps.scroll_y)
          scroll_frames = scroll_frames + 1
        end
      end
      ImGui.EndChild(ctx)
    end
    ImGui.End(ctx)
    adapter.pop_base()
  end

  return shell
end

return M
