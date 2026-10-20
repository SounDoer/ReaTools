# Shape and Corner Radius

Status: Radix Themes medium-radius baseline adopted by DS019 on 2026-10-13.
Native visual calibration remains part of the DS016 manual matrix.

Shape distinguishes interactive controls, containers, and transient surfaces
without creating product-specific silhouettes. It does not communicate status,
selection, or danger by itself.

The provisional Primitive radius scale is:

| Token | Logical units | Purpose |
| --- | ---: | --- |
| `primitive.radius.0` | 0 | Deliberately square geometry |
| `primitive.radius.1` | 4 | Controls and compact interactive surfaces |
| `primitive.radius.2` | 8 | Containers and popups |

Shared code consumes `semantic.radius.control`,
`semantic.radius.container`, and `semantic.radius.popup`. Product views do not
select Primitive radii or override one instance to make it look special.

Radii use ReaImGui logical units without a DPI multiplier. Border width remains
independent from radius. A focus outline follows the same outer shape without
changing layout. DrawList icons use stroke tokens rather than borrowing a
corner-radius value.

The adapter maps Window and Child rounding to the container role, Frame
rounding to the control role, and Popup rounding to the popup role. These values
port the Radix Themes medium radius scale into logical ReaImGui units. Both
themes still require inspection at supported display scales for raster clarity.

## Borders and dividers

An outline must communicate a boundary that users need to perceive. It is not
the default way to make every element look finished.

- Editable inputs retain a stable boundary because their writable area must be
  identifiable before interaction.
- Focus, invalid state, danger, and an explicitly emphasized container may use
  stronger semantic borders.
- Ordinary secondary actions use a tonal surface and do not draw a default
  outline. Quiet actions remain transparent until interaction.
- Cards and nested containers prefer surface contrast and spacing. A subtle
  border is used only when adjacent surfaces do not establish the boundary.
- Dividers separate persistent regions such as a fixed action footer. They do
  not replace section spacing or appear between every consecutive field.
- DS022 narrows this further. Shared components draw a divider only between a
  container body and its footer (Card footer, Review footer), and inside Menu
  and Dropdown option groups. List rows, card titles, and the page header have
  no divider. Grouping uses spacing and the inset surface.

Inset surfaces (`semantic.color.surface.inset`: Stat Group tiles, List rows,
inset Disclosure headers) and tinted Issue Items use the control radius.

The adapter owns a dedicated low-emphasis divider color. Product views do not
reuse input borders for separators or add decorative lines around local groups.
