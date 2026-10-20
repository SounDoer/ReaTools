# Card Row Contract

Status: Added on 2026-10-20 by DS022. Automated layout and height checks pass.
Visual review happens in round 2 of the visual language plan.

Card Row lays out one or more Cards. Product views use it instead of computing
card widths and placing cards with `SameLine`.

```lua
local result = card_row.draw({
  id = "master-main",
  cards = {
    { options = { id = "reference", title = "Reference", status = status }, render_body = draw_reference },
    { options = { id = "delivery", title = "Delivery", footer = footer } },
  },
})
-- result = { events, actions = { [card id] = action }, stacked = boolean }
```

## Layout

- When the content width is at least `semantic.layout.card_row.stack_below`
  (560), the cards sit side by side at equal width with
  `semantic.space.block.gap` between them.
- Below that width the cards stack at full width with the same gap between
  them.

## Equal height

Side-by-side cards get the same height. Each frame, Card Row passes the
tallest card `natural_height` from the previous frame as every card's
`min_height`. The maximum is recomputed from scratch every frame instead of
carried forward, so when a card's content shrinks (for example after
`Show Less`), the whole row shrinks on the next frame. A shorter card
stretches, and its footer stays at the bottom.

Stacked cards do not get a `min_height`.

## Ownership

Card Row copies each card's options before adding `width` and `min_height`;
it never mutates caller tables. Events from all cards are forwarded in order,
and `actions` maps each card id to its chosen action.
