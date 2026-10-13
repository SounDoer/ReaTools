# Status and Danger Semantics

Status: Confirmed by DS005 on 2026-10-12.

The shared design system separates a condition from the consequence of an
action. Conditions use the `neutral`, `ready`, `warning`, and `blocked` status
roles. Potentially destructive actions use the independent `danger` action
role.

This distinction governs token names, component variants, content, and visual
treatment. It does not preserve any color from the pre-design-system themes.

## Condition roles

| Role | Meaning | Typical user response |
| --- | --- | --- |
| `neutral` | Information with no positive or adverse condition | Read or continue normally |
| `ready` | Requirements are satisfied or a positive condition is confirmed | Proceed when desired |
| `warning` | The workflow can continue, but attention or an informed choice is needed | Review before proceeding |
| `blocked` | The workflow cannot safely or correctly continue until an issue is resolved | Resolve the stated issue |

These roles describe the current condition, not the visual intensity of a
message. A long message is not automatically `warning`, and a red-looking
element is not automatically `blocked`.

The four roles are not a single numeric severity scale. In particular,
`neutral` and `ready` express different meanings rather than lower and higher
severity.

## Danger action role

`danger` describes an action whose consequence may be destructive, difficult
to reverse, or materially disruptive. Examples include deleting stored data,
overwriting an existing destination, discarding unresolved work, or detaching a
resource when recovery is not straightforward.

Danger is not a fifth status. It belongs to the action taxonomy and may coexist
with any condition:

- a blocked Review may offer a safe corrective action;
- a ready project may still expose a dangerous Delete action;
- a warning may explain the consequence of a dangerous overwrite action;
- a neutral Settings page may contain a destructive reset action.

The confirmation pattern for a dangerous action is defined separately by DS013.
The `danger` role identifies consequence; it does not automatically require the
same confirmation for every action.

## Token responsibilities

Condition tokens use the status branch:

```text
semantic.color.status.neutral.foreground
semantic.color.status.neutral.background
semantic.color.status.ready.foreground
semantic.color.status.warning.foreground
semantic.color.status.blocked.foreground
```

Additional properties such as `background`, `border`, and `icon` are added only
when the component inventory demonstrates a distinct reusable need.

Dangerous actions use the action branch:

```text
semantic.color.action.danger.default
semantic.color.action.danger.hover
semantic.color.action.danger.pressed
semantic.color.action.danger.foreground
```

The system does not define `semantic.color.status.danger`, and a destructive
button does not consume the `blocked` status color merely because both roles may
use colors from a related family.

Component tokens preserve the same separation:

```text
component.notice.blocked.background.default
component.status.warning.foreground.default
component.button.danger.background.default
component.button.danger.foreground.default
```

Literal palette values are selected later while rebuilding the themes. Every
pairing must satisfy DS003.

## Content and visual cues

Every status presentation includes understandable language. Color is reinforced
by at least one persistent cue such as an icon, label, placement, or component
shape. A colored dot without a readable status label is insufficient when the
status affects a decision.

Status text explains the condition and, when useful, the next step:

- `Ready to publish` states a ready condition;
- `Review two changed references` states a warning and its task;
- `Destination is unavailable. Reconnect the NAS to continue.` states a block
  and its resolution.

Dangerous actions use consequence-oriented verbs where possible, such as
`Delete snapshot` or `Overwrite destination`, rather than relying on a red
button labeled only `Continue`.

## Classification rules

Choose a condition role by asking what the user can safely do now:

1. If the workflow cannot continue, use `blocked`.
2. If it can continue but needs attention or an informed decision, use
   `warning`.
3. If prerequisites are satisfied or a positive condition is confirmed, use
   `ready`.
4. Otherwise use `neutral`.

Classify an action separately by asking what happens after activation. Use
`danger` when the consequence is destructive or materially hard to reverse,
regardless of the surrounding status.

Do not add synonyms such as `success`, `error`, `critical`, or `info` merely to
match a color or an external library. A new shared role requires a meaning that
cannot be expressed accurately by this taxonomy and a confirmed workflow that
needs it.

## Component expectations

- Status, Notice, Badge, and validation patterns declare one of the four
  condition roles when they communicate a condition.
- Button and action-menu patterns declare `danger` only for consequence, never
  for message severity.
- A component may combine condition content and a danger action without merging
  their tokens.
- Sorting, filtering, and logs store domain meaning rather than deriving it
  from the visual role or color.
- Product views do not select raw palette values to imply an unmodeled status.

No production status values or component APIs are changed by DS005 itself.
