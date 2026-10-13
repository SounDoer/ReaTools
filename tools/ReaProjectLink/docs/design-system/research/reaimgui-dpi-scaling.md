# ReaImGui DPI and Display Scaling Research

Status: Technical investigation completed on 2026-10-12. The proposed Q2
resolution still requires design review and representative display validation
before it becomes a confirmed design-system decision.

ReaImGui already presents scripts with a DPI-normalized logical coordinate
space. It renders that space at the current viewport's physical DPI and prepares
fonts for the same scale. ReaProjectLink should therefore not multiply ordinary
layout, font, or DrawList values by `GetWindowDpiScale`.

## Scope

This research answers six implementation questions:

1. what coordinate system ReaImGui exposes to Lua;
2. whether custom font sizes are automatically DPI-aware;
3. whether StyleVar measurements need manual scaling;
4. whether DrawList coordinates need manual scaling;
5. whether responsive widths are logical or physical;
6. what happens when a window moves between displays with different DPI.

The project loads ReaImGui through its `0.9` compatibility API. The locally
installed documentation was generated for ReaImGui v0.10.0.5, so both the
v0.9.3.3 implementation and the v0.10 compatibility shim were inspected.

## Findings

### ReaImGui exposes logical window coordinates

On Windows and Linux, ReaImGui reads the native client size and divides it by
the viewport DPI scale before returning the size to Dear ImGui. A
1,500-physical-pixel client area at 150% scale therefore becomes approximately
1,000 logical units. The viewport's physical framebuffer is created from
logical display size multiplied by that same DPI scale.

Implications:

- `GetWindowSize`, `GetContentRegionAvail`, cursor positions, widget sizes, and
  DrawList coordinates participate in one logical coordinate space;
- the current `560` stacking threshold and `720` maximum content width are
  already logical measurements;
- product code should compare `GetContentRegionAvail` directly with logical
  breakpoint tokens;
- dividing returned widths by DPI would incorrectly shrink the perceived
  layout range.

### GetWindowDpiScale is descriptive, not a layout multiplier

`GetWindowDpiScale` reports the DPI scale associated with the current window's
viewport, where 1.0 represents 96 DPI. The API is useful for diagnostics,
platform validation, and narrowly defined physical-pixel behavior.

It should not be multiplied into ordinary spacing, widths, heights, radii, or
DrawList coordinates because the viewport and renderer already apply that
relationship between logical coordinates and physical pixels.

### ReaImGui 0.9 rasterizes fonts for each DPI while preserving logical size

The 0.9 font implementation creates a separate atlas for each scale. It
rasterizes a requested font size at `size * scale`, applies matching rasterizer
density, and sets the font scale back so layout retains the requested logical
size. When the active viewport changes scale, ReaImGui switches the active font
atlas.

For ReaProjectLink, a body font created as size `13` remains approximately 13
logical units high while receiving more physical pixels on a higher-DPI display.
The project must not create it as `13 * GetWindowDpiScale`.

ReaImGui 0.10 moved the size argument from font creation to `PushFont`. Its 0.9
compatibility shim stores the legacy size and supplies it when the old API calls
`PushFont`, preserving the project's current calling convention.

### Style measurements should remain logical

ReaImGui does not need ReaProjectLink to call Dear ImGui's `ScaleAllSizes` for
the current integration. Style values such as window padding, frame padding,
spacing, rounding, and border width occupy the same logical coordinate space as
widgets and windows.

Multiplying the current StyleVar values by viewport DPI would enlarge layout
twice: once in the logical values and again when ReaImGui maps the viewport to
physical output.

This does not mean every existing StyleVar value is correct. It means those
values should be redesigned as logical tokens rather than DPI-adjusted values.

### DrawList geometry should remain logical

ReaProjectLink's icons use cursor positions, text-derived sizes, and DrawList
primitives. ReaImGui renders the logical DrawData into a framebuffer whose
physical size is multiplied by viewport DPI. Custom icons should therefore
continue using the same logical coordinates as the controls around them.

Manually scaling icon coordinates or size by DPI would make them larger than
the text and controls. Line thickness, 1-unit borders, and fractional alignment
may still need optical validation at 125% and 150%. If a true
one-physical-pixel hairline is needed, it should become an explicit exception
rather than the general scaling model.

### Per-monitor DPI changes are handled by the backend

On Windows, ReaImGui updates viewport scale in response to `WM_DPICHANGED` for
top-level windows and `WM_DPICHANGED_BEFOREPARENT` for docked windows. It updates
logical window position and size and selects the font resources for the new
scale. The renderer then uses the viewport's new DPI scale.

This establishes the intended behavior when a floating window moves between
monitors. It does not remove the need for a real mixed-DPI test because past
ReaImGui releases have fixed edge cases involving docked windows, font textures,
and logical positions.

### Windows DPI awareness remains an environment requirement

ReaImGui v0.9.3.3 and v0.10.0.5 contain a Windows guard for unsupported HiDPI
modes. When scaled monitors are present, the source directs users toward
REAPER's per-monitor-aware configuration. An open upstream issue also documents
conflicts with Windows compatibility mode `System (Enhanced)`.

ReaProjectLink should not attempt to work around an unsupported REAPER DPI mode
by applying its own scale. Runtime guidance and validation are safer than a
second coordinate system inside the product.

## Answers to the six questions

| Question | Answer | Confidence |
|---|---|---|
| Lua coordinate system | DPI-normalized logical coordinates | Confirmed by source |
| Font size | ReaImGui scales rasterization and preserves logical size | Confirmed for 0.9 and its 0.10 shim |
| StyleVar scaling | Pass logical values without a DPI multiplier | Confirmed by coordinate and renderer model |
| DrawList scaling | Pass logical geometry without a DPI multiplier | Confirmed by renderer model; optical quality needs testing |
| Responsive widths | Compare returned available width directly with logical breakpoints | Confirmed by viewport size conversion |
| Mixed-DPI movement | Backend updates viewport scale and font/render resources | Confirmed by source; real display validation remains |

## Proposed Q2 resolution

The design system should define size-bearing tokens in ReaImGui logical units,
using 96 DPI as the conceptual 1.0 baseline.

- Ordinary layout, typography, shape, and DrawList values are passed without a
  manual DPI multiplier.
- Responsive decisions use the logical sizes returned by ReaImGui.
- `GetWindowDpiScale` is not the application's general UI scale.
- A user-selected zoom or density setting, if introduced later, is independent
  of host DPI and requires its own design and validation.
- Pixel-sensitive optical exceptions require an explicit token and evidence
  from visual testing.
- Auto theme brightness and DPI scaling remain separate systems.

## Validation still required

Before implementation is reported complete, the reference UI should be checked
at 100%, 125%, 150%, and 200% display scaling where test hosts are available.

The validation matrix should include:

- floating and docked windows;
- moving a floating window between displays with different scales;
- body, heading, and bold font clarity;
- Button, Card, Notice, menu, dropdown, and fixed Review footer geometry;
- DrawList icons, circles, diagonals, rounding, and 1-unit borders;
- narrow layout behavior around the 560-unit threshold;
- saved window position and size after a DPI change;
- startup under the supported REAPER per-monitor DPI mode;
- ReaImGui 0.9-compatible behavior when the installed implementation is 0.10.

No supported multi-scale display setup was available through the current
non-interactive environment, so monitor-transition behavior has not been
visually verified in this research pass.

## Sources

- [ReaImGui v0.9.3.3 viewport conversion](https://github.com/cfillion/reaimgui/blob/v0.9.3.3/src/viewport.cpp#L124-L173)
- [ReaImGui v0.9.3.3 font scaling](https://github.com/cfillion/reaimgui/blob/v0.9.3.3/src/font.cpp#L62-L85)
- [ReaImGui v0.9.3.3 font atlas selection](https://github.com/cfillion/reaimgui/blob/v0.9.3.3/src/font.cpp#L125-L203)
- [ReaImGui v0.9.3.3 Windows DPI changes](https://github.com/cfillion/reaimgui/blob/v0.9.3.3/src/win32_window.cpp#L365-L400)
- [ReaImGui v0.9.3.3 OpenGL framebuffer scaling](https://github.com/cfillion/reaimgui/blob/v0.9.3.3/src/opengl_renderer.cpp#L216-L233)
- [ReaImGui v0.10 compatibility font shim](https://github.com/cfillion/reaimgui/blob/v0.10.0.5/shims/0.10.cpp#L170-L208)
- [ReaImGui v0.10 release notes](https://github.com/cfillion/reaimgui/releases/tag/v0.10)
- [ReaImGui Windows System Enhanced issue](https://github.com/cfillion/reaimgui/issues/12)
