# Segmented Control Contract

Status: Initial Slice 2C contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual pointer,
keyboard-focus, activation, and narrow-reading checks remain open before product
migration.

Segmented Control presents a small set of short, mutually exclusive choices
whose simultaneous visibility improves comparison. Confirmed uses include theme,
parent, and reviewed-revision choices in ReaProjectLink.

## Boundary and inputs

The low-level control requires a stable `id`, an ordered array of at least two
unique string-ID options, and a `value` matching one option. Every option has a
visible label. `draw_field` composes the control with Field Shell description
and validation. The entire control may be disabled.

The Product owns option meaning, availability, persistence, and consequences.
The component does not accept an unmatched or invisible stored value, load
dynamic data, or execute product behavior. Choices that cannot be shown
together clearly belong in Dropdown instead.

## Output and event

Each frame returns `value`, the newly selected `option` when changed, `changed`,
resolved `layout`, and ordered events. Activating an unselected segment emits
one `selection.changed` event with `id`, value, and option. Activating the
already selected segment or a disabled control emits no event.

## Layout and states

Inline layout gives every segment the width of the longest option label so the
group remains stable as selection changes. When the complete group no longer
fits the available parent width, every option becomes a full-width stacked row.
Labels are not truncated to preserve an inline arrangement.

Supported states are selected, unselected, hover, pressed, native focused,
disabled, and Field Shell pending, valid, or invalid validation. The first
version follows ordinary native focus order for each segment; it does not
require a custom single-tab-stop arrow-key model.

The unselected segment uses the neutral secondary-action surface scale so its
idle target remains discoverable and hover moves to a visibly stronger tone.
The selected segment uses the Teal soft scale and matching high-contrast text;
selection must remain immediately distinguishable from both unselected idle and
hover states. This does not make either segment a Button: the control emits
`selection.changed`, not an action event. Persistent product navigation remains
outside this component's scope and is not part of the initial confirmed
inventory.

## Content guidance

Use short parallel nouns or noun phrases. Do not combine unrelated settings,
long explanations, or actions in one group. Description text explains the
shared question; option labels state only their distinct answers.

## Validation

Automated checks cover option and value integrity, stable equal widths,
responsive stacking, selected and unselected styling, disabled suppression,
invalid borders, semantic events, token integrity, contrast, and style balance.
Gallery fixtures cover short, long, disabled, and invalid product-shaped groups
in both themes. Manual validation covers pointer selection, native keyboard
focus and activation, and narrow-window reading order before product use.
