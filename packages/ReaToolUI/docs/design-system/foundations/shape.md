# Shape and Corner Radius

Status: Provisional first implementation completed on 2026-10-12 within the
confirmed DS001, DS002, and DS006 boundaries. Native visual calibration remains
part of the DS016 manual matrix.

Shape distinguishes interactive controls, containers, and transient surfaces
without creating product-specific silhouettes. It does not communicate status,
selection, or danger by itself.

The provisional Primitive radius scale is:

| Token | Logical units | Purpose |
| --- | ---: | --- |
| `primitive.radius.0` | 0 | Deliberately square geometry |
| `primitive.radius.1` | 6 | Controls and compact interactive surfaces |
| `primitive.radius.2` | 10 | Containers and popups |

Shared code consumes `semantic.radius.control`,
`semantic.radius.container`, and `semantic.radius.popup`. Product views do not
select Primitive radii or override one instance to make it look special.

Radii use ReaImGui logical units without a DPI multiplier. Border width remains
independent from radius. A focus outline follows the same outer shape without
changing layout. DrawList icons use stroke tokens rather than borrowing a
corner-radius value.

The initial adapter maps Window and Child rounding to the container role, Frame
rounding to the control role, and Popup rounding to the popup role. The values
remain provisional until both themes are inspected at supported display scales
for small controls, nested containers, dialogs, clipping, and raster clarity.
