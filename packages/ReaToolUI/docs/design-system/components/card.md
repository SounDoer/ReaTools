# Card Contract

Status: Initial Slice 2D contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual narrow and
wide composition, clipping, padding, border, and nested-control checks remain
open before product migration.

Card groups related content inside one bounded surface. It improves scanning and
layout hierarchy but is not inherently clickable, selectable, collapsible, or a
status message.

## Inputs and content

Card requires a stable `id` and accepts an optional title, description, parent-
supplied width, and content-rendering slot. The default variant provides ordinary
grouping. `emphasized` strengthens the border for a currently important region;
it does not imply selection or an action.

The Product owns content, ordering, responsive column composition, state, and
effects. Card does not add a header action API; Buttons, Menu, Status, or other
Components are composed explicitly in the content slot.

## Layout and safety

Card uses tokenized background, border, padding, and emphasis width. Height grows
with content. Parent layouts decide whether cards are full width, stacked, or in
columns; Card only consumes the width it receives. Titles and descriptions wrap
rather than forcing horizontal scrolling.

The implementation closes its native Child region and restores style state even
when the content callback fails, then rethrows the original error. This prevents
one faulty Gallery or product composition from corrupting later UI frames.

## Validation

Automated checks cover variants, tokens, width, optional header content,
callback results and failures, balanced Child and style stacks, and invalid
inputs. Gallery fixtures cover default, emphasized, title-free, long content,
and both themes. Manual validation covers narrow and wide composition, clipping,
padding, border visibility, and nested interactive controls before product use.
