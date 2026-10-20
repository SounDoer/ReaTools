# Page Header Contract

Status: Added on 2026-10-20 by DS022. Automated layout and event checks pass.
Visual review happens in round 2 of the visual language plan.

Page Header is the first row of a page or Review: an optional back button, the
title, an optional badge, and trailing meta text and actions. Review Header
renders through it.

```lua
page_header.draw({
  id = "publish",
  title = "Publish Reference",
  badge = "r7",
  meta = "Last checked 2 min ago",
  back_label = "Back to Main",
  actions = {
    { id = "check", label = "Check Now", icon = "refresh" },
    { id = "publish", label = "Publish", variant = "primary" },
  },
}) -- { events = { ... }, action = "publish" | nil, back_requested = boolean }
```

## Rules

- `id` and `title` are required. `badge`, `meta`, `summary`, and `back_label`
  are optional non-empty strings.
- `back_label` adds a quiet Icon Button with the `back` icon and uses
  `back_label` as its accessible label. Activation sets `back_requested` and
  emits `{ type = "page_header.back_requested", id = <header id> }`.
  `back_disabled = true` disables it, and then it never emits.
- `summary` renders under the header row, aligned with the title, in the
  `label` role with the secondary text color. Review Header uses it.
- Each action needs `id` and `label`; `icon` and `variant` are optional.
  Action button ids are `<header id>-<action id>`.
- `icon_only = true` (requires `icon`) renders the action as an Icon Button
  at every width, with `label` as its accessible label, for actions such as
  Settings that never show text.
- Disabled actions never emit events. Activation emits
  `{ type = "page_header.action_selected", id = <header id>, action = <action id> }`
  and returns the action id as `action`.
- Page Header never draws a separator.

## Layout

1. The row is `semantic.size.control.medium` high. The back button, the title
   (`title` role, primary text color), and the badge are vertically centered
   on it.
2. The badge uses the `metadata` role with the secondary text color, a
   `semantic.border.control.width` outline in `semantic.color.border.subtle`,
   rounding `semantic.radius.control`, and half of the inset padding on each
   side.
3. The title wraps before the badge, so the badge stays inside the row.
4. Meta (`label` role, secondary text color) and the actions are placed
   through the shared trailing layout: right-aligned on the title row when
   they fit, otherwise right-aligned on their own line below.
5. The summary, when present, starts one item spacing below the lowest row
   item.
6. The next content starts `semantic.space.header.gap_below` below the lowest
   header item.

## Collapsed layout

When the available width is below `semantic.layout.page_header.collapse_below`:

- meta is hidden;
- an action with an `icon` renders as an Icon Button whose accessible label is
  the action label. Icon Buttons have no primary variant, so a primary action
  with an icon renders with the secondary variant;
- actions without an icon stay text buttons;
- the gap below uses `semantic.space.header.gap_below_compact`.
