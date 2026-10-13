# Development Component Gallery

Status: Confirmed by DS015 on 2026-10-12.

The design system uses a development-only ReaImGui Gallery as the reference
rendering and interaction environment for Foundations, Components, and Patterns.
It runs inside REAPER against the real shared implementation without connecting
to product services or mutating product data.

Specifications remain the normative source for meaning and requirements. The
Gallery demonstrates whether the reference implementation conforms to those
requirements in the target host.

## Artifact form

The Gallery is a standalone development ReaScript, not a production screen, web
mockup, or product Settings page. It uses the same supported ReaImGui adapter,
tokens, themes, components, and patterns as product tools.

The final file location is chosen when the shared implementation structure is
established. It must be clearly separated from shipping product entry points and
easy for contributors to launch in a development REAPER installation.

Temporary prototypes may explore an idea in another environment. They are not
the conformance reference and are discarded or marked exploratory once the
decision is represented in the Gallery and specification.

## Safety boundary

The Gallery has no production side effects. It does not:

- modify a REAPER project, Track, Marker, Region, Item, or render setting;
- read or write manifests, presets, project state, NAS content, or Wwise data;
- connect to WAAPI, external services, LLMs, or network resources;
- launch product publish, import, sync, transfer, delete, or reset operations;
- depend on a specific user's paths, projects, or credentials.

Actions emit deterministic local demo events into an in-memory event log.
Browse, confirmation, loading, success, failure, and destructive flows use
fixtures and explicit simulation controls.

The Gallery may read packaged design-system resources needed by the reference
implementation. Any future snapshot output or saved developer preference is
specified separately and kept outside product state.

## Navigation structure

The Gallery groups examples by design-system responsibility:

1. Foundations;
2. Components;
3. Patterns;
4. Cross-product scenarios;
5. Validation and diagnostics.

The navigation itself uses shared Components and obeys DS004 focus behavior.
Sections remain usable in a narrow window and do not require the Gallery to be
maximized.

## Foundations section

The Foundations section shows:

- Primitive, Semantic, and Component token resolution where useful for
  diagnostics;
- Light and Dark semantic color roles and DS003 contrast results;
- DS009 typography roles with short, long, numeric, path, punctuation, and
  enabled-language samples;
- DS006 spacing, size, border, stroke, and optical-offset scales;
- icon names, sizes, stroke weights, and semantic colors;
- focus treatment, status roles, and danger intent;
- responsive layout ranges and active logical dimensions;
- detected ReaImGui version and viewport DPI for diagnostics.

Primitive values are visible for inspection but product-like examples consume
Semantic and Component tokens as required by DS001.

## Component section

Every supported Component has one permanent Gallery section that records:

- purpose and link or identifier for its specification;
- anatomy;
- variants;
- supported sizes;
- supported and intentionally unsupported states;
- short, typical, long, empty, and unusual content;
- pointer and keyboard interaction;
- event output;
- Compact, Standard, and Wide parent arrangements where relevant.

The state matrix includes every applicable combination from:

- default;
- hover through live interaction;
- pressed through live interaction;
- focused;
- selected or checked;
- disabled;
- read-only;
- empty and populated;
- loading and validation-pending;
- valid, invalid, warning, and blocked;
- action-running where repeat activation must be prevented.

The Gallery does not fabricate incoherent combinations merely to fill a grid.
Each omitted state is documented by the component contract.

## Pattern section

Pattern examples demonstrate composition and state ownership rather than only
static appearance. Initial sections include:

- Review Shell, Header, Footer, and Stale Review;
- Ordered List Editor;
- Token Insert Group;
- Path Selection;
- Preset Manager;
- Hierarchy Preview;
- External Operation Status;
- Confirmation Dialog and Inline Review safeguards.

Pattern fixtures expose controls for changing product-supplied state without
executing product effects. For example, a confirmation demo records `confirmed`
or `cancelled`; it never deletes a file.

## Cross-product scenarios

The Gallery contains compact representative compositions from both products:

- a ReaProjectLink card and Review sample;
- a ReaProjectLink Settings field group;
- a ReaAssetFlow naming pattern with Token Insert Group;
- a ReaAssetFlow File or Folder Path Field;
- a ReaAssetFlow Ordered List Editor row;
- a Wwise-like Hierarchy Preview using generic fixture data;
- representative long paths, target names, statuses, and external-operation
  feedback.

Fixtures imitate content shape and length, not domain behavior. Product-specific
labels may appear as test content without making their logic part of a shared
Component.

## Controls and simulation

The Gallery provides developer controls for:

- Light and Dark theme selection;
- resizable window and fixed logical-width preview presets;
- short, typical, long, empty, loading, failure, stale, and partial fixtures;
- enabling and disabling controls;
- focusing representative custom controls;
- showing dialogs and popups;
- simulating operation start, success, failure, cancellation, and retry;
- clearing and inspecting emitted demo events.

Auto theme may be shown as a theme-selection diagnostic, but visual component
matrices render the resolved Light and Dark value sets explicitly.

The Gallery does not expose a density selector while DS007 defines only one
density. A future confirmed density adds a complete matrix rather than a global
scale slider.

## Deterministic fixtures

Fixtures use stable values committed with the Gallery. They cover:

- minimal and maximum expected label lengths;
- names with spaces, punctuation, numbers, and repeated prefixes;
- Windows, macOS, Linux, NAS, and Wwise-like path shapes as plain text;
- identifiers, hashes, timestamps, counts, and revision-like numbers;
- ready, warning, blocked, danger, loading, empty, stale, and failed content;
- enabled locale samples and mixed-language user data;
- zero, one, typical, and large structured-data sets.

Fixtures contain no user secrets, real credentials, machine-specific absolute
paths, or mutable external data.

## Responsive inspection

Each responsive Component or Pattern can be inspected:

- below, at, and above its local transformation threshold;
- within Compact, Standard, and Wide page containers;
- with long content that forces natural wrapping;
- with primary and secondary action groups;
- with validation and technical details expanded.

Preview-width presets use DS002 logical units. Developers can also resize the
real Gallery window to expose behavior not anticipated by presets.

## Interaction diagnostics

An in-memory event log displays semantic events such as:

```text
button.activated
field.changed
field.committed
selection.changed
dialog.cancelled
dialog.confirmed
review.completed
```

It does not expose raw product commands or require a logging dependency. The
log helps verify that visual state and emitted behavior agree without running a
business workflow.

Focus diagnostics may show the last semantic control ID and current focused
state. They do not replace visible focus or normal keyboard testing.

## Conformance responsibility

The specification defines what a Component means and requires. The Gallery is
the approved reference instance used to review implementation behavior.

When they disagree:

- an intentional contract change updates the decision and specification first;
- an implementation mismatch is fixed in the shared implementation and Gallery;
- a Gallery-only workaround is not accepted as conformance;
- a product-local difference remains a documented Product exception until it
  satisfies DS011 promotion criteria.

Each supported Component links conceptually to one specification and one
permanent Gallery section. Removing either requires an explicit deprecation or
migration decision under the DS017 versioning rules.

## Validation workflow

Before a component change is considered implementation-complete:

1. update its contract and tokens when meaning changed;
2. update deterministic Gallery fixtures and states;
3. inspect both themes;
4. inspect relevant widths and long content;
5. test pointer and keyboard behavior;
6. inspect status, validation, disabled, loading, and danger states as applicable;
7. run structural automated checks;
8. record the manual validation result required by the release workflow.

DS016 permits stable screenshot comparison only after a controlled experiment.
The first version uses the manual visual matrix and does not claim that
cross-platform pixels are stable.

## Version and diagnostics

The Gallery displays or records:

- design-system contract version once the implementation publishes one under
  DS017;
- shared implementation version or revision;
- ReaImGui compatibility target and detected version;
- current theme and logical preview width;
- host platform and viewport DPI for diagnostics.

These values help reproduce a mismatch. They do not change the component state
being demonstrated.

No Gallery implementation or production behavior is created by DS015 itself.
