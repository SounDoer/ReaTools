# Color Contrast Baseline

Status: Technical audit completed on 2026-10-12. The contrast rules were
confirmed by DS003. Existing palette values are historical evidence, not
requirements for the rebuilt themes.

This audit compares the pre-design-system Light and Dark palette in
`ui/theme.lua` against WCAG 2.2 contrast thresholds. WCAG is written for web
content, but its contrast ratios provide a stable, measurable target for this
embedded desktop interface. The audit identifies role and contrast risks; it
does not establish colors that the rebuilt themes must retain.

## Measurable thresholds

The proposed baseline uses these WCAG 2.2 values:

- ordinary text requires at least 4.5:1 contrast against its actual background;
- large text may use 3:1, but the current 12–16 logical-unit typography does not
  qualify for this exception;
- meaningful control boundaries, icons, and state graphics require at least
  3:1 against adjacent colors;
- disabled controls and purely decorative marks are exempt from the numeric
  minimum, but must not carry information that has no other representation;
- exact, unrounded ratios determine conformance.

These are target values, not a claim that ReaImGui itself implements or
certifies WCAG conformance.

## Method

The audit used the WCAG relative-luminance formula with the hexadecimal RGB
values currently declared in `ReaProjectLink/lib/reaprojectlink/ui/theme.lua`.
Alpha is fully opaque for all audited palette entries.

Each foreground was tested against the backgrounds where its name and current
usage make that pairing plausible. Ratios below are rounded only for display;
pass or fail was evaluated using the unrounded value.

## Current palette results

### Light theme

| Pair | Ratio | Ordinary text 4.5:1 | Meaningful UI 3:1 |
| --- | ---: | :---: | :---: |
| `text` / `bg` | 14.84:1 | Pass | Pass |
| `text` / `surface` | 16.34:1 | Pass | Pass |
| `muted` / `bg` | 5.27:1 | Pass | Pass |
| `muted` / `surface` | 5.80:1 | Pass | Pass |
| `accent` / `bg` | 4.27:1 | Fail | Pass |
| `accent` / `surface` | 4.70:1 | Pass | Pass |
| `on_accent` / `accent` | 4.70:1 | Pass | Pass |
| `ready` / `bg` | 3.92:1 | Fail | Pass |
| `ready` / `surface` | 4.31:1 | Fail | Pass |
| `warning` / `bg` | 4.03:1 | Fail | Pass |
| `warning` / `surface` | 4.44:1 | Fail | Pass |
| `blocked` / `bg` | 4.52:1 | Pass | Pass |
| `blocked` / `surface` | 4.98:1 | Pass | Pass |
| `warning` / `warning_bg` | 3.97:1 | Fail | Pass |
| `blocked` / `blocked_bg` | 4.14:1 | Fail | Pass |
| `accent` / `accent_bg` | 3.99:1 | Fail | Pass |
| `border` / `bg` | 1.24:1 | Fail | Fail |
| `border` / `surface` | 1.36:1 | Fail | Fail |
| `surface_hover` / `surface` | 1.14:1 | Fail | Fail |

### Dark theme

| Pair | Ratio | Ordinary text 4.5:1 | Meaningful UI 3:1 |
| --- | ---: | :---: | :---: |
| `text` / `bg` | 14.48:1 | Pass | Pass |
| `text` / `surface` | 13.00:1 | Pass | Pass |
| `muted` / `bg` | 6.74:1 | Pass | Pass |
| `muted` / `surface` | 6.05:1 | Pass | Pass |
| `accent` / `bg` | 5.55:1 | Pass | Pass |
| `accent` / `surface` | 4.98:1 | Pass | Pass |
| `on_accent` / `accent` | 5.85:1 | Pass | Pass |
| `ready` / `bg` | 7.67:1 | Pass | Pass |
| `ready` / `surface` | 6.88:1 | Pass | Pass |
| `warning` / `bg` | 8.35:1 | Pass | Pass |
| `warning` / `surface` | 7.50:1 | Pass | Pass |
| `blocked` / `bg` | 5.39:1 | Pass | Pass |
| `blocked` / `surface` | 4.84:1 | Pass | Pass |
| `warning` / `warning_bg` | 6.16:1 | Pass | Pass |
| `blocked` / `blocked_bg` | 4.42:1 | Fail | Pass |
| `accent` / `accent_bg` | 4.48:1 | Fail | Pass |
| `border` / `bg` | 1.42:1 | Fail | Fail |
| `border` / `surface` | 1.28:1 | Fail | Fail |
| `surface_hover` / `surface` | 1.12:1 | Fail | Fail |

## Interpretation

The primary and secondary text colors already have strong contrast in both
themes. Dark-theme accent and status colors also meet the proposed ordinary
text target on the main surfaces.

Several Light-theme accent and status pairings pass 3:1 for icons or graphical
indicators but fail 4.5:1 when used for 12–16 unit text. A color cannot therefore
be approved merely as `accent` or `warning`; its semantic token must identify
whether it is a text foreground, graphical indicator, background, or control
fill.

The current border and hover-fill differences are below 3:1. This is not an
automatic failure for every card separator: a border may be decorative when
the surface, spacing, and layout already identify the region. It is a failure
candidate when that boundary or color change is the only way to identify an
input, control, selection, hover affordance, or state.

The near-threshold Dark-theme `blocked` on `blocked_bg` and `accent` on
`accent_bg` combinations pass the 3:1 graphical threshold but should not be
used for ordinary text without adjustment.

## Confirmed Q3 resolution

1. Use WCAG 2.2 Level AA contrast values as the minimum measurable baseline.
2. Require 4.5:1 for all routine text, including secondary, metadata, status,
   link-like action, and button-label text against its actual background.
3. Do not use the large-text 3:1 exception for the current 12–16 unit type
   scale.
4. Require 3:1 for meaningful icons, control outlines, input boundaries, state
   indicators, selection indicators, and visible focus treatment.
5. Permit sub-3:1 separators, surface differences, and borders only when they
   are decorative and the component remains identifiable without them.
6. Exempt disabled controls from the numeric target, while keeping them
   recognizable, visibly unavailable, and unnecessary for understanding
   critical information.
7. Never use color as the only carrier of status, validation, selection, or
   action meaning. Pair it with text, shape, iconography, placement, or another
   persistent cue.
8. Evaluate every supported component state in both themes against the actual
   adjacent background. Do not infer conformance from a palette swatch alone.
9. Use unrounded ratios for pass/fail. For thin custom strokes and small icons,
   prefer margin above 3:1 because anti-aliasing can reduce perceived contrast.

Focus geometry and keyboard behavior are defined separately by DS004. DS003
establishes the color-change minimum for that focus treatment.

## Sources

- [WCAG 2.2 Understanding Success Criterion 1.4.3: Contrast
  (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum)
- [WCAG 2.2 Understanding Success Criterion 1.4.11: Non-text
  Contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html)
- [WCAG 2.2 Understanding Success Criterion 2.4.7: Focus
  Visible](https://www.w3.org/WAI/WCAG22/Understanding/focus-visible)
- [WCAG 2.2 Understanding Success Criterion 2.4.13: Focus
  Appearance](https://www.w3.org/WAI/WCAG22/Understanding/focus-appearance)
