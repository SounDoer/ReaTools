# Dropdown Contract

Status: Initial Slice 2C contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual popup, Escape,
focus, and long-label checks remain open before product migration.

Dropdown selects one value from a set that is not best presented as simultaneous
choices. Confirmed uses include ReaProjectLink lane and revision choices and
ReaAssetFlow scope, conflict policy, WorkUnit, target, preset, and object type.

## Component boundary

The low-level Dropdown owns the current preview, popup options, one selected
value, disabled interaction, complete-label tooltips, dynamic data presentation,
stale-value detection, styling, and semantic change event. `draw_field` composes
that control with the shared Field Shell for a visible label, description, and
validation message.

Product code owns option loading, refresh, ordering, IDs, domain meaning,
persistence, and the consequences of selection. The component is not searchable
and does not support multiple selection, arbitrary values, headers, separators,
or product commands inside the popup.

## Inputs

The component requires a stable `id` and an ordered `options` array. Every
option has a unique string `id` and visible `label`; the entire option table is
returned for product metadata access. `value` is a string ID or `nil`.

`data_state` is `ready`, `loading`, `empty`, or `failed`. Optional labels may
replace the generic loading, empty, failed, and unselected preview wording.
Empty state cannot contain options. Non-ready states keep the control visible
but unavailable.

When a stored `value` is absent from the current options, `stale_label` is
required. The stale preview remains visible and the result reports `stale=true`;
ready replacement options remain selectable. This prevents an invisible stored
ID or silent fallback to another choice.

## Output and event

Each frame returns `value`, the selected `option` when present, `changed`,
`stale`, `data_state`, and ordered events. Choosing a different option emits one
`selection.changed` event with `id`, new `value`, and the selected option.
Choosing the already selected option, disabled interaction, and non-ready data
states emit no event.

## States and long content

Supported states include unselected, selected, hover, open, native focused,
disabled, loading, empty, failed, stale value, refreshed ready data, and Field
Shell pending, valid, or invalid validation. Invalid state changes the field
border and message without replacing the dynamic-data state.

The control fills its supplied width. Native clipping may shorten a visible
preview, but hovering the control or any option exposes its complete label.
Option IDs never appear as fallback user-facing text.

## Validation

Automated checks cover option integrity, unique IDs, state coherence, selected
and unselected previews, stale values, long-label tooltips, blocked states,
selection events, Field Shell composition, token integrity, and style balance.
Gallery fixtures cover static and dynamic ReaProjectLink and ReaAssetFlow
choices in both themes. Manual validation covers popup navigation, selection,
Escape, visible focus, and long-label inspection before product use.
