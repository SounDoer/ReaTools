# Button and Icon Button Contract

Status: Initial Slice 2A contract and Gallery implementation completed on
2026-10-12. Manual keyboard-focus validation remains required before product
migration.

Button initiates one user-requested action. Icon Button provides the same action
semantics in a compact square control when a familiar shared icon and a concise
accessible label are available. Both emit semantic activation events and never
execute product behavior themselves.

## Purpose and non goals

Use Button for actions such as opening a Review, applying a confirmed choice,
browsing for a path, retrying a check, or cancelling a transient surface.

Button does not represent navigation state, a boolean value, a selectable row,
or a status. Icon Button is not used merely to save horizontal space when the
icon would be ambiguous. Neither component decides whether an action requires a
Confirmation Dialog or Inline Review; DS013 owns that consequence decision.

## Variants

| Variant | Meaning | Typical placement |
| --- | --- | --- |
| `primary` | The main forward action in the current scope | One per action group |
| `secondary` | A normal alternative or supporting action | Beside or below the primary action |
| `quiet` | A low-emphasis local action whose surrounding context is sufficient | Tool rows, headers, and compact groups |
| `danger` | An action with destructive or materially hard-to-reverse consequences | Confirmation or clearly separated destructive area |

`danger` is independent of the current `neutral`, `ready`, `warning`, or
`blocked` condition. A product does not use `primary` merely to color an action
blue, or `danger` merely to make an error visually stronger.

Icon Button supports `secondary`, `quiet`, and `danger`. It does not support
`primary` in the first contract because an icon-only primary action is too easy
to miss or misunderstand.

## Anatomy

Button contains:

1. a visible action label;
2. an optional hidden identity suffix used only for stable ReaImGui identity;
3. variant background, foreground, and border treatment;
4. the native interactive and focus target.

Icon Button contains:

1. one shared icon centered in a square native interactive target;
2. a required concise accessible label used as its semantic name;
3. a visible tooltip carrying the same label when hovered;
4. variant background, foreground, border, and focus treatment.

## Size and layout

The default `medium` size:

- control height: 32 logical units;
- horizontal text padding: 12 logical units on each side;
- icon-button hit area: 32 by 32 logical units;
- icon size: 16 logical units.

DS022 adds a `compact` size (`semantic.size.control.compact`, 28 logical
units) for actions inside List rows. It changes the control height and the
icon-button hit area; padding and icon size stay the same.

Content-sized Button width is the default. `stretch` may fill the available
container width when the parent composition requires it. Product code cannot
pass arbitrary height, padding, radius, or colors.

Labels remain on one line. A parent places long or translated actions on their
own row instead of truncating the consequence. Compact layouts stack action
groups in reading order when they no longer fit.

## States

Both components support default, hover, pressed, focused, and disabled states.
Button additionally supports `running`.

- Hover and pressed use immediate visual changes with no required animation.
- Focus uses ReaImGui native navigation and the shared semantic focus color.
- Disabled controls do not activate or participate as usable actions.
- Running prevents repeat activation and requires a visible `running_label`
  such as `Publishing...` or `Checking...`.
- Running does not imply progress, success, failure, warning, or danger.
- Running width reserves the larger of the normal and running labels so the
  surrounding layout does not jump.

Icon Button does not support `running` in the first contract because an icon
alone cannot provide the persistent activity wording required by DS010.

## Interaction and events

Both components use native ReaImGui Button items, retain native pointer and
keyboard activation, and follow submission order for navigation.

Successful activation emits:

```text
{
  type = "button.activated",
  id = <stable component id>
}
```

No event is emitted while disabled or running. Product code receives the event
and decides which effect to execute.

## Public inputs

Button accepts:

- `id`: required stable identity within the current ReaImGui scope;
- `label`: required visible action label;
- `variant`: `primary`, `secondary`, `quiet`, or `danger`;
- `disabled`: optional boolean;
- `running`: optional boolean;
- `running_label`: required when `running` is true;
- `stretch`: optional boolean;
- `size`: optional, `medium` (default) or `compact`.

Icon Button accepts:

- `id`: required stable identity;
- `icon`: required supported shared icon name;
- `accessible_label`: required semantic name and tooltip text;
- `variant`: `secondary`, `quiet`, or `danger`;
- `disabled`: optional boolean;
- `size`: optional, `medium` (default) or `compact`.

Unknown variants or sizes, missing required content, a Button running without
`running_label`, and an Icon Button requesting `primary` or `running` are
contract errors.

## Token ownership

Each variant owns Component tokens for background default, hover, and pressed;
foreground default; and border default. Shared measurements use:

```text
semantic.size.control.medium
semantic.size.icon.medium
semantic.space.control.padding_x
```

Focus color remains a Semantic responsibility. Product code does not consume
the Button Component tokens directly or override one instance with a raw style
value.

## Content guidance

- Start labels with a specific verb: `Publish`, `Choose folder`, `Retry`, or
  `Cancel`.
- Name destructive consequences: `Delete preset`, not `Continue`.
- Do not include trailing punctuation unless the label is a complete question.
- Use an ellipsis only when activation opens another step that requires user
  input, not merely because an operation takes time.
- Keep an Icon Button label short enough to work as a tooltip, but complete
  enough to identify the action without seeing the icon.

## Validation

Automated checks cover input validation, semantic event output, disabled and
running suppression, stable running width, variant-token resolution, style
stack balance, Icon Button labeling, and module loading.

The Gallery matrix covers every variant in default interactive form, disabled
Button and Icon Button, running Button, long labels, both themes, and Compact,
Standard, and Wide containers. Manual keyboard validation confirms visible
focus and activation through native ReaImGui navigation before product use.
