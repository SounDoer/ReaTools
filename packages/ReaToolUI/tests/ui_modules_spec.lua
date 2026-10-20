local MODULES = {
  "reaui",
  "reaui.design_tokens",
  "reaui.design_contract",
  "reaui.design_system",
  "reaui.design_adapter",
  "reaui.design_layout",
  "reaui.design_button",
  "reaui.design_field_shell",
  "reaui.design_input_control",
  "reaui.design_text_field",
  "reaui.design_number_field",
  "reaui.design_path_field",
  "reaui.design_checkbox",
  "reaui.design_dropdown",
  "reaui.design_segmented_control",
  "reaui.design_single_selection_list",
  "reaui.design_card",
  "reaui.design_card_row",
  "reaui.design_status",
  "reaui.design_action_bar",
  "reaui.design_notice",
  "reaui.design_menu",
  "reaui.design_disclosure",
  "reaui.design_path_selection",
  "reaui.design_token_insert_group",
  "reaui.design_ordered_list_editor",
  "reaui.design_preset_manager",
  "reaui.design_hierarchy_preview",
  "reaui.design_external_operation_status",
  "reaui.design_review_header",
  "reaui.design_review_footer",
  "reaui.design_stale_review",
  "reaui.design_review_shell",
  "reaui.design_confirmation_dialog",
  "reaui.design_inline_review",
  "reaui.icons",
}

local tests = {}

function tests.every_public_module_loads()
  for _, name in ipairs(MODULES) do
    assert(type(require(name)) == "table", name .. " returns a module table")
  end
end

local passed = 0
for name, test in pairs(tests) do
  local ok, err = pcall(test)
  if not ok then error(name .. ": " .. tostring(err)) end
  passed = passed + 1
end
return passed
