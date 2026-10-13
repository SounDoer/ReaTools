# Token Insert Group Pattern

Status: Initial Milestone 3 contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual editing,
focus, wrapping, and repeated-insertion checks remain open before product
migration.

Token Insert Group composes one Text Field with a wrapping set of token Buttons.
Activating a token appends its product-supplied string to the current value and
emits `token.inserted`, `field.changed`, and `field.committed` in that order.

Each token requires a stable ID, visible label, and inserted value and may be
disabled. Product code owns the token grammar, supported set, expansion,
validation, meaning, and persistence. The Pattern does not parse, reorder,
deduplicate, or rewrite tokens. An optional separator is inserted before the
token; the default is direct concatenation, matching ReaAssetFlow naming.

Buttons remain inline while their measured labels fit and wrap to later rows
without truncation. Text Field editing and validation behavior is preserved.
Automated checks cover integrity, append behavior, event order, disabled tokens,
wrapping, and Text Field event forwarding. Manual checks cover editing, focus,
button wrapping, and repeated insertion before product use.
