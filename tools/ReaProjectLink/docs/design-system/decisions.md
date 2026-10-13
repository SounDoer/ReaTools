# ReaProjectLink Design System Decisions

This log records confirmed decisions about the shared design system. It does not
replace `docs/decisions.md`, which remains authoritative for product workflow,
domain, storage, and data-model decisions.

## Confirmed decisions

### DS001: Hierarchical three-layer token architecture

Confirmed: 2026-10-12.

Design tokens use three layers: Primitive, Semantic, and Component. Canonical
token IDs are hierarchical dot-separated paths. Each segment uses lowercase
ASCII snake case; numeric scale steps may be numeric segments.

Examples:

```text
primitive.color.blue.500
semantic.color.action.primary.default
component.button.primary.background.default
```

Primitive tokens contain literal design values. Semantic tokens name a value's
interface purpose and normally alias Primitive tokens. Component tokens express
stable component-specific decisions and normally alias Semantic tokens.

Product views consume Semantic or Component tokens. They do not consume
Primitive tokens or embed unexplained visual literals.

Platform adapters preserve a mechanical one-to-one mapping from canonical token
IDs. The ReaImGui implementation may use nested Lua tables, but it must not
invent shorter names whose relationship to the canonical ID is ambiguous.

Component tokens are added only when a reusable component needs a stable local
decision that is not adequately expressed by a Semantic token. Product names,
domain terms, and one-screen exceptions do not become shared Component tokens.

Detailed naming and reference rules are defined in `foundations/tokens.md`.

### DS002: ReaImGui logical units govern display scaling

Confirmed: 2026-10-12.

Size-bearing design tokens use ReaImGui logical units with 96 DPI as the
conceptual 1.0 baseline. ReaProjectLink passes ordinary layout, typography,
shape, StyleVar, DrawList, and responsive values to ReaImGui without multiplying
them by `GetWindowDpiScale`.

ReaImGui supplies the logical coordinate space, prepares font resources for the
viewport DPI, and renders logical DrawData to the DPI-scaled framebuffer.
Applying the same DPI multiplier in product code would double-scale the UI.

Responsive decisions compare ReaImGui's returned logical available width
directly with logical breakpoint tokens. `GetWindowDpiScale` is reserved for
diagnostics and for a narrowly specified physical-pixel exception if visual
evidence demonstrates the need.

Host DPI, optional future user zoom, and optional future density modes are
separate concepts. DS002 does not introduce a user zoom or density preference.

Representative validation at 100%, 125%, 150%, and 200%, including mixed-DPI
monitor movement where available, remains a release-quality requirement rather
than an application-side scaling mechanism.

Detailed rules are defined in `foundations/display-scaling.md`; supporting
technical evidence is recorded in `research/reaimgui-dpi-scaling.md`.

### DS003: WCAG 2.2 AA contrast targets govern the rebuilt themes

Confirmed: 2026-10-12.

The rebuilt Light and Dark themes use WCAG 2.2 Level AA contrast values as
measurable minimum targets. The existing theme values are audit evidence only;
they are not visual-compatibility constraints and do not need to be preserved.

All routine text, including primary, secondary, metadata, status, link-like
action, and button-label text, requires at least 4.5:1 contrast against its
actual background. The current 12–16 logical-unit type scale does not use the
large-text 3:1 exception.

Meaningful icons, control outlines, input boundaries, state indicators,
selection indicators, and visible focus treatments require at least 3:1
against adjacent colors. A border, separator, or surface difference may be
below 3:1 only when it is decorative and the component, state, or region
remains identifiable without it.

Disabled controls are exempt from the numeric minimum, but must remain
recognizable, clearly unavailable, and unnecessary for understanding critical
information. Color must not be the only carrier of status, validation,
selection, or action meaning.

Contrast is evaluated for every supported component state in both themes
against the actual adjacent background. Pass or fail uses the exact unrounded
ratio. Thin custom strokes and small icons should exceed the nominal minimum
where practical to offset the perceptual effect of anti-aliasing.

Focus geometry and keyboard behavior are defined separately by DS004.
Supporting thresholds and the historical palette audit are recorded in
`research/color-contrast.md`.

### DS004: Preserve native keyboard navigation with visible focus

Confirmed: 2026-10-12.

The shared design system provides a modest, platform-aligned keyboard baseline.
ReaProjectLink enables ReaImGui's native keyboard-navigation capability and
keeps standard control behavior intact. It does not introduce a separate global
shortcut system, key remapping, gamepad support, or custom directional engine.

Every enabled interactive control participates in navigation and exposes a
visible focused state. Static content and disabled controls do not become focus
stops. Focus order follows visible reading and task order through normal
ReaImGui submission order; product views do not maintain a separate manual tab
index.

Custom-drawn controls use a real ReaImGui interactive item and represent its
focused state. The shared default focus treatment is a two-logical-unit outline
that does not change layout and meets DS003 contrast requirements. Native focus
treatment may be retained when it meets the same visibility requirement.

Ordinary views do not force initial focus. Focused confirmations prefer the
first safe useful control and never default to a destructive action. Transient
UI uses native close and restoration behavior where supported.

Composite controls retain their native-item behavior in the first version.
Bespoke single-tab-stop and arrow-key interaction is deferred until a confirmed
workflow or usability evidence requires it.

Detailed rules and the validation checklist are defined in
`foundations/keyboard-focus.md`.

### DS005: Separate condition status from dangerous action intent

Confirmed: 2026-10-12.

The shared condition taxonomy is `neutral`, `ready`, `warning`, and `blocked`.
These roles describe what the user can safely do in the current condition:
ordinary information, satisfied prerequisites, a need for attention, or an
issue that prevents continuation.

`danger` is a separate action intent for destructive, difficult-to-reverse, or
materially disruptive consequences. It is not a fifth status. A condition and
an action intent may coexist independently, so a blocked state may offer a safe
action and a ready state may still expose a dangerous action.

Status tokens use `semantic.color.status.<role>.*`. Dangerous action tokens use
`semantic.color.action.danger.*`; the system does not define a shared
`status.danger` role or reuse `blocked` as the destructive button variant.

Every status uses readable language plus a persistent non-color cue when the
status affects a decision. Dangerous actions use consequence-oriented labels
rather than relying on color alone. Literal colors will be selected during the
theme rebuild and must satisfy DS003; existing status colors are not migration
constraints.

New shared status synonyms such as `success`, `error`, `critical`, or `info`
require a distinct confirmed meaning and workflow. They are not introduced to
mirror an external library or duplicate a color.

Detailed classification, naming, and component rules are defined in
`foundations/status-and-danger.md`. Confirmation behavior for dangerous actions
is defined separately by DS013.

### DS006: Use a four-unit core grid with named optical exceptions

Confirmed: 2026-10-12.

Reusable spacing and sizing use a four-logical-unit core grid under DS002.
Primitive numeric scale segments express the number of four-unit steps, so
`primitive.space.3` resolves to 12 logical units. Spacing and size remain
separate categories because empty distance and object extent have different
responsibilities.

One- and two-logical-unit values are permitted only through purpose-specific
border-width, stroke-width, or optical-offset tokens. They support borders,
focus treatment, custom icon strokes, and documented visual alignment
corrections. They do not support general padding, gaps, hit-area reduction, or
unexplained local nudges.

Semantic and Component tokens name the purpose of a measurement. Product views
do not consume Primitive scale values or introduce unexplained visual literals.
Content measurement, available-width calculations, clipping, indices, domain
values, and external API constants are calculated data rather than design-token
exceptions.

DS006 defines the available measurement system, not the density of a component.
DS007 governs the initial density; DS008 governs responsive layout values;
DS009 defines typography and enables final size aliases. Existing measurements
are audit input rather than compatibility requirements.

Detailed scale, exception, usage, and migration rules are defined in
`foundations/spacing-and-sizing.md`.

### DS007: Ship one compact-but-readable density

Confirmed: 2026-10-12.

The first design-system version provides one compact-but-readable density for
mouse-and-keyboard desktop production work. It does not expose Compact and
Comfortable modes or maintain an unused second value set.

Components consume purpose-based Semantic and Component size tokens. Canonical
token IDs do not include a density-mode suffix, and product views do not branch
on density. A future mode may map the same semantic roles to different
Primitive values without changing component APIs.

Density is distinct from host DPI, responsive layout, and any future user zoom.
It uses discrete reviewed token values rather than multiplying every visual
measurement by a global factor.

DS007 confirms the single mode and its compact-but-readable objective. Exact
control heights and vertical spacing are finalized with DS009 text metrics,
then validated across the DS008 layout ranges and DS002 display scales.

A future density preference requires demonstrated workflow value, a complete
semantic value map, persistence and migration decisions, and full component
validation. One crowded component does not by itself justify a global mode.

Detailed responsibilities, assignment sequence, and validation rules are
defined in `foundations/density.md`.

### DS008: Use behavior-based responsive layout ranges

Confirmed: 2026-10-12.

Responsive layout uses three behavior ranges: `compact`, `standard`, and
`wide`. These names describe available-width behavior rather than device class,
display DPI, user density, or feature availability.

Page and layout containers own coordinated decisions such as column count,
region order, maximum content width, and persistent action placement. Leaf
components respond to the width they actually receive by wrapping or stacking
their internal content. A component does not assume Wide behavior merely
because its parent page is wide.

Reflow preserves capabilities, critical information, validation state, primary
actions, reading order, and DS004 focus order. It prefers shrinking flexible
regions, wrapping, and stacking before clipping or horizontal scrolling. DS014
defines the detailed policy for structured and long data.

Range entry points use semantic breakpoint tokens and ReaImGui logical
available width under DS002. Product code does not use device labels, physical
pixels, DPI multiplication, or local breakpoint literals. Responsive range does
not switch the DS007 density.

The range model is confirmed, but numeric thresholds are assigned after real
components and representative content are tested around candidate boundaries.
The existing local `560` threshold is audit input rather than a compatibility
requirement.

Detailed behavior, ownership, measurement, reflow, and validation rules are
defined in `foundations/responsive-layout.md`.

### DS009: Use system font families with verified glyph coverage

Confirmed: 2026-10-12.

The first design-system version uses operating-system font matching and does not
bundle a font file. The primary interface family is the generic `sans-serif`
family. A generic system monospace family may be used selectively for
machine-oriented values when fixed character width improves scanning.

System matching means the exact typeface and metrics may vary by platform.
Layouts measure active fonts at runtime and tolerate normal differences; they do
not rely on identical text width across systems. The generic family name does
not guarantee coverage of every language.

The initial semantic text roles are `title`, `heading`, `body`, `label`,
`metadata`, and `code`. Components and product views consume these roles rather
than raw font sizes. The initial weight set is regular and bold; additional
weights require cross-platform font-matching evidence.

Existing `12`, `13`, `14`, and `16` sizes are audit input rather than
compatibility requirements. Final numeric values are calibrated with rendered
content, then used to finalize DS007 control heights and spacing. The type scale
does not rely on the DS003 large-text contrast exception.

Every enabled locale requires verified glyph coverage on every supported host
platform before release. Chinese and other non-Latin support therefore require
an explicit character inventory, mixed-content and layout tests, and a decision
on whether system matching remains reliable. A bundled font may be proposed
later only with a confirmed need plus license, package-size, fallback, and
rendering review.

Required interface icons remain DrawList graphics rather than emoji or special
font glyphs. Detailed roles, coverage gates, layout behavior, and validation are
defined in `foundations/typography.md`.

### DS010: Require static clarity and add motion only for communication

Confirmed: 2026-10-12.

The first design-system version requires no animation. Activity, progress,
state changes, and results remain understandable through persistent text,
component state, and other non-motion cues.

Future motion is permitted only when it materially communicates ongoing
activity, continuity, or a meaningful state change. It is not used for idle
decoration, repeated attention capture, ordinary control polish, or to
compensate for unclear labels and hierarchy.

Initial control states, responsive reflow, menus, notices, and Reviews change
without required transitions. An indeterminate indicator, if later justified,
must accompany descriptive activity text and have an equivalent static state.
Determinate progress represents honest measured progress rather than an
invented animated percentage.

The first version does not expose a Reduced Motion preference because no motion
is required. Every future motion proposal defines its reduced or static
behavior before adoption and follows a reliable host preference when one is
available. Information, focus, reading order, and results remain intact with
motion disabled.

Animation timing uses elapsed monotonic time rather than frame counts and must
not block input, misrepresent completion, or create unnecessary continuous
work. No numeric motion-duration tokens are approved until a confirmed
animation needs them. Feedback lifetime, such as toast visibility, remains a
separate policy.

Detailed purpose, performance, reduced-motion, token, component, and validation
rules are defined in `foundations/motion.md`.

### DS011: Separate Components, Patterns, and Product composition

Confirmed: 2026-10-12.

The shared UI architecture has four one-way responsibility layers:
Foundations, Components, Patterns, and Product. Product may compose Patterns and
Components; Patterns compose Components; Components consume Foundations. Lower
layers do not depend on higher layers.

The initial confirmed Component families are Button, Icon Button, Card, Status,
Notice, Dropdown, Segmented Control, Menu, and Disclosure. A Component owns a
generic interface responsibility, semantic API, states, interaction,
accessibility, internal layout, tokens, and UI events. It does not know product
data or execute domain effects.

Review Shell, Review Header, Review Footer, and Stale Review belong to the
Pattern layer. They coordinate reusable structure and action hierarchy while
receiving product content, state, and effects from Product. ReaProjectLink
cards, Lane Mapping, revision behavior, and Publish, Import, Sync, and
Synchronize workflows remain Product responsibilities.

Typography adapters, measurement, alignment, clipping, icon geometry, style
wrappers, and basic layout calculations are internal infrastructure unless a
later specification promotes them. Reusable code is not automatically a public
Component.

A shared contract requires a repeatable responsibility, generic semantic
boundary, foundation-token compliance, independent state and accessibility
specification, and a confirmed workflow or repeated cross-tool need. Product
exceptions remain local rather than widening a shared API prematurely.

DS011 classifies the current mixed helper module but does not require an
immediate file move, API rename, or production-code change. Detailed
classification, promotion, specification, API, and migration rules are defined
in `components/architecture.md`.

### DS012: Specify only the cross-product essential input inventory

Confirmed: 2026-10-12.

The initial supported input families are Field Shell, Text Field, Integer
Number Field, Path Field, Checkbox, Dropdown, Segmented Control, and Single
Selection List. They are required by confirmed ReaProjectLink and
ReaAssetFlow workflows.

Path Field has File and Folder variants plus editable and read-only selection
modes. Dropdown remains the low-level Component name; its labeled composition
inside Field Shell may be described as a Select Field. Single Selection List is
limited to one active row and does not introduce multi-selection, drag
reordering, or spreadsheet behavior.

Ordered List Editor, Token Insert Group, Path Selection, Preset Manager,
Hierarchy Preview, and External Operation Status are confirmed Pattern
responsibilities rather than primitive inputs. Product code retains domain data,
validation meaning, external effects, persistence, and storage.

Search Field, Radio Group, Switch, multiline text, floating-point and
unit-bearing number input, Slider, date and time input, Color Picker,
drag-and-drop, searchable or multi-select Dropdown, and multi-selection List are
deferred until a confirmed workflow satisfies the DS011 promotion criteria.

Inclusion in the inventory requires a stable specification before migration; it
does not require an immediate rewrite of both products. Detailed responsibilities,
states, product mapping, deferrals, and migration order are defined in
`components/input-inventory.md`.

### DS013: Match destructive safeguards to consequence and scope

Confirmed: 2026-10-12.

Potentially destructive actions use the least disruptive safeguard that makes
their consequence understandable. The system chooses among direct execution, a
focused Confirmation Dialog, and an Inline Review according to recoverability,
scope, surprise, immediacy, complexity, and external effects.

Direct execution is appropriate for low-consequence, unsurprising, reliably
reversible actions and includes result feedback or a real Undo where available.
A Confirmation Dialog serves one isolated material consequence that fits in a
short message. An Inline Review serves multi-target operations, multiple risks
or choices, and workflows requiring preview or correction.

Confirmation Dialogs name the target and consequence and use explicit action
verbs rather than `Yes`, `OK`, or generic `Continue`. The dangerous confirming
action is not the default focus; Cancel is the safe default, Escape and close
cancel where supported, and focus returns to the trigger under DS004.

An Inline Review does not lead to repeated dialogs for consequences it already
made clear. A blocked condition cannot be overridden through confirmation.
Warning, blocked, and danger retain the independent meanings established by
DS005.

Execution prevents duplicate activation and reports running, failed, cancelled,
and partial outcomes without relying on motion or color. Native REAPER or
operating-system message boxes may remain temporary migration fallbacks, but do
not define the shared contract when they cannot provide specific labels or focus
behavior.

Detailed selection factors, anatomy, wording, execution, product mappings, and
validation are defined in `patterns/destructive-confirmation.md`.

### DS014: Reflow structured data before using horizontal scrolling

Confirmed: 2026-10-12.

Structured data uses responsive rows that render as aligned columns when their
documented minimums fit and as labeled stacked details when they do not. The
initial system distinguishes Data List, Responsive Table, Structured Row,
Single Selection List, and Hierarchy Preview responsibilities rather than
introducing a universal spreadsheet-style Grid.

Fields declare `identity`, `decision`, `supporting`, or `technical` priority.
Identity, condition, validation, selection, and the primary next action remain
available at every supported width. Supporting fields stack below the identity;
technical values move into details with a way to inspect or copy the complete
value.

The component derives its column-to-stack transformation from its own available
logical width and declared field minimums, not the global DS008 page range.
Status and validation text wrap without truncation. Long paths use path-aware
truncation only when complete-value access remains available.

Vertical scrolling is the default for long data. Clipping or virtualization is
used only with a compatible row-height contract and never forces variable,
wrapped content into a one-line row. Horizontal scrolling requires a documented
comparison need that cannot be served by reflow and cannot hide core decisions
or recovery actions.

One row-level primary action may remain visible; secondary actions use a Menu.
Selected, focused, hovered, and checked remain distinct states. Selection is
preserved by stable record identity through reflow, sorting, and refresh.

Hierarchy Preview is a Disclosure or Tree Pattern, not a Table variant.
ReaAssetFlow structure preview provides initial evidence, while ReaProjectLink
repeated rows and Reviews provide Data List and Responsive Table evidence.

Detailed priority, transformation, truncation, scrolling, selection, action,
state, hierarchy, cross-product, and validation rules are defined in
`components/structured-data.md`.

### DS015: Use a development-only ReaImGui Component Gallery

Confirmed: 2026-10-12.

The design system uses a standalone development ReaScript running in the real
REAPER and ReaImGui environment as its reference rendering and interaction
Gallery. Specifications remain normative; the Gallery demonstrates whether the
shared implementation conforms in the target host.

The Gallery uses the actual shared adapter, tokens, themes, Components, and
Patterns. It is isolated from production entry points and has no REAPER project,
NAS, storage, WAAPI, network, LLM, publish, sync, import, transfer, delete, or
reset side effects. Actions produce deterministic in-memory demo events.

Permanent sections cover Foundations, every supported Component, confirmed
Patterns, representative ReaProjectLink and ReaAssetFlow compositions, and
validation diagnostics. Fixtures cover themes, relevant widths, supported
states, long content, paths, enabled languages, and loading, empty, failure,
stale, and partial conditions.

The Gallery supports Light and Dark inspection, resizable and fixed logical
widths, state simulation, dialogs, popups, operation outcomes, focus checks, and
an in-memory semantic event log. It does not expose a density selector while
DS007 defines one density.

Temporary prototypes may support exploration but do not become the conformance
reference. A mismatch is resolved through the specification and shared
implementation, not a Gallery-only workaround.

DS015 requires a recorded manual validation matrix. DS016 governs whether stable
screenshot comparison may supplement it. Detailed structure, safety, fixtures,
simulations, conformance, and validation rules are defined in
`governance/component-gallery.md`.

### DS016: Gate the first version with structural tests and manual visual review

Confirmed: 2026-10-12.

The first design-system version uses automated structural and deterministic
behavior checks plus a recorded manual visual and interaction matrix in the
DS015 Gallery. Pixel-based screenshot comparison is not a release gate until a
controlled experiment demonstrates stable capture and acceptable maintenance
cost.

Automated checks cover token structure and references, theme completeness,
declared contrast pairings, scale rules, component states, deterministic events,
invalid property combinations, supported API compatibility, and testable layout
and product-adapter behavior. They do not claim that rendered hierarchy,
wrapping, focus, or typography looks correct.

The manual matrix covers both themes, relevant page and local widths, long and
technical content, applicable component and async states, pointer and keyboard
interaction, available DS002 display scales, and representative ReaProjectLink
and ReaAssetFlow compositions. Each run records implementation and host context
plus every non-pass result.

A future screenshot experiment uses pinned environments, deterministic Gallery
scenes, fixed logical dimensions, and at least five repeated captures before and
after a REAPER restart. Screenshot comparison is adopted only when review shows
that tolerances separate genuine regressions from normal font and rendering
variation, baseline changes are explicitly reviewed, and any new dependency is
approved.

Screenshot comparison supplements rather than replaces structural, contrast,
keyboard, semantic, and manual validation. Detailed release gates, matrix,
record format, experiment, adoption, baseline, and failure rules are defined in
`governance/visual-validation.md`.

### DS017: Version the design-system contract independently

Confirmed: 2026-10-12.

The shared design-system contract has its own semantic `MAJOR.MINOR.PATCH`
version, independent of ReaProjectLink, ReaAssetFlow, and future product
versions. The first usable implementation may begin at `0.1.0`; DS017 defines
policy but does not publish that version.

After `1.0.0`, breaking changes increment MAJOR, backward-compatible additions
increment MINOR, and compatible corrections increment PATCH. Before `1.0.0`, a
breaking contract change increments MINOR and is still documented with a
migration note; pre-1.0 does not permit silent breakage.

Breaking changes include canonical token removal, rename, type or meaning
changes; incompatible Component, Pattern, property, state, default, or event
changes; and behavior changes that require product workflow migration. Visual
corrections may remain compatible when semantic meaning is preserved, but still
require changelog, impact review, and DS016 validation.

Each product declares its target contract, implementation revision, adapter
compatibility, and temporary Product exceptions. Exact versions are the default
before `1.0.0`; compatible ranges require automated conformance evidence.

Deprecations document their replacement, first version, earliest removal
version, known consumers, and migration. After `1.0.0`, removal requires a MAJOR
release and at least one intervening MINOR release. Before `1.0.0`, removal may
occur in a later MINOR. In either case, a contract used by both first-party
products is not removed until ReaProjectLink and ReaAssetFlow have migrated or
an explicit coordinated plan approves the break.

Compatibility aliases remain temporary, live at a defined adapter or migration
boundary, are forbidden in new code, and have a removal version. They do not
become permanent canonical synonyms.

Every published version has a changelog; breaking and deprecating releases have
migration instructions. Distribution must preserve traceable versions,
deterministic upgrades, consumer declarations, and cross-product validation.
Its repository boundary was subsequently confirmed by DS018.

Detailed version categories, breaking-change rules, declarations, deprecation,
aliases, changelog, migration, conformance, and distribution constraints are
defined in `governance/versioning.md`.

### DS018: Place ReaToolUI in the ReaTools monorepo

Confirmed: 2026-10-13.

ReaToolUI is the product-neutral shared package under
`packages/ReaToolUI` in the ReaTools monorepo. Its permanent Lua namespace is
`reaui`. ReaProjectLink and ReaAssetFlow consume the same canonical source and
declare the exact shared contract they use.

Tool releases remain independently versioned and self-contained. Installing or
updating one tool must not silently replace the UI implementation used by
another tool. Repository-level decisions M001 through M005 govern source
ownership, naming, installation direction, and release isolation. Detailed
tradeoffs and the extraction sequence are recorded in
`distribution-options.md`.
