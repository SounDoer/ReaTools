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

Disclosure is not a Card, navigation section, modal, or replacement for content
that is required to make a decision. Automated checks cover open and closed
rendering, default state, disabled behavior, descriptions, callback results and
failures, and stack balance. Manual checks cover keyboard expansion, focus,
wrapping, and nested controls.
