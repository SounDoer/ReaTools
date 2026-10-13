# Checkbox Contract

Status: Initial Slice 2C contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual label, Space
key, and visible-focus checks remain open before product migration.

Checkbox represents one independent yes-or-no choice. Confirmed uses include
ReaProjectLink timeline mirroring and Review options. It is not a substitute
for a mutually exclusive choice, an immediate-effect Switch, or a multi-state
control.

## Inputs and responsibility

The component requires a stable `id` and visible `label`. It accepts `checked`,
`disabled`, an optional description, optional pending, valid, or invalid
validation, and optional reserved message space.

The visible label is rendered by the native Checkbox and is part of its pointer
activation target. An invalid state requires a recovery-oriented message. The
first contract deliberately excludes indeterminate state and custom label-side
actions.

Product code owns the meaning, persistence, permission, and consequences of the
boolean. The component only presents state and reports interaction.

## Output and event

Each frame returns `checked`, `changed`, and ordered events. A user toggle emits
one `checkbox.changed` event with `id` and the new `checked` value. A disabled
Checkbox keeps its supplied value and emits no event.

The Product supplies the returned value on later frames. The component does not
save settings or trigger a workflow directly.

## States and layout

Supported states are checked, unchecked, hover, pressed, native focused,
disabled, validation-pending, valid, and invalid. Invalid state adds a semantic
border and message without replacing the native focus indication. There is no
read-only Checkbox; non-editable boolean information uses a Status or data
display rather than an apparently interactive control.

The checkbox and label stay together as one native row. Description and
validation text wrap below it. Narrow parents wrap supporting text vertically
without shortening the activation label or changing the boolean meaning.

## Content guidance

Use a concise statement that reads naturally with a checked state, such as
`Mirror the source timeline`. Put consequences or technical detail in the
description. Avoid vague labels such as `Enable` when the enabled behavior is
not named.

## Validation

Automated checks cover labels, checked and unchecked changes, disabled event
suppression, validation states, reserved message space, style-stack balance,
token integrity, and contrast. Gallery fixtures cover both products' content
shapes, long supporting text, disabled, pending, valid, and invalid states in
both themes. Manual validation covers pointer activation through the label,
Space-key activation, and visible focus before product use.
