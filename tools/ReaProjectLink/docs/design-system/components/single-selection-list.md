# Single Selection List Contract

Status: Initial Slice 2C contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual scrolling,
pointer and keyboard selection, focus, and long-label checks remain open before
product migration.

Single Selection List displays a scrollable set of rows with one active record.
Its first confirmed use is selecting a ReaAssetFlow structure row for editing.
Selection identifies the record; it does not execute the row's primary action.

## Boundary and inputs

The low-level list requires a stable `id` and an ordered `items` array. Every
item has a unique string `id` and visible `label`. `value` is one selected item
ID or `nil`. `draw_field` composes the list with Field Shell.

`size` is `compact` or `standard` and selects a tokenized scroll-region height.
`data_state` is `ready`, `loading`, `empty`, or `failed`, with optional
user-facing state labels. Ready state requires at least one item; empty state
contains none. Non-ready data remains explicit and non-interactive.

Product code owns records, ordering, loading, persistence, editing, deletion,
and any Ordered List Editor actions. Multiple selection, drag reordering,
inline spreadsheet editing, hierarchy, and filtering are outside this contract.

## Selection and stale values

The selected row uses persistent visual treatment and appends `(selected)` as a
non-color cue. Focus and hover remain distinct native states. Complete row
labels are exposed on hover when the visible row is clipped.

When a stored `value` no longer exists, `stale_label` is required. The list
shows that previous selection as unavailable before the current rows and
returns `stale=true`; it never substitutes the first row silently. Selecting a
current row resolves the stale state.

## Output and event

Each frame returns `value`, selected `item` when present, `changed`, `stale`,
`data_state`, and ordered events. Selecting a different row emits one
`selection.changed` event containing `id`, value, and the complete item. A
disabled or non-ready list emits no event.

## Layout and states

The list fills its parent width and uses a tokenized vertical scroll region so
long collections do not expand the page without limit. Labels remain one row
with complete-value tooltip access. Editing controls and row actions compose
outside this low-level Component.

Supported states include unselected, selected, hover, native focused, disabled,
loading, empty, failed, stale selection, refreshed ready data, and Field Shell
pending, valid, or invalid validation.

## Validation

Automated checks cover item integrity, data-state coherence, selected and stale
presentation, non-color selection cue, scroll sizes, disabled states, complete
label tooltips, selection events, Field Shell composition, tokens, and style
balance. Gallery fixtures cover ReaAssetFlow structure rows and dynamic states
in both themes. Manual validation covers scrolling, pointer and keyboard row
selection, focus visibility, and long-label inspection before product use.
