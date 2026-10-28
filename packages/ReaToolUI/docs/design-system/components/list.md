# List Contract

Status: Added on 2026-10-20 by DS022. Groups amended on 2026-10-28 by DS024.
Automated layout and event checks pass.

List shows a vertical run of inset rows with optional group headers. Product
views use it instead of hand-placing row text, status, and buttons.

```lua
local result = list.draw({
  id = "deliveries",
  variant = "standard", -- or "compact"
  items = {
    { kind = "group", id = "media", label = "Files", count = 2, collapsible = true, collapsed = false },
    { kind = "row", id = "music", title = "Music bed", detail = "Published r7",
      status = { role = "ready", text = "Synchronized" },
      action = { id = "publish", label = "Publish" },
      menu = { accessible_label = "Music actions", items = items } },
    { kind = "row", id = "dialogue", title = "Dialogue", trailing_text = "2 Items" },
  },
})
-- result = { events, action = { row, id } | nil, toggled_group = <group id> | nil }
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

In order: `trailing_text` (`metadata`, secondary color), inline Status, at
most one action button, and a menu. All are centered on the compact control
height, and the row centers that whole control line, not just the text. The
trailing group is right-aligned beside the text when the text fits
on one line next to it. Otherwise it moves to its own right-aligned line below
the full-width text, so nothing scrolls horizontally.

## Groups

- `{ kind = "group", label }` renders a header between runs of rows in the
  `body` role: the optional integer `count` in the primary text color, a
  space, then `label` in the secondary color (`3 Tracks`). The product writes
  the noun in the form that agrees with the count.
- A header sits `semantic.space.list.gap` above its own rows and
  `semantic.space.section.default` below the previous group, so each group
  reads as one unit.
- `collapsible = true` (requires `id`) makes the header a full-width
  disclosure with its arrow in the secondary color. `collapsed = true` hides
  the rows that follow, up to the next group. The product owns the collapsed
  state; the List reports clicks and never slices rows itself.
- The List has no item limit and no `Show All` row (DS024).

## Events

- `{ type = "list.row_action", id = <list id>, row = <row id>, action = <id> }`
  for a row action or a chosen menu item; `action` is also returned as
  `{ row, id }`.
- `{ type = "list.group_toggled", id = <list id>, group = <group id> }` when
  a collapsible header is clicked, with `toggled_group = <group id>`.

Disabled row actions never emit. An empty list renders nothing and emits
nothing.
