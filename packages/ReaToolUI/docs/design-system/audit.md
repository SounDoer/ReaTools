# ReaProjectLink Design System Current State Audit

Status: Baseline audit as of 2026-10-12.

ReaProjectLink already has a coherent UI direction and a useful presentation
layer. The main gap is not the absence of styling; it is the absence of a fully
specified reusable contract between visual values, components, interaction
patterns, and product views.

This document remains the ReaProjectLink baseline. Cross-product component
evidence from ReaAssetFlow is recorded separately in
`research/reaassetflow-ui-inventory.md` so the current-state descriptions are
not conflated.

## Constraints

- ReaProjectLink runs inside REAPER using Lua 5.4 and the ReaImGui
  0.9-compatible API.
- The same window must work docked at approximately 320 px and floating at
  approximately 1040 px.
- ReaImGui is immediate-mode UI. DOM, CSS, browser layout, and browser
  accessibility APIs are not available.
- The current package uses system sans-serif fonts and DrawList icons. It ships
  no font or icon assets.
- Light, Dark, and Auto themes are confirmed. Auto responds to REAPER theme
  brightness rather than copying the complete REAPER palette.
- Status must never rely on color alone.
- The UI is English today, uses the default font glyph range, and substitutes
  ASCII `...` for the ellipsis character.
- New runtime dependencies require user approval.

## Existing foundations

### Color

`ui/theme.lua` defines matching Light and Dark palettes with 14 named colors:

```text
bg, surface, surface_hover, border, text, muted,
accent, on_accent, accent_bg,
ready, warning, warning_bg, blocked, blocked_bg
```

It derives `accent_hover`, `accent_active`, and `surface_active` through color
mixing. Components access theme colors through semantic-looking names rather
than embedding color literals.

Strengths:

- Light and Dark expose the same base keys.
- Status colors are distinct from the primary action color.
- Auto-theme selection and preference persistence are isolated in the theme
  module.
- Theme behavior has automated tests.

Gaps:

- Primitive color values, semantic roles, and component-level overrides are
  not separated.
- Interaction colors are partly derived and partly inherited from ImGui style;
  there is no documented state matrix.
- Focus, selection, disabled, input, overlay, scrim, and danger-action roles do
  not have an explicit token contract.
- Contrast targets have not been documented or measured.

### Typography

The current type ramp contains four system sans-serif styles:

| Current role | Size | Weight |
|---|---:|---|
| Title | 16 | Bold |
| Heading | 14 | Bold |
| Body | 13 | Regular |
| Small | 12 | Regular |

Strengths:

- The ramp is compact and appropriate for an embedded utility.
- Typography is created once by the theme layer.

Gaps:

- Line height, truncation, wrapping, numeric alignment, and long-path behavior
  are not specified as reusable rules.
- Display scaling behavior and the relationship between logical and physical
  pixels are not defined.
- Labels, metadata, code-like values, and table content have no explicit roles.
- Localization expansion and non-Latin glyph coverage are not yet defined.

### Spacing, sizing, and shape

The specification establishes a 4 px base unit, 12 px card padding, 12 px card
gap, 16 px section gap, 28 px row height, 6 px radius, and 1 px border. The theme
also sets global ImGui padding, spacing, rounding, and border values.

The component layer contains additional layout constants:

| Constant | Current value | Current purpose |
|---|---:|---|
| Page maximum width | 720 | Review and Settings content width |
| Footer height | 48 | Fixed Review footer reservation |
| Card stacking threshold | 560 | One-column/two-column transition |
| Value column | 130 | Key/value alignment |
| Toast maximum width | 520 | Notification width |

Strengths:

- Most values follow a compact 4 px rhythm.
- Narrow and wide behavior is intentionally supported.
- Repeated high-level measurements are concentrated in the component module.

Gaps:

- The scale and semantic names are not documented.
- Several values remain local literals in components and views, including
  gaps, notice padding, highlighted borders, dropdown width, and settings
  columns.
- Control heights, icon sizes, minimum interaction targets, content widths,
  and density policy are implicit.
- Responsive behavior has one width threshold but no general layout rules.

### Icons

`ui/icons.lua` draws 11 dependency-free icons with line and circle primitives:

```text
more, gear, dot, back, plus, check, cross, warning, film, upload, download
```

Strengths:

- Icons inherit semantic color and scale with text.
- No icon font or binary asset is required.
- Every registered icon has a basic primitive-drawing test.

Gaps:

- Canvas, optical size, stroke, alignment, bounding box, and filled-versus-line
  rules are not documented.
- Icon-only button labeling exists through tooltips, but keyboard focus and
  accessible-name expectations are not specified.
- There is no promotion rule for adding icons versus using text.

## Existing components

The shared component module currently exposes the following capabilities.

| Category | Current capabilities |
|---|---|
| Typography | title, heading, colored, muted, small, inline muted, section |
| Data display | key/value, value row, copy value, status, inline status, badge |
| Actions | button, disabled button, icon button, menu |
| Containers | card, centered page, Review footer |
| Feedback | notice, toast overlay, stale state |
| Selection | dropdown, segmented control |
| Disclosure and data | collapsible group, clipped list |
| Layout helpers | card width, right alignment, text/button measurement |
| Review composition | Review header and fixed footer |

Strengths:

- Domain mutation remains outside the component module.
- Components use current theme colors rather than local color literals.
- Product views share cards, notices, Review headers, footers, dropdowns, and
  selection controls.
- Long lists can use clipping.
- Components are syntax-loaded by the automated suite.

Gaps in specification:

- Anatomy, variants, states, content rules, interaction contracts, and
  accessibility expectations are not documented per component.
- Hover and active behavior exists for some controls, but focus, keyboard,
  disabled, loading, selected, validation, and destructive states are not
  described consistently.
- Some helpers mix primitive component behavior with product composition, most
  notably Review headers and footers.
- Button `kind` and notice `level` are implementation conventions rather than a
  documented public component API.

Missing or incomplete general-purpose components:

- text field, search field, numeric field, and path field;
- checkbox, radio group, and switch/toggle with a shared contract;
- tooltip and contextual help;
- progress indicator and indeterminate activity indicator;
- dialog and destructive confirmation shell;
- table or structured grid with responsive behavior;
- divider, spacer, stack, and inline layout primitives;
- skeleton or explicit loading placeholder;
- empty state as an independent component;
- validation message and field-level error presentation;
- optional tabs or navigation components for future products, if a demonstrated
  need appears.

These gaps are an inventory, not approval to implement every listed component.
Components should be added when a real workflow requires them.

## Existing patterns

### Product information architecture

D085 and `docs/ui-spec.md` define a single-panel ReaProjectLink structure with
two domain cards, full-panel Reviews, and Settings. At most one card carries the
next-step highlight and primary button.

This is a ReaProjectLink product recipe. The reusable principle is scarce
primary emphasis and clear next-step hierarchy; a two-card main panel is not a
requirement for every future tool.

### Review

Reviews share a header, issues, decisions, collapsible details, and a fixed
footer with one primary completion action. Stale publish reviews replace their
body with a refresh state.

The general Review shell and stale-state behavior are strong candidates for a
shared pattern. Delivery Lane Mapping and revision-specific choices remain
ReaProjectLink product content.

### Status and recovery

D080 defines Notice, Warning, and Blocked semantics and user-facing recovery
language. Cards and rows combine status text with semantic color. Pointer-read
failures appear contextually instead of automatically opening dialogs.

The general status taxonomy is reusable. ReaProjectLink-specific conditions and
revision labels remain product content.

### Notifications

Success toasts are reserved for results not already visible in the panel. Error
toasts persist until dismissal. Persistent global problems use banners in the
layout.

This is a reusable feedback pattern, although duration, stacking, interruption,
and repeated-message behavior still need specification.

### Content

D080 and D081 provide a strong starting point: actions begin with verbs,
conditions are states, required follow-up selection uses an ellipsis, stable IDs
are normally hidden, and technical detail is secondary.

These rules should be extracted into shared content guidance while preserving
ReaProjectLink terminology in the product specification.

## Product-specific composition

The following remain in `docs/ui-spec.md` rather than becoming universal design
system requirements:

- Source Project and Master Project card inventories;
- Reference and Delivery state priority;
- Lane Mapping options and defaults;
- revision comparison and declaration behavior;
- Publish, Import, Sync, and Synchronize domain actions;
- registered REAPER Track, Marker, Region, and Item behavior;
- the rule that the ReaProjectLink main panel has exactly two domain cards.

The shared system may supply the Card, Review, Status, Mapping Table, and action
hierarchy used to express these decisions.

## Current test coverage

Automated coverage currently confirms:

- Light and Dark palettes have matching keys;
- explicit and automatic theme resolution;
- derived color mixing;
- persisted theme preference behavior;
- every UI module loads;
- every registered icon draws primitives;
- view-model status, priority, labels, counts, and mapping behavior;
- app state and pointer-check behavior;
- Source and Master smoke scenarios inside REAPER.

Important gaps:

- no automated contrast evaluation;
- no token-schema or component-API conformance checks beyond palette keys;
- no keyboard-navigation or focus-order specification;
- no visual-regression baseline;
- no systematic width, scaling, long-content, or localization stress matrix;
- no automated assertion that product views avoid raw visual values;
- no component-gallery coverage of every state.

## Retain, evolve, and add

### Retain

- Light, Dark, and Auto theme strategy;
- the current restrained blue accent as the baseline pending token review;
- system font and dependency-free icons for the current product;
- semantic status levels and non-color labels;
- presentation/domain separation through view models and UI modules;
- shared components and product views as separate layers;
- narrow-window-first responsive intent;
- existing product information architecture and workflow decisions.

### Evolve

- the 14-color palette into primitive and semantic token layers;
- hard-coded layout measurements into a documented scale and layout tokens;
- component helpers into specified APIs with complete state contracts;
- Review and feedback behavior into reusable patterns;
- icon drawing into a documented icon system;
- English-only layout assumptions into localization-ready behavior;
- smoke coverage into a repeatable viewport and content stress matrix.

### Add when specified

- accessibility and focus requirements;
- display-scaling rules;
- token naming, versioning, and deprecation policy;
- component specification template;
- design-system gallery;
- conformance and contrast tests;
- essential input and feedback components required by confirmed workflows.

## Immediate conclusion

The existing UI should not be rewritten before the token architecture is
agreed. The next phase should preserve current product behavior, name the
semantic roles already present, expose unowned visual constants, and decide the
minimum contracts for scaling, focus, contrast, and localization.
