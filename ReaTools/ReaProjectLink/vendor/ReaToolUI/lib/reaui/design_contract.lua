local M = {}

M.SCHEMA_VERSION = 1
M.STATUS = "development"
M.VERSION = nil
M.ADAPTER = { name = "ReaImGui", api_version = "0.9" }
M.THEMES = { "light", "dark" }

M.CATALOG = {
  components = {
    { id = "button", name = "Button", module = "design_button", factory_key = "button", spec = "components/button.md", fixture = "Button variants" },
    { id = "icon_button", name = "Icon Button", module = "design_button", factory_key = "button", spec = "components/button.md", fixture = "Icon Button variants" },
    { id = "field_shell", name = "Field Shell", module = "design_field_shell", factory_key = "field_shell", spec = "components/text-field.md", fixture = "Field Shell and Text Field" },
    { id = "text_field", name = "Text Field", module = "design_text_field", factory_key = "text_field", spec = "components/text-field.md", fixture = "Field Shell and Text Field" },
    { id = "integer_number_field", name = "Integer Number Field", module = "design_number_field", factory_key = "number_field", spec = "components/integer-number-field.md", fixture = "Integer Number Field" },
    { id = "file_path_field", name = "File Path Field", module = "design_path_field", factory_key = "path_field", spec = "components/path-field.md", fixture = "Path Field" },
    { id = "folder_path_field", name = "Folder Path Field", module = "design_path_field", factory_key = "path_field", spec = "components/path-field.md", fixture = "Path Field" },
    { id = "checkbox", name = "Checkbox", module = "design_checkbox", factory_key = "checkbox", spec = "components/checkbox.md", fixture = "Checkbox" },
    { id = "dropdown", name = "Dropdown", module = "design_dropdown", factory_key = "dropdown", spec = "components/dropdown.md", fixture = "Dropdown and Select Field" },
    { id = "segmented_control", name = "Segmented Control", module = "design_segmented_control", factory_key = "segmented_control", spec = "components/segmented-control.md", fixture = "Segmented Control" },
    { id = "single_selection_list", name = "Single Selection List", module = "design_single_selection_list", factory_key = "single_selection_list", spec = "components/single-selection-list.md", fixture = "Single Selection List" },
    { id = "card", name = "Card", module = "design_card", factory_key = "card", spec = "components/card.md", fixture = "Card" },
    { id = "card_row", name = "Card Row", module = "design_card_row", factory_key = "card_row", spec = "components/card-row.md", fixture = "Card Row" },
    { id = "stat_group", name = "Stat Group", module = "design_stat_group", factory_key = "stat_group", spec = "components/stat-group.md", fixture = "Stat Group" },
    { id = "list", name = "List", module = "design_list", factory_key = "list", spec = "components/list.md", fixture = "List and List Row" },
    { id = "status", name = "Status", module = "design_status", factory_key = "status", spec = "components/status.md", fixture = "Status" },
    { id = "notice", name = "Notice", module = "design_notice", factory_key = "notice", spec = "components/notice.md", fixture = "Notice" },
    { id = "action_bar", name = "Action Bar", module = "design_action_bar", factory_key = "action_bar", spec = "components/action-bar.md", fixture = "Action Bar" },
    { id = "issue_item", name = "Issue Item", module = "design_issue_item", factory_key = "issue_item", spec = "components/issue-item.md", fixture = "Issue Item" },
    { id = "page_header", name = "Page Header", module = "design_page_header", factory_key = "page_header", spec = "components/page-header.md", fixture = "Page Header" },
    { id = "section_heading", name = "Section Heading", module = "design_section_heading", factory_key = "section_heading", spec = "components/section-heading.md", fixture = "Section Heading" },
    { id = "menu", name = "Menu", module = "design_menu", factory_key = "menu", spec = "components/menu.md", fixture = "Menu and Disclosure" },
    { id = "disclosure", name = "Disclosure", module = "design_disclosure", factory_key = "disclosure", spec = "components/disclosure.md", fixture = "Menu and Disclosure" },
  },
  patterns = {
    { id = "path_selection", name = "Path Selection", module = "design_path_selection", factory_key = "path_selection", spec = "patterns/path-selection.md", fixture = "Path Selection" },
    { id = "token_insert_group", name = "Token Insert Group", module = "design_token_insert_group", factory_key = "token_insert_group", spec = "patterns/token-insert-group.md", fixture = "Token Insert Group" },
    { id = "ordered_list_editor", name = "Ordered List Editor", module = "design_ordered_list_editor", factory_key = "ordered_list_editor", spec = "patterns/ordered-list-editor.md", fixture = "Ordered List Editor" },
    { id = "preset_manager", name = "Preset Manager", module = "design_preset_manager", factory_key = "preset_manager", spec = "patterns/preset-manager.md", fixture = "Preset Manager" },
    { id = "hierarchy_preview", name = "Hierarchy Preview", module = "design_hierarchy_preview", factory_key = "hierarchy_preview", spec = "patterns/hierarchy-preview.md", fixture = "Hierarchy Preview" },
    { id = "external_operation_status", name = "External Operation Status", module = "design_external_operation_status", factory_key = "external_operation_status", spec = "patterns/external-operation-status.md", fixture = "External Operation Status" },
    { id = "review_header", name = "Review Header", module = "design_review_header", factory_key = "review_header", spec = "patterns/review.md", fixture = "Publish Reference r7" },
    { id = "review_footer", name = "Review Footer", module = "design_review_footer", factory_key = "review_footer", spec = "patterns/review.md", fixture = "Fix 1 issue to publish" },
    { id = "stale_review", name = "Stale Review", module = "design_stale_review", factory_key = "stale_review", spec = "patterns/review.md", fixture = "Stale Review" },
    { id = "review_shell", name = "Review Shell", module = "design_review_shell", factory_key = "review_shell", spec = "patterns/review.md", fixture = "reference-publish" },
    { id = "confirmation_dialog", name = "Confirmation Dialog", module = "design_confirmation_dialog", factory_key = "confirmation_dialog", spec = "patterns/confirmation-and-inline-review.md", fixture = "delete-preset" },
    { id = "inline_review", name = "Inline Review", module = "design_inline_review", factory_key = "inline_review", spec = "patterns/confirmation-and-inline-review.md", fixture = "Inline Review" },
  },
}

M.COMPONENTS, M.PATTERNS = {}, {}
for _, entry in ipairs(M.CATALOG.components) do table.insert(M.COMPONENTS, entry.name) end
for _, entry in ipairs(M.CATALOG.patterns) do table.insert(M.PATTERNS, entry.name) end

local function required_string(value, name, errors)
  if type(value) ~= "string" or value == "" then table.insert(errors, name .. " is required") end
end

function M.validate_consumer(declaration)
  local errors = {}
  if type(declaration) ~= "table" then return { "consumer declaration must be a table" } end
  if declaration.schema_version ~= M.SCHEMA_VERSION then
    table.insert(errors, "consumer schema_version must equal " .. M.SCHEMA_VERSION)
  end
  if M.VERSION then
    if declaration.contract_version ~= M.VERSION then
      table.insert(errors, "consumer contract_version must equal " .. M.VERSION)
    end
  elseif declaration.contract_version ~= nil then
    table.insert(errors, "development contract cannot be declared as a published version")
  end
  required_string(declaration.contract_status, "consumer contract_status", errors)
  if declaration.contract_status ~= M.STATUS then
    table.insert(errors, "consumer contract_status must equal " .. M.STATUS)
  end
  required_string(declaration.implementation_revision, "consumer implementation_revision", errors)
  if type(declaration.adapter) ~= "table" then
    table.insert(errors, "consumer adapter is required")
  else
    if declaration.adapter.name ~= M.ADAPTER.name then
      table.insert(errors, "consumer adapter name must equal " .. M.ADAPTER.name)
    end
    if declaration.adapter.api_version ~= M.ADAPTER.api_version then
      table.insert(errors, "consumer adapter api_version must equal " .. M.ADAPTER.api_version)
    end
  end
  if type(declaration.exceptions) ~= "table" then
    table.insert(errors, "consumer exceptions must be a table")
  end
  if declaration.migration_note ~= nil and type(declaration.migration_note) ~= "string" then
    table.insert(errors, "consumer migration_note must be a string or nil")
  end
  return errors
end

return M
