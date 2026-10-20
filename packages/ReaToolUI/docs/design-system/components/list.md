# List Contract

Status: Added on 2026-10-20 by DS022. Automated layout and event checks pass.
Visual review happens in round 2 of the visual language plan.

List shows a vertical run of inset rows with optional group labels and an
optional overflow row. Product views use it instead of hand-placing row text,
status, and buttons.

```lua
local result = list.draw({
  id = "deliveries",
  variant = "standard", -- or "compact"
  items = {
    { kind = "group", label = "Media" },
    { kind = "row", id = "music", title = "Music bed", detail = "Published r7",
      status = { role = "ready", text = "Synchronized" },
      action = { id = "publish", label = "Publish" },
      menu = { accessible_label = "Music actions", items = items } },
  },
  overflow = { label = "+ 12 more", expanded = false },
})
-- result = { events, action = { row, id } | nil, overflow_toggled = boolean }
```

## Rows

- Each row is an inset surface (`component.list_row.background`, control
  radius, `semantic.space.inset.*` padding). Rows are separated by
  `semantic.space.list.gap`; there are no separators.
- `title` uses the `body` role and wraps. `detail` sits below it in
  `metadata` and the secondary text color.
- Standard rows have a minimum height of `semantic.size.row.single`, or
  `semantic.size.row.double` with a detail line. Content is vertically centered
  inside that height.
- The compact variant uses `semantic.size.row.compact` for single-line name
  lists. A compact row with `detail` is an error.

## Trailing controls

In order: inline Status, at most one action button, and a menu. All use the
compact control height. The trailing group is right-aligned beside the text
when the text fits on one line next to it. Otherwise it moves to its own
right-aligned line below the full-width text, so nothing scrolls horizontally.

## Groups and overflow

- `{ kind = "group", label }` renders a `metadata` label in the secondary
  color between runs of rows.
- `overflow = { label, expanded }` renders a final compact row with the label
  in the secondary color and a quiet `Show All` or `Show Less` button. The List
  does not slice items: the product passes the visible rows and owns the
  expanded state.

## Events

- `{ type = "list.row_action", id = <list id>, row = <row id>, action = <id> }`
  for a row action or a chosen menu item; `action` is also returned as
  `{ row, id }`.
- `{ type = "list.overflow_toggled", id = <list id> }`, with
  `overflow_toggled = true`.

Disabled row actions never emit. An empty list renders nothing and emits
nothing.
