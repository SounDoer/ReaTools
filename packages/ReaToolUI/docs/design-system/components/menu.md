# Menu Contract

Status: Initial Slice 2D contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual opening,
dismissal, keyboard navigation, focus return, and placement checks remain open
before product migration.

Menu holds secondary or low-frequency actions behind an accessible More actions
Icon Button. Items are ordered actions or separators. Actions require unique IDs
and labels and may be disabled or marked with danger intent.

Selecting an enabled item emits `menu.action_selected`; Product code executes
the effect. Danger changes action styling but is not a blocked status and does
not replace consequence-appropriate confirmation. The first version excludes
submenus, checkable items, arbitrary embedded controls, and product callbacks.

Automated checks cover trigger labeling, popup lifecycle, separators, disabled
and danger items, unique IDs, event payloads, and style balance. Manual checks
cover opening, dismissal, keyboard navigation, focus return, and placement.
