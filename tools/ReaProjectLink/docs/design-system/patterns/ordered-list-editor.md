# Ordered List Editor Pattern

Status: Initial Milestone 3 contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual selection,
reordering, editing, and narrow-layout inspection remains open before product
migration.

Ordered List Editor composes a Single Selection List with Add, Delete, Move up,
and Move down actions plus an optional product-supplied editor for the selected
item. It is intended for ordered rules, routing rows, naming operations, and
similar user-managed sequences.

The Pattern owns action placement, responsive wrapping, disabled boundary
states, action hierarchy, and semantic request events. It does not mutate the
item array. Product code owns row schemas, validation, unique identifiers,
creation defaults, deletion consequences, persistence, undo, and the actual
reorder operation.

Selection events are emitted before an action requested in the same frame.
Actions emit `ordered_list.add_requested`, `ordered_list.delete_requested`, or
`ordered_list.move_requested`. Delete and Move include the selected item, its
identifier, and its current one-based index. Move also includes `up` or `down`.
Add remains available without a selection; Delete and Move do not. Boundary
items cannot move beyond the start or end of the list.

The optional `render_editor(item, index)` slot is presentation composition
only. It may draw fields for the current row, but its product code remains
responsible for state and effects. Compact, Standard, and Wide layouts inherit
the list sizing contract while the action row wraps instead of requiring
horizontal scrolling.
