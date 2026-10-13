# Preset Manager Pattern

Status: Initial Milestone 3 contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual popup, text
editing, action, busy-state, and narrow-layout inspection remains open before
product migration.

Preset Manager composes a Dropdown, Text Field, and Save, Load, and Delete
actions. It standardizes selection, naming, action hierarchy, responsive
wrapping, disabled states, and semantic events for reusable configurations.

The Pattern owns no persistence or serialization. Product code supplies preset
identifiers and labels, tracks selected and draft-name state, decides whether a
save creates or replaces data, applies confirmation rules for overwrite or
deletion, reads and writes storage, and reports loading or failure states.

Input events are emitted before an action requested in the same frame. Actions
emit `preset.save_requested`, `preset.load_requested`, or
`preset.delete_requested` with the current selection, selected item, and draft
name. Save requires a non-whitespace name. Load and Delete require an available
selection. A busy manager disables all inputs and actions; the active action may
show a caller-provided running label.

Dropdown dynamic states and stale-selection behavior follow the Dropdown
contract. Destructive confirmation is intentionally not embedded here: product
code combines this Pattern with Confirmation Dialog or Inline Review according
to consequence.
