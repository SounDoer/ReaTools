# Disclosure Contract

Status: Initial Slice 2D contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual keyboard
expansion, focus, wrapping, and nested-control checks remain open before product
migration.

Disclosure progressively reveals optional detail under one native expandable
heading. It requires a stable ID and label and accepts optional description,
default-open state, disabled state, and a content slot.

The component returns current open state but does not persist it or execute
product behavior. Content is rendered only while open. Native Tree interaction
provides pointer and keyboard behavior. The implementation always restores the
Tree stack before rethrowing a content error.

## Inset variant, detail, and role (DS022)

Added on 2026-10-20. Automated checks pass; visual review happens in round 2
of the visual language plan.

- `variant` is `default` or `inset`. The inset variant draws the header row as
  a framed row on `semantic.color.surface.inset` with rounding
  `semantic.radius.control`, horizontal padding
  `semantic.space.inset.padding_x`, and a height of `semantic.size.row.single`.
  Hover and pressed use the quiet action backgrounds.
- `detail` is an optional non-empty string drawn right-aligned on the header
  row in the `metadata` role with the secondary text color. In the inset
  variant it ends `semantic.space.inset.padding_x` before the row edge.
- `role` is an optional Status role. When set, the Status glyph (with its role
  label as the tooltip) follows the label.
- An inset Disclosure whose `role` is `warning` or `blocked` opens by default.
  Like `default_open`, this sets the initial state only.

Disclosure is not a Card, navigation section, modal, or replacement for content
that is required to make a decision. Automated checks cover open and closed
rendering, default state, disabled behavior, descriptions, callback results and
failures, and stack balance. Manual checks cover keyboard expansion, focus,
wrapping, and nested controls.
