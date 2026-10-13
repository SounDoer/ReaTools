# Native Gallery Validation Runbook

Use this runbook to complete the DS016 visual and interaction gate in a real
REAPER window. The Gallery uses deterministic fixtures only and does not call
product services, edit a REAPER project, connect to Wwise, or write product
settings.

## Start a scene

From the ReaProjectLink repository, run:

```powershell
./tests/open_design_system_gallery.ps1 `
  -Section Components `
  -Theme light `
  -Preview wide
```

Allowed sections are Foundations, Components, Patterns, Cross-product
Scenarios, and Diagnostics. Theme is light or dark. Preview is compact,
standard, or wide. The launcher opens a separate visible REAPER instance so the
test does not use the current project.

The same values can be changed inside the Gallery. Use the launcher parameters
when a run must begin from a reproducible initial scene.

The automated launcher is intentionally different: it renders all 30 Section,
Theme, and Preview combinations in one hidden Gallery instance. Only this
manual launcher opens a visible instance for inspection.

## Record the environment

Before judging components, record:

- date and reviewer;
- current implementation commit;
- Windows version and monitor arrangement;
- REAPER and detected ReaImGui versions from Diagnostics;
- display scaling for every monitor used;
- whether the Gallery is floating or docked;
- resolved font face when it can be identified.

Use [the current Windows validation record](validation/2026-10-12-windows.md) or
copy it for a new date. Change only cells actually inspected; an unavailable
scale remains Blocked rather than becoming Pass by inference.

## Foundations

For Light and Dark at all three preview widths:

1. Compare title, heading, body, label, metadata, and code roles. Hierarchy must
   remain clear without making metadata unreadable.
2. Confirm English, Chinese, Japanese, punctuation, identifiers, and paths show
   no missing-glyph boxes on the supported host.
3. Confirm control, container, and popup rounding looks consistent and does not
   clip borders or focus.
4. Check Diagnostics reports the expected theme, logical preview width,
   platform, ReaImGui API, and DPI scale.

## Components

For each applicable control:

1. Inspect default, hover, pressed, focused, disabled, read-only, selected,
   loading, empty, failed, stale, invalid, running, and danger states shown by
   its fixtures.
2. Traverse enabled controls with native keyboard navigation. Visible order and
   focus order must agree; disabled and static content must not create dead
   stops.
3. Activate one representative control by pointer and keyboard and verify the
   semantic event line matches the action.
4. Check long labels, paths, validation messages, and descriptions for
   clipping, overlap, or inaccessible complete values.
5. Open Dropdown, Menu, and Disclosure surfaces; inspect placement, close
   behavior, focus, and nested controls.
6. Resize the real window around each fixture's transition in addition to using
   Compact, Standard, and Wide presets.

## Patterns

1. Edit and commit Path Selection and Token Insert Group values; check wrapping
   and repeated insertion.
2. Select, add, delete, and request movement in Ordered List Editor; boundary
   actions must disable correctly.
3. Inspect Preset Manager selection, naming, empty/busy states, and destructive
   action hierarchy without allowing a product effect.
4. Expand deep Hierarchy Preview nodes and check long leaves without relying on
   horizontal scrolling.
5. Compare running, succeeded, failed, cancelled, stale, and partial operation
   feedback; every state must remain explicit without motion or color alone.
6. In Confirmation Dialog, verify Cancel receives safe default focus, Enter
   does not accidentally confirm, Escape and close cancel, and focus returns
   appropriately where the host supports it.
7. In Inline Review, confirm blockers prevent completion, warnings remain
   visible, actions reflow, and no redundant dialog follows an already-complete
   review.

## Cross-product Review

1. Confirm Review Header, issue Notice, decision control, details Disclosure,
   and Footer read in task order.
2. Scroll long content while the Footer remains available and does not cover
   body content.
3. Inspect Compact, Standard, and Wide previews for vertical growth rather than
   primary horizontal scrolling.
4. Inspect Stale Review separately: current decisions must be absent, Refresh
   must be the only continuation, and completion must be unavailable.

## Display scales and window modes

Repeat the applicable high-value scenes at 100%, 125%, 150%, and 200% wherever
the validation host supports them. Include floating and docked windows and move
between same-DPI and mixed-DPI monitors when available. Check text rasterization,
icons, one- and two-unit strokes, borders, rounding, popup placement, saved
window size, and responsive behavior after the move.

Changing Windows scale or monitor configuration is outside the Gallery. Do not
change system settings merely to turn an unavailable matrix cell into a pass.

## Result handling

- Pass means the exact recorded scene was inspected and met the contract.
- Fail records the component or Pattern, theme, width, scale, input method, and
  a concise reproducible mismatch.
- Blocked records the missing host, display scale, window mode, or automation
  capability.
- Not applicable is used only when the contract states that the state or
  interaction has no coherent meaning for that item.

After fixes, rerun `tests/run_design_system_validation.ps1` and repeat only the
manual cells affected by the change plus any shared Foundation cells it can
influence. Product migration begins only when the applicable cells are Pass or
an accepted non-blocking platform variation is documented.
