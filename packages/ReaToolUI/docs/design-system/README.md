# ReaProjectLink Design System Charter

Status: Working charter approved for design-system development on 2026-10-12.

This design system defines a shared interface language for ReaProjectLink,
ReaAssetFlow, and future REAPER workflow tools. It separates reusable
foundations, components, and interaction patterns from product-specific
workflows so that tools can feel related without copying one another's domain
models.

The system is framework-independent at the specification level. ReaImGui is the
first reference implementation and remains the implementation target for
ReaProjectLink.

## Scope

The design system covers:

- visual foundations, including color, typography, spacing, sizing, shape,
  icons, responsive layout, and display scaling;
- reusable components and their visual and interaction states;
- cross-product patterns such as setup, review, status, notifications, error
  recovery, destructive confirmation, and settings;
- content rules for actions, status, errors, paths, revisions, counts, and
  technical details;
- accessibility requirements that are practical within ReaImGui;
- implementation conformance, testing, versioning, and deprecation.

The design system does not define:

- ReaProjectLink's Delivery, Reference, Source Project, or Master Project
  behavior;
- manifest, storage, synchronization, or publishing semantics;
- product-specific information architecture that is not reusable;
- the visual design of REAPER itself;
- a requirement that future tools use Lua or ReaImGui.

## Confirmed direction

The following direction governs the design-system work:

- The system is shared by ReaProjectLink, ReaAssetFlow, and future REAPER
  tools.
- The visual language is stable and recognizable rather than a literal copy of
  the active REAPER theme.
- Auto theme follows the active REAPER theme's brightness while retaining the
  design system's own semantic palette.
- English is the initial interface language. Components and layouts must allow
  future localization and must not depend on short English labels.
- Specifications use framework-independent semantic names. The ReaImGui layer
  maps those semantics to concrete drawing and interaction APIs.
- Product workflow decisions remain in `docs/decisions.md`. Reusable visual and
  interaction rules live under `docs/design-system/`.

## Design principles

### Make the next meaningful action clear

Hierarchy should help users understand the current condition and the next
useful action. Primary emphasis is scarce and must not become a substitute for
good information architecture.

### Preserve creative focus

The tools support work performed in REAPER. Routine success should be quiet,
setup should stay out of the daily path, and errors should explain how to
recover without unnecessary modal interruption.

### Describe state without relying on color

Color reinforces meaning but never carries it alone. Status has a label, icon,
shape, position, or other non-color signal. Warning and blocked states describe
both the condition and the available next action.

### Prefer semantic consistency over visual coincidence

A component should look and behave the same because it has the same role, not
because two screens happened to use similar values. Product views consume
tokens, components, and patterns instead of creating local variants.

### Design for constrained windows first

Every essential workflow must remain usable in a narrow docked window. Wider
layouts may improve scanning and density but must not reveal capabilities that
are unavailable at smaller widths.

### Keep technical detail available but secondary

Paths, IDs, diagnostic messages, and implementation detail remain accessible
when they help recovery or support, but routine workflows lead with user-facing
language.

### Earn complexity

New tokens, variants, and components require a demonstrated reusable need.
Product-specific exceptions remain at the product layer until repeated use
justifies promotion into the shared system.

## System layers

```text
Foundations
  -> semantic tokens and platform-independent rules

Components
  -> reusable controls, containers, feedback, and data display

Patterns
  -> recurring multi-component interaction and content behavior

Product recipes
  -> ReaProjectLink and future tools composing the shared layers

Platform adapters
  -> ReaImGui and any future implementation mapping tokens and behavior
```

Foundations, components, and patterns form the reusable design system. Product
recipes and platform adapters demonstrate and implement it without redefining
its semantics.

## Source of truth

The intended source-of-truth order is:

1. confirmed product behavior in `docs/decisions.md`;
2. shared design rules under `docs/design-system/`;
3. ReaProjectLink composition in `docs/ui-spec.md`;
4. ReaImGui mappings in `ReaProjectLink/lib/reaprojectlink/ui/`;
5. automated tests and manual validation evidence.

When sources disagree, product behavior must not be changed merely to match a
visual implementation. The discrepancy is recorded and resolved explicitly.

## Delivery phases

### Phase 1: Charter and audit

- establish scope, principles, boundaries, and terminology;
- inventory existing tokens, components, patterns, and tests;
- record gaps and open questions without turning them into decisions.

Exit criteria: this charter, the current-state audit, and the prioritized open
question list are accurate enough to guide token work.

### Phase 2: Foundations and token architecture

- define primitive, semantic, and component-token responsibilities;
- specify color, typography, spacing, sizing, shape, elevation, iconography,
  responsive behavior, display scaling, and motion policy;
- define Light, Dark, and Auto behavior;
- map the confirmed tokens to ReaImGui without changing product workflows.

Exit criteria: all existing presentation values have a documented owner, both
themes expose the same semantic contract, and new views need no unexplained
visual constants.

### Phase 3: Component specifications

- document anatomy, variants, states, behavior, content, accessibility, and
  usage guidance for each component;
- distinguish foundational controls from ReaProjectLink composition helpers;
- fill essential component gaps in priority order.

Exit criteria: an implementer can reproduce a component and its states without
reading a product view.

### Phase 4: Interaction and content patterns

- standardize setup, review, asynchronous checks, notifications, errors,
  confirmation, long lists, file selection, and settings;
- consolidate public-language rules from D080 and D081 into reusable content
  guidance without changing the confirmed terminology.

Exit criteria: recurring workflows use shared patterns and product-specific
documents describe only their domain decisions.

### Phase 5: Reference implementation and gallery

- align the ReaImGui implementation with the specifications;
- provide a developer-facing gallery of tokens, components, states, themes,
  widths, and content stress cases;
- preserve the separation between UI presentation and domain mutation logic.

Exit criteria: the shared system can be inspected without entering a live
product workflow.

### Phase 6: Validation and governance

- add structural, interaction, accessibility, theme, and smoke checks;
- validate narrow and wide layouts at representative display scales;
- define contribution, review, release, migration, and deprecation rules.

Exit criteria: changes to the shared interface language are deliberate,
reviewable, and testable.

## Change policy

- Open questions remain in `open-questions.md` until confirmed.
- Confirmed product changes are recorded in `docs/decisions.md` before the
  affected workflow or data model is changed.
- Design-system changes state their affected tokens, components, patterns, and
  implementation mappings.
- A component variant is not added solely to reproduce one screen.
- Breaking token or component changes require a migration note.
- Runtime dependencies are not added without prior user approval.

## Related documents

- `audit.md` records the current implementation and the gap between that state
  and this charter.
- `decisions.md` records confirmed design-system decisions that do not change
  product behavior.
- `open-questions.md` contains decisions that must be resolved during the next
  phases.
- `foundations/tokens.md` defines the token architecture and naming contract.
- `foundations/display-scaling.md` defines logical units and host-DPI behavior.
- `foundations/keyboard-focus.md` defines the native keyboard and visible-focus
  baseline.
- `foundations/status-and-danger.md` separates condition roles from destructive
  action intent.
- `foundations/spacing-and-sizing.md` defines the four-unit core grid and named
  optical exceptions.
- `foundations/shape.md` defines provisional control, container, and popup
  radii and their ReaImGui adapter mapping.
- `foundations/density.md` defines the single compact-but-readable density and
  its future extension boundary.
- `foundations/responsive-layout.md` defines behavior-based layout ranges and
  container-versus-component responsibilities.
- `foundations/typography.md` defines system-family usage, semantic text roles,
  and glyph-coverage gates.
- `foundations/motion.md` defines the static-first activity and transition
  policy.
- `components/architecture.md` defines the Component, Pattern, Product, and
  internal-utility boundaries.
- `components/input-inventory.md` defines the initial cross-product input set and
  deferred controls.
- `components/button.md` defines Button and Icon Button variants, states,
  semantic events, tokens, and validation.
- `components/text-field.md` defines the shared Field Shell and single-line Text
  Field structure, states, events, and validation boundary.
- `components/integer-number-field.md` defines integer buffers, parse states,
  inclusive ranges, step actions, semantic events, and responsive layout.
- `components/path-field.md` defines File and Folder variants, editable and
  read-only modes, Browse requests, long-path access, and responsive reflow.
- `components/checkbox.md` defines independent boolean choices, native label
  activation, validation presentation, and semantic change events.
- `components/dropdown.md` defines single selection, dynamic option states,
  stale-value recovery, long labels, and Select Field composition.
- `components/segmented-control.md` defines visible mutually exclusive choices,
  equal-width segments, semantic selection, and responsive stacking.
- `components/single-selection-list.md` defines one active scrollable row,
  dynamic data states, stale selection recovery, and semantic events.
- `components/card.md` defines bounded content grouping, optional emphasis,
  parent-owned width, and safe content-slot rendering.
- `components/card-row.md` defines side-by-side and stacked card layout and
  equal card height.
- `components/stat-group.md` defines equal-width metric tiles for counts.
- `components/list.md` defines inset rows, trailing status and actions, group
  labels, and the overflow toggle.
- `components/status.md` defines neutral, ready, warning, and blocked conditions
  with persistent readable role cues.
- `components/notice.md` defines actionable condition messages and responsive
  action layout.
- `components/action-bar.md` defines the context line, ordered actions,
  single trailing primary action, and full-width stacking when the row does
  not fit.
- `components/issue-item.md` defines tinted warning and blocked items with an
  inline status and optional actions, and stacked issue lists.
- `components/section-heading.md` defines the heading that titles a group of
  content and the section gap above it.
- `components/page-header.md` defines the title row, badge, meta, trailing
  actions, and the collapsed layout below the breakpoint.
- `components/menu.md` defines secondary action menus, disabled items, and
  independent danger intent.
- `components/disclosure.md` defines native expandable detail with safe content
  rendering.
- `patterns/path-selection.md` composes Path Field with checking, valid, invalid,
  and picker-unavailable lifecycle states.
- `patterns/token-insert-group.md` composes Text Field with wrapping product-
  supplied token actions and ordered semantic events.
- `patterns/ordered-list-editor.md` composes selection, ordered actions, and an
  optional product-owned editor without mutating product data.
- `patterns/preset-manager.md` composes preset selection, naming, and request
  actions while leaving persistence and confirmation to product code.
- `patterns/hierarchy-preview.md` renders validated parent-child previews with
  explicit loading, failure, stale, and partial-data states.
- `patterns/external-operation-status.md` presents explicit external-work
  outcomes and emits cancel, retry, and dismiss requests without owning jobs.
- `patterns/review.md` defines the shared Review Header, scrolling Shell,
  fixed Footer, event order, and body-replacing Stale Review safeguard.
- `patterns/confirmation-and-inline-review.md` implements consequence-based
  modal confirmation and multi-target Inline Review safeguards.
- `components/structured-data.md` defines responsive rows, tables, lists,
  hierarchy, and long-content behavior.
- `patterns/destructive-confirmation.md` selects direct execution, Confirmation
  Dialog, or Inline Review according to consequence.
- `governance/component-gallery.md` defines the development-only ReaImGui
  conformance Gallery.
- `governance/visual-validation.md` defines first-version automated and manual
  validation plus the screenshot-adoption gate.
- `governance/versioning.md` defines independent contract versions,
  compatibility, deprecation, and migration.
- `implementation-roadmap.md` defines the staged reference implementation,
  product pilots, cross-product adoption, and release gates.
- `implementation-migration-map.md` maps current code to target ownership and
  records the first safe migration seams in both products.
- `migration-readiness.md` records the shared construction and conformance
  boundary, pilot mappings, automated evidence, and remaining manual gates.
- `validation/2026-10-12-windows.md` records the reproducible automated result
  and the exact native manual cells blocked in the current Windows session.
- `manual-validation-runbook.md` provides reproducible visible Gallery launch
  commands and the complete DS016 native inspection procedure.
- `distribution-options.md` records the evaluated sharing mechanisms and the
  confirmed ReaTools monorepo package boundary.
- `release-readiness.md` records every remaining gate before contract `0.1.0`.
- `research/` contains evidence used to resolve open design-system questions.
- `../ui-spec.md` defines ReaProjectLink's current product-level UI.
- `../decisions.md` is the authority for confirmed product decisions.
