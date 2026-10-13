# Display Scaling and Logical Units

Status: Confirmed by DS002. Named one- and two-unit optical exceptions are
governed by DS006 and remain subject to visual validation.

The design system uses ReaImGui logical units for all ordinary UI measurements.
ReaImGui maps those units to the current display's physical pixels, so product
code does not apply an additional host-DPI multiplier.

## Logical unit baseline

One logical unit corresponds conceptually to one pixel at the 96-DPI baseline.
At higher display scaling, ReaImGui renders that logical unit using the
appropriate physical output scale while keeping the perceived layout size
stable.

Examples of logical values include:

```text
body font size = 13
card padding = 12
corner radius = 6
compact layout threshold = 560
readable content maximum width = 720
```

These numbers express relationships inside the design coordinate system. They
are not instructions to occupy the same number of physical display pixels at
every DPI.

## Values that use logical units

The following use the same logical coordinate system:

- font sizes and text measurements;
- window, child, and content sizes;
- padding, gaps, and margins;
- control widths and heights;
- corner radii and border widths;
- cursor positions and alignment offsets;
- DrawList positions, sizes, and line thicknesses;
- responsive thresholds and maximum content widths;
- icon canvases and component interaction targets.

Tokens for these values store the logical value directly.

## Platform adapter behavior

The ReaImGui adapter passes logical values to normal ReaImGui APIs without
multiplying or dividing by the viewport DPI.

Valid behavior:

```lua
local padding = adapter.resolve("semantic.space.page.padding")
ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, padding, padding)

local available = ImGui.GetContentRegionAvail(ctx)
local compact = available < 560
```

Invalid behavior:

```lua
local dpi = ImGui.GetWindowDpiScale(ctx)
local padding = adapter.resolve("semantic.space.page.padding")
ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, padding * dpi, padding * dpi)

local logical_available = ImGui.GetContentRegionAvail(ctx) / dpi
```

The invalid example double-applies a conversion that ReaImGui already performs.

## Typography

Font tokens store their logical base size. Under the project's ReaImGui 0.9
compatibility API, ReaImGui prepares the appropriate rasterization for the
viewport DPI while preserving the requested logical layout size.

The application does not multiply the font size by `GetWindowDpiScale` and does
not independently rebuild fonts solely because a window changes monitors.

Font family, glyph coverage, weight, and line-height rules are separate
typography concerns.

## Responsive layout

Responsive rules compare the logical sizes returned by ReaImGui directly with
logical breakpoint or container tokens.

For example, a two-card layout may switch to a vertical stack when the available
logical width falls below its confirmed threshold. The decision is independent
of whether that width is rendered on a 100%, 150%, or 200% display.

Responsive behavior remains container-driven. Display DPI does not select a
layout mode by itself.

## DrawList and icons

Custom DrawList geometry uses the same logical positions and sizes as the
surrounding ReaImGui controls. Icons derived from text height therefore remain
aligned with that text without an additional DPI multiplier.

Thin strokes, diagonal lines, small circles, and rounded corners require visual
inspection at fractional display scales. A true physical-pixel hairline may be
defined only when testing demonstrates a reusable need. Such a token is an
optical exception and does not change the general coordinate model.

## DPI diagnostics

`GetWindowDpiScale` may be used to:

- report the current environment in a diagnostic view;
- confirm monitor-transition behavior during testing;
- calculate a confirmed physical-pixel optical exception;
- investigate a host or renderer defect.

It is not the application's general UI scale.

## Host DPI, zoom, and density

Three independent concepts must remain separate:

| Concept | Purpose | Current policy |
|---|---|---|
| Host DPI | Preserve perceived size and sharpness across displays | Handled by ReaImGui |
| User zoom | Intentionally enlarge or shrink the whole UI | Not provided |
| Density | Change how much content fits while retaining readability | One compact-but-readable density under DS007 |

A future zoom or density feature must define its own scale, token effects,
limits, persistence, and test matrix. It must not reinterpret host DPI.

## Validation matrix

Release-quality visual validation should cover the following environments where
test hosts are available:

| Area | Cases |
|---|---|
| Display scale | 100%, 125%, 150%, 200% |
| Window mode | Floating and docked |
| Monitor change | Same-DPI and mixed-DPI movement |
| Typography | Body, metadata, heading, bold, long text |
| Components | Button, Card, Notice, menu, dropdown, Review footer |
| Custom drawing | Icons, circles, diagonals, rounding, thin borders |
| Responsive layout | Immediately below, at, and above each threshold |
| Persistence | Saved size and position before and after a DPI change |

Structural tests should confirm that size-bearing product code uses approved
tokens and does not introduce arbitrary `GetWindowDpiScale` multiplication.
Visual validation remains necessary for raster clarity and platform-specific
behavior.

## Known environment constraint

On Windows, ReaImGui expects a supported REAPER per-monitor DPI mode when scaled
monitors are present. ReaProjectLink does not attempt to compensate for an
unsupported host mode with a second application coordinate system. A detected
environment failure should provide diagnostic guidance instead.
