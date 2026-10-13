# Spacing and Sizing Scale

Status: Confirmed by DS006 on 2026-10-12.

ReaProjectLink uses a four-logical-unit core grid for reusable spacing and
sizing. One- and two-unit values are restricted to named optical purposes such
as borders, focus strokes, icon strokes, and small alignment corrections.

The scale standardizes available measurements. DS007 governs density, and
responsive layout under DS008 decides which measurements individual containers
use.

## Unit model

All values in this specification are ReaImGui logical units under DS002. They
are not physical pixels and are not multiplied by display DPI in product code.

One core grid step is four logical units:

```text
1 grid step = 4 logical units
```

Reusable padding, gaps, fixed component dimensions, icon boxes, and layout
dimensions use whole grid steps unless an approved optical category applies.

## Core scale

The initial core scale is:

| Token | Logical units |
| --- | ---: |
| `primitive.space.0` | 0 |
| `primitive.space.1` | 4 |
| `primitive.space.2` | 8 |
| `primitive.space.3` | 12 |
| `primitive.space.4` | 16 |
| `primitive.space.5` | 20 |
| `primitive.space.6` | 24 |
| `primitive.space.8` | 32 |
| `primitive.space.10` | 40 |
| `primitive.space.12` | 48 |
| `primitive.space.16` | 64 |

The numeric segment expresses the number of four-unit grid steps. The scale may
gain another whole-step value when a reusable need is demonstrated. It does not
predeclare every possible integer and does not gain a token solely to legitimize
one local measurement.

Size tokens follow the same grid-step meaning:

```text
primitive.size.3 = 12
primitive.size.4 = 16
primitive.size.6 = 24
primitive.size.7 = 28
primitive.size.8 = 32
primitive.size.10 = 40
primitive.size.12 = 48
```

Spacing and size remain separate categories even when values match. `space`
describes empty distance; `size` describes the extent of an icon, control, hit
area, or other object.

## Semantic spacing roles

Components and product views consume named Semantic or Component tokens rather
than selecting a Primitive step directly. Expected semantic roles include:

```text
semantic.space.inline.tight
semantic.space.inline.default
semantic.space.stack.tight
semantic.space.stack.default
semantic.space.section.default
semantic.space.section.loose
semantic.space.region.default
semantic.space.item.horizontal
semantic.space.item.vertical
semantic.space.container.padding
semantic.space.page.padding
semantic.space.indent.default
semantic.size.control.medium
semantic.size.icon.medium
```

These names describe why the distance exists. Their exact aliases are assigned
through the DS007 density process with DS009 text metrics.

The current development implementation uses the following vertical rhythm:

| Relationship | Token | Logical units |
| --- | --- | ---: |
| items inside one compound control | `semantic.space.inline.tight` | 4 |
| related inline items | `semantic.space.inline.default` | 8 |
| closely related stacked content | `semantic.space.stack.tight` | 8 |
| ordinary stacked content | `semantic.space.stack.default` | 12 |
| groups inside one section | `semantic.space.section.default` | 16 |
| distinct sections in one task | `semantic.space.section.loose` | 24 |
| major page regions | `semantic.space.region.default` | 32 |

Global ImGui item spacing is explicitly owned by
`semantic.space.item.horizontal` (8) and `semantic.space.item.vertical` (4),
so host defaults cannot silently change the rhythm. Cards and notices use
`semantic.space.container.padding` (16). Top-level pages use the deliberately
larger `semantic.space.page.padding` (20). Tree and disclosure indentation uses
`semantic.space.indent.default` (20).

Adjacent components do not choose a gap by appearance. The composition decides
whether they belong to the same stack, section, or page region and uses that
relationship's token. These assignments remain subject to native DS016
calibration before the first contract release.

## Optical exceptions

One- and two-unit values are allowed only through purpose-specific tokens. The
initial allowed categories are:

```text
primitive.border_width.1 = 1
primitive.border_width.2 = 2
primitive.stroke_width.1 = 1
primitive.stroke_width.2 = 2
primitive.optical_offset.1 = 1
primitive.optical_offset.2 = 2
```

They may support:

- ordinary and emphasized borders;
- the two-unit focus outline defined by DS004;
- custom icon strokes;
- a documented one- or two-unit visual alignment correction where mathematical
  alignment appears visibly wrong.

They do not support:

- general padding or component gaps;
- arbitrary control height or width;
- shrinking a hit area;
- repeated local nudges that compensate for a flawed component layout;
- values such as 3, 5, 6, or 7 disguised as optical exceptions.

An optical adjustment belongs inside the shared component or icon definition.
Product views do not apply local optical offsets.

## Values that are not scale tokens

Not every runtime measurement is a design token. Text measurement, remaining
available width, centering calculations, clipping bounds, and content-derived
sizes may produce values outside the four-unit grid. They are calculated results
rather than reusable design decisions.

External API constants and domain values are also outside this scale. The
number `3` in a retry count is not a spacing exception, and an index is not a
size token.

Responsive breakpoints and content maximum widths follow the four-unit grid but
receive semantic layout names under DS008. Typography follows its own scale
under DS009. Shape and corner-radius values will be specified as a separate
foundation; DS006 does not silently convert the existing six-unit radius into
an approved spacing value.

## Component rules

- A component uses semantic spacing and size roles by default.
- A Component token is added when a stable local measurement cannot be
  expressed accurately by a shared Semantic role.
- Product views do not pass raw visual measurements to restyle one component
  instance.
- Hit targets and visible control sizes are deliberate Component or Semantic
  decisions, not incidental results of text height.
- Widths that must adapt to content use minimum, maximum, or available-width
  rules rather than an inventory of arbitrary fixed values.
- Repeated calculations are centralized in layout or component helpers.

## Examples

Valid decisions:

```text
card padding -> semantic.space.container.padding -> primitive.space.4
page padding -> semantic.space.page.padding -> primitive.space.5
section gap -> semantic.space.section.default -> primitive.space.4
major region gap -> semantic.space.region.default -> primitive.space.8
medium icon box -> semantic.size.icon.medium -> primitive.size.4
focus outline -> semantic.border.focus.width -> primitive.border_width.2
```

Invalid decisions:

```text
view-local card padding = 13
one-off button height = 30
icon nudge = 3
component gap -> primitive.space.2
```

The last example is invalid because a component should request a purpose through
a Semantic or Component token rather than consume a Primitive token directly.

## Migration and validation

Existing measurements are audit input, not compatibility requirements. During
implementation, each literal is classified as:

1. an alias to an approved Semantic or Component token;
2. a calculated runtime result;
3. an external or domain constant; or
4. an unexplained visual literal that must be removed or proposed explicitly.

Review checks both the numeric value and the token layer. A multiple of four is
not automatically valid when it has no named purpose, and a named token is not
valid when it disguises a one-screen exception.

No production measurements are changed by DS006 itself.
