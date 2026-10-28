# Card Contract

Status: Initial Slice 2D contract completed on 2026-10-12. DS022 revised the
anatomy on 2026-10-20: title row, status slot, body, and footer; DS024 added
sections on 2026-10-28. Automated
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
   (Stat Group, List, Notice, text). A body that draws nothing adds no block.
5. **Sections**: optional ordered
   `sections = { { id, heading, render, actions? } }` (DS024), for content the
   card lists by name, such as what is registered and what is selected in the
   host application. Each section follows the previous block behind its own
   separator, with `semantic.space.footer.padding_y` below the separator, then
   a Section Heading (`heading` role, `gap_above = false`), the caller's
   `render` content, usually a compact List, and, when `actions` is set, an
   Action Bar of those actions (for example `Register` / `Unregister`). The
   content and the Action Bar each sit `semantic.space.stack.tight` below
   what precedes them.
   A section with nothing to list keeps its heading and shows one short empty
   text, for example `Nothing selected`, wrapped in the `body` role with
   `semantic.color.text.secondary`.
   A non-nil value returned by `render` or a chosen section action becomes
   the card action. Sections
   stay with the content when the footer is pinned. `selection` (DS023) is
   rejected.
6. **Footer**: optional `footer = { context?, actions }`, drawn by Action Bar
   below its own separator. The footer sticks to the card bottom when the card
   is taller than its content.

Blocks are separated by `semantic.space.block.gap`. The footer content sits
`semantic.space.footer.padding_y` below its separator. A card draws one
separator before each section and one before the footer, and no others.

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
  for the trailing button, a chosen menu item, a section action, or a
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
natural height and shrinking, trailing, menu, section, and footer actions,
section separators and headings, section placement under a pinned footer,
empty cards and bodies, variants, callback failures, balanced Child and style stacks, and
invalid inputs. Gallery fixtures cover default, emphasized, trailing icon,
trailing menu, status detail, footer, filled and empty sections, and
title-free cards in both themes.
