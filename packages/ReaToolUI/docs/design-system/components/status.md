# Status Contract

Status: Initial Slice 2D contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual scanability,
wrapping, and non-color comprehension checks remain open before product
migration.

Status presents a compact current condition using exactly one confirmed role:
`neutral`, `ready`, `warning`, or `blocked`. It is not an action, notification,
validation message, or destructive `danger` role.

The component requires `role` and readable `text`. DS022 replaces the visible
role prefix with a role glyph, so meaning never depends on color alone:

| Role | Glyph | Role label (tooltip) |
| --- | --- | --- |
| `neutral` | dot | Info |
| `ready` | check | Ready |
| `warning` | warning triangle | Attention |
| `blocked` | cross | Blocked |

The glyph is drawn at the current text line height in the role foreground,
followed by `semantic.space.inline.default` and the text in the same color.
Hovering the glyph shows the role label. Products may supply an equivalent
localized `role_label`; it cannot be empty or removed.

Two presentations exist:

- `inline` (default) uses the `body` typography role, for status inside a row
  or paragraph.
- `prominent` uses the `status` typography role, for the status slot of a
  Card.

An optional `detail` renders below the text in `metadata` typography and the
secondary text color. Text and detail wrap within the parent width and stay
aligned to the text start, not the glyph. `measure(options)` returns the
single-line width (glyph, gap, and text) for layout components.

`draw_glyph({ role, role_label? })` draws only the glyph, at the `body` line
height, with the same tooltip. Components that place their own text next to a
role cue, such as Disclosure, use it so the glyph and its tooltip stay
identical everywhere.

Product code classifies the condition and supplies the message. Status owns only
the shared semantic foreground and readable role cue; it emits no event and
does not execute recovery. Longer messages with actions belong in Notice.

Automated checks cover role glyphs, default and custom tooltip labels,
presentations, detail, measurement, token use, contrast, stack balance, and
invalid inputs. Gallery fixtures cover product-
shaped conditions in both themes. Manual validation covers scanability, wrapping,
and non-color comprehension before product use.
