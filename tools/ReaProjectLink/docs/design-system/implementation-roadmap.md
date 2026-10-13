# Design System Implementation Roadmap

Status: In progress. The automated reference implementation through Milestone 3
was completed on 2026-10-12. Milestones 0 through 3 remain open for their native
DS016 validation gates, and no product surface has migrated.

This roadmap turns the confirmed DS001-DS017 contract into a shared ReaImGui
implementation for ReaProjectLink and ReaAssetFlow inside the ReaTools
monorepo. Work proceeds through
small, inspectable vertical slices. Each slice includes its contract, reference
implementation, Gallery examples, automated checks, and manual validation
before product migration begins.

The first reference implementation lives with ReaProjectLink because that
product already separates theme, components, views, and smoke scenarios.
ReaAssetFlow supplies cross-product requirements from the beginning and adopts
the implementation after the shared boundaries have been exercised. Repository
decisions M001 through M005 now place the canonical package at
`packages/ReaToolUI` and require self-contained tool releases.

## Delivery principles

- Preserve product workflows and persisted data while changing presentation.
- Specify a public contract before treating an implementation helper as shared.
- Keep product effects outside Components and Patterns.
- Use Semantic and Component tokens in product-facing code; raw Primitive
  values remain inside the token and adapter layers.
- Add no runtime dependency without explicit approval.
- Keep compatibility temporary, named, tested, and removable under DS017.
- Complete one usable vertical slice before expanding the component catalog.
- Validate with both ReaProjectLink and ReaAssetFlow content even when only one
  product has migrated.

## Milestone 0 Baseline and migration map

Purpose: establish a safe starting point without changing appearance or
behavior.

Work:

1. Record the current ReaProjectLink theme keys, component helpers, direct
   ReaImGui calls, smoke scenarios, and product views that consume them.
2. Map every current helper to Foundation, Component, Pattern, Product, internal
   utility, compatibility facade, or retirement candidate.
3. Record the corresponding ReaAssetFlow panel controls and the seams that can
   later receive shared Components without moving Wwise or REAPER behavior.
4. Define the minimum conformance metadata shape required by DS017, without yet
   publishing a contract version.
5. Capture a baseline automated result and manual screenshots for human
   comparison. These screenshots are evidence only, not snapshot-test oracles.

Exit criteria:

- every existing shared-looking helper has one target owner;
- the first migration slice has no unresolved workflow dependency;
- existing ReaProjectLink tests and UI smoke scenarios pass;
- ReaAssetFlow remains unchanged and its candidate integration seams are
  documented.

## Milestone 1 Foundation spine and Gallery shell

Purpose: prove the complete token-to-ReaImGui path before building a large
component catalog.

### Contract work

- define typed Primitive, Semantic, and Component token tables;
- define Light and Dark theme maps with identical Semantic keys;
- assign initial typography, spacing, sizing, shape, border, focus, and motion
  values within DS002-DS010;
- define token validation rules for missing references, cycles, value types,
  theme parity, and forbidden product use of Primitive values;
- define the ReaImGui adapter boundary for fonts, styles, colors, focus, and
  logical measurements.

### Reference implementation

- implement pure token data and resolution separately from ReaImGui calls;
- implement a narrow adapter that converts resolved values into host styles;
- keep the existing ReaProjectLink public UI working through a temporary
  compatibility facade where necessary;
- create the development-only Gallery shell with Foundations, Components,
  Patterns, Cross-product Scenarios, and Diagnostics navigation;
- display the contract revision, ReaImGui version, theme, preview width, and DPI
  diagnostics available at that point.

### Validation

- pure structural tests cover token references, types, parity, and cycles;
- adapter tests cover balanced style and font push and pop behavior;
- Gallery fixtures show both themes, typography samples, focus, status roles,
  danger intent, long paths, and mixed-language text;
- manual validation covers 100%, 125%, 150%, and 200% display scaling where
  test hosts are available.

Implementation status: typed color, typography, spacing, sizing, radius,
border, focus, stroke, and optical-offset tokens now resolve through the
ReaImGui adapter. Motion intentionally has no numeric token in the static first
version, and responsive breakpoint values remain provisional pending visual
calibration. The Gallery exposes six typography roles, both rebuilt themes,
three fixed logical preview widths, platform, detected DPI scale, and adapter
diagnostics. Automated validation passes; the native DS016 matrix remains open.

Exit criteria:

- one semantic token resolves deterministically through the full adapter path;
- theme switching changes only theme values, not component meaning;
- the Gallery opens without product services or product-state mutation;
- existing ReaProjectLink product screens still run through the compatibility
  boundary.

## Milestone 2 Core component slices

Purpose: establish reusable controls in dependency order. Each slice is
completed before the next begins.

### Slice 2A Actions

Components:

- Button;
- Icon Button.

This slice establishes variants, activation, disabled and running behavior,
focus visibility, hit area, label and icon spacing, and semantic events. It is
the smallest end-to-end proof of a public Component contract.

Implementation status: the contract, tokens, reference Components, structural
tests, contrast checks, and Light and Dark Gallery smoke frames are complete.
Manual keyboard-focus inspection is still open, so no product call site has
migrated.

### Slice 2B Field structure and direct entry

Components:

- Field Shell;
- Text Field;
- Integer Number Field;
- Path Field with File and Folder variants.

This slice establishes labels, descriptions, validation, read-only behavior,
change versus commit events, long values, Browse placement, and narrow-layout
stacking. ReaAssetFlow naming and path fixtures are mandatory even before that
product migrates.

Implementation status: Field Shell, Text Field, Integer Number Field, and the
File and Folder Path Field variants now have contracts, tokens, reference
Components, structural and contrast tests, responsive layouts, and
deterministic Light and Dark Gallery frames using both products' content
shapes. The current 255-test core suite and unchanged 40-scenario product UI
smoke matrix pass. Manual native editing, selection, copying, horizontal scrolling,
step activation, picker handoff, and focus inspection remain open, so Slice 2B
has not passed its full completion rule and no product call site has migrated.

### Slice 2C Choice and selection

Components:

- Checkbox;
- Dropdown;
- Segmented Control;
- Single Selection List.

This slice covers static and dynamic options, loading, empty, failed, stale,
selected, focused, disabled, and invalid states. Product code continues to own
the meaning and source of the choices.

Implementation status: Checkbox, Dropdown, Segmented Control, and Single
Selection List now have contracts, tokens, reference Components, structural and
contrast tests, responsive behavior, and deterministic Light and Dark Gallery
frames using both products' content shapes. Dynamic loading, empty, failed,
stale, refreshed, selected, disabled, and invalid fixtures are represented.
Manual pointer, popup, scrolling, native keyboard, long-label, and focus checks
remain open, so Slice 2C has not passed its full completion rule and no product
call site has migrated.

### Slice 2D Information and containers

Components:

- Card;
- Status;
- Notice;
- Menu;
- Disclosure.

Badge, Key Value Row, and Toast remain candidates until their contracts satisfy
the DS011 promotion criteria. Existing helpers may remain behind the migration
facade without becoming supported Components.

Implementation status: Card, Status, Notice, Menu, and Disclosure now have
contracts, tokens, reference Components, structural and contrast checks, safe
container or popup lifecycle behavior, semantic action events, and
deterministic Light and Dark Gallery frames. The current 255-test core suite and
unchanged 40-scenario product UI smoke matrix pass. Manual pointer, keyboard,
focus, wrapping, popup-placement, and nested-control inspection remains open,
so Slice 2D has not passed its full completion rule and no product call site has
migrated.

### Component completion rule

A slice is complete only when every included Component has:

1. a written contract covering purpose, anatomy, variants, states, events, and
   invalid combinations;
2. named Semantic or Component tokens and no unexplained visual constants;
3. deterministic Gallery fixtures for both products' representative content;
4. Compact, Standard, and Wide behavior where applicable;
5. structural tests and relevant interaction checks;
6. a completed DS016 manual Gallery matrix;
7. no product workflow or storage logic inside its implementation.

## Milestone 3 Shared patterns

Purpose: compose stable Components into repeatable workflows without importing
product behavior.

Implementation order:

1. Path Selection;
2. Token Insert Group;
3. Ordered List Editor;
4. Preset Manager;
5. Hierarchy Preview;
6. External Operation Status;
7. Review Shell, Header, Footer, and Stale Review;
8. Confirmation Dialog and Inline Review safeguards.

Implementation status: Path Selection, Token Insert Group, Ordered List Editor,
Preset Manager, Hierarchy Preview, External Operation Status, and the Review
Shell, Header, Footer, and Stale Review family now have contracts, reference Patterns,
state and event tests, and Light and Dark Gallery fixtures using both products'
content shapes.
Manual picker handoff, lifecycle, editing, focus, wrapping, repeated insertion,
reordering, selected-row, popup, and busy-state inspection remains open.
Confirmation Dialog and Inline Review safeguards now complete the initial
Milestone 3 reference Pattern catalog. Manual native interaction validation
remains open before any product migration.

Each Pattern specifies state ownership, reading and focus order, action
hierarchy, responsive reflow, semantic events, and the exact boundary where the
product supplies data or executes an effect.

Exit criteria:

- every Pattern can run in the Gallery using deterministic fixtures only;
- confirmation behavior follows consequence rather than button color;
- long structured content remains usable without horizontal scrolling as the
  primary reading path;
- the Review Pattern can represent one existing ReaProjectLink Review without
  knowing its domain nouns.

## Milestone 4 ReaProjectLink pilot migration

Purpose: validate the shared contract in a real product before a broad rewrite.

### Pilot 4A Settings

Migrate Settings first because it exercises Field Shell, Checkbox, Segmented
Control, diagnostics, paths, and a destructive reset entry point without
changing a publish or synchronization workflow.

Acceptance:

- settings values and persistence behave exactly as before;
- the rebuilt themes may change appearance but preserve semantic hierarchy;
- narrow-window behavior conforms to DS008;
- reset uses the DS013 consequence-appropriate safeguard;
- direct product use of migrated raw style values is removed.

### Pilot 4B One Review

Migrate one representative Review after Settings. Select the Review that
exercises blockers, decisions, stale state, details, primary and secondary
actions, and long structured content with the least domain risk.

Acceptance:

- existing review and workflow tests remain unchanged unless they asserted old
  presentation details;
- stale review, cancellation, confirmation, and completion semantics match the
  product decisions;
- the shared Review Pattern requires no ReaProjectLink-specific branch.

### Remaining ReaProjectLink migration

After both pilots pass, migrate remaining product surfaces by composition:

1. setup and header;
2. cards and overview surfaces;
3. remaining Reviews;
4. structured lane, clip, reference, and delivery content;
5. notifications, menus, and advanced or destructive actions;
6. removal of the temporary compatibility facade.

Exit criteria:

- all migrated views declare the same design-system contract;
- product-specific layout exceptions are documented rather than hidden in
  shared variants;
- the complete automated suite and UI smoke matrix pass;
- affected manual workflow checks in `docs/validation.md` pass.

## Milestone 5 ReaToolUI extraction and ReaAssetFlow adoption

Purpose: extract the confirmed shared package within the ReaTools monorepo, then
integrate the second product without combining their business logic.

### Confirmed distribution boundary

`packages/ReaToolUI` is the canonical source location and `reaui` is the public
Lua namespace. Both tools are developed in the same repository, declare the
exact shared contract they consume, and produce independently versioned,
self-contained release artifacts. `distribution-options.md` records the
superseded alternatives and the selected boundary.

### Adoption sequence

1. add the contract declaration and adapter boundary without changing the
   current panel behavior;
2. migrate naming Pattern and Token Insert Group;
3. migrate File and Folder Path Fields;
4. migrate Dropdowns and other choice controls;
5. migrate the Ordered List Editor and Hierarchy Preview;
6. migrate Preset Manager and External Operation Status;
7. replace remaining presentation-only helpers and retire the local
   compatibility boundary.

ReaAssetFlow retains ownership of Wwise paths, WAAPI calls, WorkUnit and target
loading, naming-token grammar, conflict policy, presets, transfer behavior, LLM
assistance, and external process state.

Exit criteria:

- both products declare and pass the same contract version;
- ReaAssetFlow domain and external-operation behavior is unchanged;
- both products render the required cross-product Gallery fixtures;
- no permanent fork of canonical tokens or supported Component APIs exists.

## Milestone 6 First contract release

Purpose: publish the first contract only after it is consumable and evidenced.

Release `0.1.0` when:

- supported tokens, Components, Patterns, and adapter behavior are documented;
- the Gallery and structural tests cover the supported contract;
- ReaProjectLink and ReaAssetFlow both conform to the contract version;
- contract metadata, changelog, conformance record, and rollback guidance are
  present;
- no undocumented compatibility alias or product exception remains.

The version number is not assigned merely because Foundation code exists. A
prototype or partial migration remains an implementation revision until these
release conditions are met.

## Verification matrix

Every implementation change runs the smallest relevant checks plus all checks
required by the milestone gate.

| Change | Structural tests | Gallery matrix | UI smoke | Product workflow |
| --- | --- | --- | --- | --- |
| Token or theme | Required | Both themes and affected states | Required | Affected surfaces |
| Component | Required | All supported states and widths | Required when consumed | Affected interactions |
| Pattern | Required | Fixtures and responsive composition | Required when consumed | Affected workflow |
| Product migration | Existing and new checks | Cross-product scenario | Required | Required |
| Adapter or scaling | Required | Themes, widths, DPI | Required | Representative workflow |

Screenshot comparison remains excluded from required automation until the
DS016 stability experiment succeeds.

## Work deliberately deferred

The first implementation does not include:

- an additional density mode;
- deferred input families from DS012;
- automatic adoption of screenshot snapshot testing;
- a packaged font or icon dependency;
- a rewrite of product workflow, storage, REAPER, Wwise, WAAPI, or LLM logic;
- simultaneous migration of every product screen;
- a separate shared-package repository or runtime network dependency.

## Completed automated reference package

The implementation now contains:

1. the current-to-target migration map and cross-product inventory;
2. the complete Foundation token and ReaImGui adapter spine;
3. the supported Slice 2A through 2D Component catalog;
4. the supported Milestone 3 Pattern catalog;
5. deterministic Gallery fixtures across five sections, both themes, and all
   three preview widths;
6. public-catalog conformance, contract, behavior, contrast, and stack-balance
   checks;
7. migration-readiness mappings for Settings and Delivery Publish Review;
8. one-command validation of 255 core tests, 30 Gallery scenarios, and 40
   unchanged ReaProjectLink product UI scenarios.

The automated Gallery matrix reuses one hidden REAPER instance, while the core
suite and product UI smoke each use their own isolated instance. This preserves
active-project isolation without opening and closing one process for every
Gallery scene.

Product call sites remain unchanged until the relevant native DS016 cells pass.
Structural extraction to `packages/ReaToolUI` may proceed without changing
product presentation. After native evidence is recorded, the next product
implementation package is Milestone 4A Settings followed by the Delivery
Publish Review pilot and the staged ReaAssetFlow adoption sequence.
