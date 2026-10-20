# Section Heading Contract

Status: Added on 2026-10-20 by DS022 after round 2 of the visual review.
Automated layout checks pass.

Section Heading titles a group of content inside a page, such as a run of
Cards or the Issues and Details parts of a Review. It replaces hand-placed
heading text and the cursor moves around it. The Review Shell draws its
sections through it.

```lua
local body_result = section_heading.draw({
  id = "importer",
  title = "Wwise Importer",
  gap_above = nil, -- optional boolean
}, function()
  -- content of the section
  return result
end)
```

## Rules

- `id` and `title` are required. `render` is optional; without it only the
  heading is drawn, and `draw` returns `nil`.
- The title uses the `heading` typography role and
  `semantic.color.text.primary`, and wraps.
- `gap_above` decides whether `semantic.space.section.loose` separates the
  heading from the content above it:
  - `nil` (default): the gap is added when anything has already been drawn in
    the current window, and omitted at the top of the window;
  - `true` or `false`: the caller decides. Use `false` when a container
    already supplies its own spacing, for example the first section in a
    Card body or right under a Page Header.
- The gap replaces the item spacing instead of adding to it.
- After `render`, the component ends with an empty item (see the
  architecture API rules), so a section may end with a child window such as
  an Issue Item.
- Section Heading emits no events.
