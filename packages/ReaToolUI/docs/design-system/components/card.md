# Card Contract

Status: Initial Slice 2D contract completed on 2026-10-12. DS022 revised the
anatomy on 2026-10-20: title row, status slot, body, and footer. Automated
layout and event checks pass; visual review happens in round 2 of the visual
language plan.

Card groups related content inside one bounded surface. It improves scanning and
layout hierarchy but is not inherently clickable, selectable, or collapsible.

## Anatomy

Top to bottom:

1. **Title row**: optional `icon` (a `reaui.icons` name), optional `title`
   (heading role), and an optional `trailing` control. The row has the fixed
   height `semantic.size.control.medium`, so cards with and without a trailing
   control align. A long title wraps before the trailing control and may make
   the row taller.
2. **Description**: optional secondary text.
3. **Status slot**: optional `status = { role, text, detail?, role_label? }`,
   drawn with the `prominent` Status presentation.
4. **Body**: the caller's `render_body` content, composed from shared blocks
   (Stat Group, List, Notice, text).
5. **Selection**: optional `selection = { heading, parts, actions }` for
   actions that act on the host application's current selection (DS023). It
   follows the body behind its own separator, with
   `semantic.space.footer.padding_y` below the separator, and stays with the
   content when the footer is pinned. Three rows, top to bottom:
   - `heading` in the `metadata` role and `component.card.selection.heading`
     color, like a List group label;
   - the parts, a fixed list of `{ label, value }` joined with ` · `, for
     example Tracks **4** · Markers **0** · Regions **2**. The label uses
     `body` and the numeric value `heading`, sharing a bottom edge. Nonzero
     parts use `component.card.selection.label` / `.value`; zero parts and the
     separators use `.muted`. The line wraps between parts;
   - the actions on their own row, `semantic.space.control.gap` below, on the
     Action Bar layout. Selection actions cannot be `primary`.
6. **Footer**: optional `footer = { context?, actions }`, drawn by Action Bar
   below its own separator. The footer sticks to the card bottom when the card
   is taller than its content.

Blocks are separated by `semantic.space.block.gap`. The footer content sits
`semantic.space.footer.padding_y` below its separator. A card has at most two
separators: above the selection and above the footer.

```lua
local result = card.draw({
  id = "master-reference",
  icon = "film",
  title = "Reference",
  trailing = { kind = "menu", id = "menu", accessible_label = "Reference actions", items = items },
  status = { role = "ready", text = "Ready to publish", detail = "Synchronized r2" },
  footer = { context = "2 changes", actions = { { id = "publish", label = "Publish", variant = "primary" } } },
  min_height = row_height, -- supplied by Card Row
}, function() --[[ body ]] end)
-- result = { events, action, body_result, natural_height }
```

`trailing` is either `{ kind = "icon_button", id, icon, accessible_label }` or
`{ kind = "menu", id, accessible_label, items }`.

## Results and events

`draw` returns a table:

- `events`: `{ type = "card.action_selected", id = <card id>, action = <id> }`
  for the trailing button, a chosen menu item, a selection action, or a
  footer action;
- `action`: the same action id, or `nil`;
- `body_result`: the value returned by `render_body`;
- `natural_height`: the card's content height from this frame, measured
  independently of `min_height`.

The Product executes effects. Disabled footer actions never emit.

## Height

The first frame of a card without `min_height` auto-resizes to its content.
Later frames use a fixed height of `max(natural_height, min_height)`, where
`natural_height` comes from the previous frame. Because `natural_height` ignores
`min_height`, content that shrinks makes the card shrink on the next frame.
Card Row uses `min_height` to give cards in a row equal height.

## Variants and width

The default variant provides ordinary grouping. `emphasized` strengthens the
border for the region that holds the next step; it does not imply selection or
an action. Parent layouts decide whether cards are full width, stacked, or in
columns; Card only consumes the `width` it receives.

## Safety

The implementation closes its native Child region and restores style state even
when the content callback fails, then rethrows the original error. This prevents
one faulty Gallery or product composition from corrupting later UI frames.

## Validation

Automated checks cover the fixed title row, prominent status, footer pinning,
natural height and shrinking, trailing, menu, selection, and footer actions,
selection placement under a pinned footer, the selection heading, muted zero
counts, and wrapping, empty cards, variants, callback failures, balanced Child and style
stacks, and invalid inputs. Gallery fixtures cover default, emphasized,
trailing icon, trailing menu, status detail, footer, zero and nonzero
selection, and title-free cards in both themes.
