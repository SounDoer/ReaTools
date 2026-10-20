# Issue Item Contract

Status: Added on 2026-10-20 by DS022. Automated token and event checks pass.
Visual review happens in round 2 of the visual language plan.

Issue Item shows one problem that needs attention, such as a missing reference
or a blocked publish condition. Reviews and cards stack Issue Items to list
what the user must fix.

```lua
issue_item.draw({
  id = "missing-ambience",
  role = "blocked",
  message = "Ambience reference is missing",
  detail = "Expected at Refs/Ambience_r6.rpp",
  actions = { { id = "relink", label = "Relink..." } },
}) -- { events = { ... }, action = "relink" | nil }
```

## Rules

- `role` is `warning` or `blocked`. Neutral and ready conditions are not
  issues; use Status or Notice for them.
- `message` is required and renders through Status (`inline` presentation),
  so the role glyph and its tooltip come from Status. `detail` renders under
  the message in the `metadata` role with the secondary text color.
- `actions` uses Action Bar with the Issue Item id. The usual Action Bar rules
  apply: the primary action is last, and disabled actions never emit events.
- Activation emits
  `{ type = "issue_item.action_selected", id = <item id>, action = <action id> }`
  and returns the action id as `action`.

## Layout and tokens

- The item is a child window that grows to its content height.
- Background: `component.issue_item.<role>.background`
  (`semantic.color.tint.<role>.background`).
- Border: `component.issue_item.<role>.border`
  (`semantic.color.tint.<role>.border`), `semantic.border.control.width` wide.
- Rounding: `semantic.radius.control`.
- Padding: `semantic.space.inset.padding_x` and `semantic.space.inset.padding_y`.
- Actions sit `semantic.space.control.gap` below the message and are
  right-aligned by Action Bar.
- Several Issue Items are drawn with `draw_list`, which separates them by
  `semantic.space.list.gap`:

  ```lua
  issue_item.draw_list({ id = "issues", items = { item_a, item_b } })
  -- { events = { ... }, action = { item = <item id>, id = <action id> } | nil }
  ```

  `items` must not be empty. Each item follows the rules above, and its
  events are forwarded unchanged.
