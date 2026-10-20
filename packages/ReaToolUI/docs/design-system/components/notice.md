# Notice Contract

Status: Initial Slice 2D contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual wrapping,
action hierarchy, and narrow-layout checks remain open before product migration.

Notice presents a condition that needs more space, recovery guidance, or one or
more explicit actions. It uses the same neutral, ready, warning, and blocked
roles as Status and always includes a readable role label.

Notice requires `id`, role, and text. Optional actions have unique IDs, labels,
secondary or danger intent, and disabled state. Actions emit
`notice.action_selected`; the Product executes effects. Buttons remain inline
when they fit and become full-width stacked actions in narrow parents.

Since DS022 (2026-10-20) the message renders through Status in the `inline`
presentation: the role glyph comes first and the role label (or `role_label`)
is the glyph's tooltip instead of a visible `Info:` / `Blocked:` prefix. The
message text uses the role foreground color, as before.

Notice is not a Toast lifetime policy, modal dialog, validation message, or
automatic confirmation. Automated checks cover roles, action integrity,
responsive action layout, disabled actions, event payloads, tokens, and stack
balance. Manual checks cover wrapping, action hierarchy, and narrow layouts.
