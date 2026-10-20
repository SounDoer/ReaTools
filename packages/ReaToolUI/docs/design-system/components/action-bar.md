# Action Bar Contract

Status: Added on 2026-10-20 by DS022. Automated layout and event checks pass.
Visual review happens in round 2 of the visual language plan.

Action Bar places an optional context line and an ordered set of buttons. Card
footers and the Review footer use it, and product views use it instead of
hand-placing buttons with `SameLine` or `SetCursorPosX`.

```lua
action_bar.draw({
  id = "publish-footer",
  context = "2 references changed",
  actions = {
    { id = "diff", label = "View Changes" },
    { id = "publish", label = "Publish Reference", variant = "primary" },
  },
}) -- { events = { ... }, action = "publish" | nil }
```

## Rules

- `actions` may be empty only when `context` is set.
- At most one action is `primary`, and it is the last action.
- `context` uses the `label` typography role and the secondary text color.
- Each action uses Button with the scoped id `<bar id>-<action id>`.
- Disabled actions never emit events.
- Activation emits `{ type = "action_bar.activated", id = <bar id>, action = <action id> }`
  and returns the action id as `action`.

## Layout

1. The action group width is the sum of button widths plus
   `semantic.space.control.gap` between buttons.
2. When the context and the whole group fit on one line, the context sits on
   the left and the group is right-aligned on the same line.
3. Otherwise the context wraps on its own line. If the whole group fits on one
   row, it is right-aligned below the context at natural widths.
4. If the group does not fit on one row, every action takes its own
   full-width row, in order, separated by `semantic.space.control.gap`. The
   primary action, being last, ends up at the bottom. The bar never leaves a
   lone button on a partial row.

Action Bar does not draw separators. A container that needs a footer divider
(Card, Review footer) draws it above the bar.
