# Stat Group Contract

Status: Added on 2026-10-20 by DS022. Automated layout checks pass. Visual
review happens in round 2 of the visual language plan.

Stat Group shows two to four counts as an equal-width row of tiles, each with
a metric number over a short label. Cards and Review summaries use it to make
scope readable at a glance.

```lua
stat_group.draw({
  id = "publish-scope",
  stats = {
    { label = "Tracks", value = 4 },
    { label = "Markers", value = 8 },
    { label = "Regions", value = 2 },
  },
}) -- { events = {} }
```

## Rules

- `stats` has two to four entries. Each needs a non-empty `label` and a string
  or number `value`.
- Tiles share the available width equally with `semantic.space.list.gap`
  between them, so they keep their ratio at narrow widths.
- Each tile uses `component.stat_group.background` (the inset surface) with
  the control radius and `semantic.space.inset.*` padding.
- The value uses the `metric` typography role; the label uses `metadata` and
  `component.stat_group.label`.
- Values never wrap. A value wider than its tile is clipped inside the tile.
- The group reserves one row and emits no events.
