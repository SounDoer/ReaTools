# ReaToolUI visual language and layout system — design

Date: 2026-10-20
Status: Draft for review
Pilot product: ReaProjectLink
Affects: `packages/ReaToolUI`, `tools/ReaProjectLink` presentation layer

## 1. Intent

ReaProjectLink already runs entirely on ReaToolUI (DS021), and its main panel
follows the information architecture in `tools/ReaProjectLink/docs/ui-spec.md`.
The result is functionally correct but visually weak. On the Master main panel
the user identified four problems:

1. Text is too small.
2. Items on the same line are not aligned.
3. Gaps are inconsistent.
4. Separators are used arbitrarily.

The root cause is structural. ReaToolUI owns tokens and individual controls,
but layout is still written by each product view: `master_main.lua` and
`card.lua` call `SameLine`, `Separator`, `NewLine`, and `same_line_right(width)`
directly, with literals such as `8` and `12`. Any new tool will repeat the same
problems.

The goal is to use ReaProjectLink as the case that makes ReaToolUI's visual
language and layout components correct, so future REAPER tools can focus on
their features rather than on alignment, spacing, and typography.

### Success criterion

**First-glance clarity.** On any screen, a user can tell within about two
seconds what state each area is in and which control is the next step.
Everything else recedes. This is the test every rule in this document serves.

## 2. Goals, non-goals, anti-goals

Goals:

- One visual language ("Direction C", section 4) applied to every ReaProjectLink
  surface in Light and Dark themes.
- ReaToolUI provides layout structure, not just controls, so product views can
  not easily produce misalignment or arbitrary gaps.
- A mechanical check proves product views contain no hand-written layout.
- The language is general enough for ReaAssetFlow, verified on paper.

Non-goals:

- No change to ReaProjectLink domain behavior, persisted data, manifests, or
  workflows. The only product-level changes are the five in section 7.
- No ReaAssetFlow code migration in this project.
- No new runtime dependencies, bundled fonts, or icon fonts.
- No pixel-based screenshot comparison as a release gate (DS016 unchanged).

Anti-goals (failure even if everything technically works):

- Product view code still needs `SameLine`, `Separator`, cursor math, or layout
  literals to look right.
- A rule that only makes sense for ReaProjectLink is promoted into the shared
  system.
- Screens get prettier but the next step is less obvious than today.
- The narrow docked window (~320 px) loses capability or becomes cluttered.

## 3. Decisions made in conversation

The user decided:

- Direction C, "status-forward cards", over calibrated cards (A) and flat
  sections (B). Reason given: clearer and simpler at first glance.
- Direction C as shown in three mockup screens is accepted: the Master main
  panel; stress cases (highlighted next step, 320 px narrow, mixed subscription
  states); the Delivery Publish Review in Dark; and the Master main panel in
  Light.
- The five product-level deviations listed in section 7.
- Scope as proposed by the agent (below), delegated by the user.

Agent's calls, accepted by the user as a whole:

- ReaProjectLink is the only product migrated. ReaAssetFlow gets a paper check
  (section 9).
- The work proceeds foundations → shared layout components → enforcement →
  product migration (section 12).

Agent's calls made while writing this document, for the user to check:

- Accent stays DS019 Teal. The mockups' blue is not adopted (4.3).
- Inset blocks use radius 4, not the mockups' 6 (4.4).
- Status prefixes become role glyphs with tooltip labels, keeping DS005
  (4.6, 5.4).
- `Show All` expands in place; the name list stays at narrow widths (5.5,
  section 7).
- Settings follows the Review page layout (section 8).

Mockups: `.superpowers/brainstorm/1646-1792476329/content/`
(`master-direction.html` option C, `direction-c-stress.html`,
`direction-c-review-light.html`). They show layout and hierarchy; their colors
and exact pixel values are not normative (see section 4.3).

## 4. Visual language (Direction C)

### 4.1 Hierarchy

Within a card, information appears in a fixed order of decreasing weight:

1. **Status line**: the most prominent line in the card body.
2. **Key figures**: counts as a Stat Group of large numbers.
3. **Lists**: rows as inset blocks.
4. **Actions**: in the card footer, right-aligned, primary last.

The emphasized card (the single next step, ui-spec 1.2) has the accent border
and owns the view's only primary button. This rule is unchanged.

### 4.2 Typography

System sans-serif through ReaImGui; regular and bold only.

| Role | Size | Weight | Use |
|---|---|---|---|
| title | 20 | bold | Project name, Review title |
| heading | 16 | bold | Card title, Review section title |
| status | 15 | bold | Card status line |
| metric | 22 | bold | Stat number |
| body | 14 | regular | Body text, buttons, list row titles |
| label | 13 | regular | Field labels, footer context text, summaries |
| metadata | 12 | regular | Stat labels, row secondary lines, timestamps |

Changes from current tokens: body 13 → 14; new `status` and `metric` roles.
`label` stays 13, `metadata` stays 12. The narrow window may reduce `title` to
18 (builder decides the threshold).

### 4.3 Color

DS019 remains in force: Radix Slate neutrals with **Teal accent**. The mockups
used the older blue accent from `ui-spec.md` 7.1 for illustration only. That
ui-spec color table is stale and is replaced by a reference to ReaToolUI
tokens (section 10).

Direction C needs one additional semantic surface role: an **inset** surface
for Stat tiles, List Rows, and Review detail groups, one step raised from the
card surface in both themes. Issue Items use the existing warning and blocked
tinted backgrounds with a matching border.

### 4.4 Spacing and shape

Four-unit grid (unchanged). Named values used by the components:

| Use | Value |
|---|---|
| Page padding | 24 (16 when narrow) |
| Header to content | 20 (16 when narrow) |
| Gap between cards | 16 |
| Card body padding | 16 |
| Gap between body blocks (status, stats, list) | 16 |
| Gap between list rows / issue items / stat tiles | 8 |
| Card footer padding | 12 vertical, 16 horizontal |
| Gap between buttons | 8 |
| Review section gap | 24 |
| Control height | 32 (compact row actions 28) |
| Card title row height | 32, regardless of trailing control |
| List row min height | 56 (two-line) |
| Radius: control 4, container 8 | unchanged |

Inset blocks use the control radius (4) unless the Gallery review shows it
reads wrong next to the 8 px card radius. The mockups used 6. This is the
agent's call, made to avoid a new primitive.

### 4.5 Separators

A separator has exactly one legal use: dividing a container's body from its
footer (Card footer, Review footer). No separators between list rows, under
card titles, or between the page header and content. Grouping is expressed
with spacing and inset surfaces. The Dropdown and Menu internal separators for
option groups remain.

### 4.6 Status wording and role cue

The visible `Info:` / `Ready:` / `Attention:` / `Blocked:` text prefixes
(`components.lua` `inline_status`) are removed. Status text itself is
unchanged from ui-spec and names the condition.

DS005 (`foundations/status-and-danger.md`) requires a persistent non-color
cue and accepts an icon. So the plain dot becomes a small **role glyph** drawn
with the existing DrawList icons:

- neutral: dot;
- ready: check;
- warning: warning triangle;
- blocked: cross.

The glyph sits at the size and position the mockups show for the dot. The role
label stays in the Status contract as the glyph's tooltip and accessible label
instead of visible text. This keeps DS005 intact. The `components/status.md`
rule "the role label may be replaced but not removed" is amended to "may be
presented as the glyph's tooltip", which is a contract change recorded in
DS022 (agent's call).

## 5. Shared components and patterns (ReaToolUI)

Each item gets a component document under
`packages/ReaToolUI/docs/design-system/components/` (or `patterns/`), a
Gallery entry covering all states in both themes at narrow and wide widths, and
specs in the existing runner.

### 5.1 Card (revised)

Anatomy, top to bottom:

- **Title row**: icon, title, optional trailing slot (one icon button or menu).
  Fixed height, so cards with and without a trailing control align.
- **Status slot**: optional Status (prominent), with an optional secondary line
  (for example `Synchronized r2`).
- **Body**: caller content composed from shared blocks (Stat Group, List,
  Notice, text).
- **Footer**: optional. Left: context text (label role, muted, for example
  `Selected: 2 Tracks`). Right: actions, primary last. The only separator.

Variants: default, emphasized (next step). Cards in a Card Row are equal
height. The footer sticks to the card bottom.

### 5.2 Card Row (new)

Lays out one or more Cards. At or above 560 px of content width, the cards sit
side by side at equal width and equal height. Below that, they stack. This
replaces `c.card_width()` and the manual `SameLine` between cards.

### 5.3 Stat Group (new)

An equal-width row of tiles: a metric number over a metadata label. Two to four
tiles. Tiles keep their width ratio at narrow widths. Numbers do not wrap.

### 5.4 Status (revised)

Two presentations of the same roles (neutral, ready, warning, blocked):

- prominent: status role typography and role glyph, for card status lines;
- inline: body typography and role glyph, for row trailing status.

Every shared use of Status (cards, list rows, Review footer summary, Notice,
Gallery fixtures) moves to the glyph presentation, so there is one Status look.

Both expose their measured width to the layout so callers never compute it.

### 5.5 List and List Row (new)

A vertical list of inset rows with 8 px gaps and no separators. A row has a
title (body) and an optional secondary line (metadata), plus a trailing slot
for inline Status, at most one action button, and an optional menu. The
trailing slot is right-aligned by the component. When the row is too narrow,
the trailing slot wraps under the title, keeping the order status → action →
menu.

A compact variant (single line, 32 px) serves name lists such as the Source
Reference contents with `Detach...`.

The List also supports:

- optional group labels (metadata role, muted) between runs of rows;
- an optional overflow row: `+ N more ...` with a `Show All` / `Show Less`
  toggle that expands or collapses the list in place.

The List reports the toggle as a semantic event, and the product owns the
expanded state. Expanded lists grow the card. Equal height in a Card Row means
the shorter card stretches, and its footer stays at the bottom.

### 5.6 Action Bar (new layout)

Used by the Card footer, the Review footer, and Issue Items. Context text on
the left, actions on the right, primary last. When the actions do not fit, the
context text takes its own line first. If they still do not fit, the actions
wrap with the primary staying last and right-aligned. Callers pass labels; the
component measures them.

### 5.7 Page Header (new)

Title, optional badge, and a trailing area for metadata text and actions
(`Checked 2 min ago`, `Check Now`, settings). Below a narrow threshold, text
actions with an icon equivalent collapse to icon buttons with tooltips, and
metadata text may hide. Product supplies which actions are collapsible.

### 5.8 Issue Item (revised from the Review issues treatment)

A tinted block (warning or blocked) with a dot, a message (body), an optional
detail line (metadata), and an Action Bar of fix actions.

### 5.9 Review pattern (revised)

Header (back, title, summary line), optional Stat Group summarizing the scope,
sections with heading-role titles (Issues, Decisions, Details), detail groups
as inset disclosure blocks that auto-expand when they contain an issue, and the
fixed footer as an Action Bar. Body capped at the readable max width, as today.

### 5.10 Boundary change against DS021

DS021 kept card composition and key/value rows in the product. This design
moves card anatomy, list rows, stat groups, and action layout into ReaToolUI.
Record this as **DS022** (section 10). Product-specific compositions that stay
local:

- grouped Lane Mapping dropdown;
- virtualized domain lists;
- Settings copy/value rows;
- Toast placement.

All of these must resolve tokens through the adapter.

## 6. Enforcement

A static check, run in the ReaProjectLink validation suite, scans
`ReaProjectLink/lib/reaprojectlink/ui/views/*.lua` and fails on:

- calls to `ImGui.SameLine`, `ImGui.Separator`, `ImGui.NewLine`,
  `ImGui.Dummy`, `ImGui.Indent`, `ImGui.SetCursorPos*`,
  `ImGui.PushStyleVar`, `ImGui.PushStyleColor`;
- numeric literals passed as layout arguments to `c.*` helpers.

`ui/components.lua` remains the product compatibility layer and is exempt, but
every value it uses must come from the adapter. The builder may implement the
scan however fits the existing runner, and may refine the literal rule to avoid
false positives (for example list indices).

The check should be reusable by future tools: a small helper under
`tooling/` or ReaToolUI test utilities, parameterized by path.

## 7. ReaProjectLink product changes (user-approved)

1. Card selection actions are labeled `Register` and `Unregister` instead of
   `Register Selected` and `Unregister Selected`. The muted `Selected: ...`
   footer context provides the scope.
2. The Review issue action `Allow Reference revision difference` is labeled
   `Allow Difference`. The issue message keeps the full explanation.
3. On the Source Reference card, the per-object name list (ui-spec 2.1) shows
   the first N entries in total, in the order Tracks, Markers, Regions, with a
   group label per kind. The rest collapse behind a `+ N more ...` overflow row
   with `Show All`. It expands in place and offers `Show Less`. Each listed name
   keeps its `Detach...`. The list appears at every width, including the
   narrow window. The 320 px mockup omitted it only for brevity. The builder
   chooses N so that the card stays within the first-glance criterion.
4. The Master Deliveries card shows an aggregate status line, for example
   `2 Need Attention` or `All Up to Date`, above the subscription rows.
5. In the narrow window, `Check Now` in the header collapses to a refresh icon
   button with a tooltip.

Record these as a new ReaProjectLink decision (next free number, currently
**D093**) and update `ui-spec.md` sections 1.1, 2.1, 2.3, 2.4, and 4 to match.

## 8. ReaProjectLink migration

Every surface moves onto the section 5 components:

- setup;
- Source and Master main panels;
- Settings;
- the four Reviews (Reference Update, Reference Publish, Delivery Publish,
  Delivery Import/Update);
- banners and Toast.

Settings has no mockup. It follows the Review page layout (agent's call):

- Page Header with a back control;
- the existing groups (Project, Reference, Appearance, About, Reset) as
  heading-role sections, 24 px apart;
- each group's rows inside one inset block.

The copy/value rows stay product-local but align to the same row heights and
label column. `Reset ReaProjectLink State...` keeps its danger treatment.
Visual review round 3 confirms it with the user.

`ui/views/card.lua` and `components.lua` layout helpers (`card_width`,
`same_line_right`, `begin_card`, `card_header`, `inline_status`,
`status_width`, `key_value`, `value_row`) are retired where a shared component
replaces them. View models (`view_models.lua`) gain fields only where the new
anatomy needs them (status secondary line, stat tiles, footer context, list row
secondary line). Highlight priority logic is unchanged.

## 9. ReaAssetFlow paper check

Before a component in section 5 is finalized, read the corresponding
ReaAssetFlow UI in `tools/ReaAssetFlow/ReaAssetFlow.lua` (settings forms,
lists, path fields, action rows) and confirm the component covers it without a
ReaProjectLink-specific assumption. Record the result per component in one
short document,
`packages/ReaToolUI/docs/design-system/validation/2026-10-reaassetflow-paper-check.md`:
covered, covered with note, or product-specific (not promoted).

## 10. Documentation updates

- `packages/ReaToolUI/docs/design-system/decisions.md`: add **DS022**. It
  records Direction C as the visual language, the separator rule, the
  typography roles, the inset surface, and layout ownership moving into
  ReaToolUI (revising the DS021 boundary).
- Foundations docs: typography, spacing-and-sizing, shape, tokens.
- Component and pattern docs for 5.1–5.9; update `README.md` related-documents
  list.
- `tools/ReaProjectLink/docs/decisions.md`: D093 (section 7).
- `tools/ReaProjectLink/docs/ui-spec.md`: sections from section 7; replace 7.1
  to 7.5 with a reference to ReaToolUI tokens and components, keeping only
  product composition.

## 11. Validation

- The complete existing ReaToolUI and ReaProjectLink suites pass.
- New component specs: anatomy, states, wrapping order, equal-height Card Row,
  and title-row height independent of the trailing control.
- UI smoke renders every ReaProjectLink view in both themes at 320 px and
  1040 px, with balanced Begin/End and Push/Pop.
- The enforcement scan (section 6) passes with zero findings in `views/`.
- Repository-level validation required by the ReaToolUI and ReaProjectLink
  boundaries passes.
- **Visual review rounds with the user**: after foundations, after shared
  components (Gallery), and after product migration, capture screenshots of
  the Gallery and each ReaProjectLink view in Dark and Light at narrow and wide
  widths. Show them to the user and iterate until the user accepts. These are
  human evidence, not snapshot oracles (DS016).

## 12. Delivery order

Each step is runnable, tested, and reviewed before the next.

1. Foundations: typography roles, inset surface, spacing names, separator rule
   in tokens and docs. Visual review round 1 in Gallery.
2. Shared components 5.1–5.9 with Gallery entries and specs, including the
   ReaAssetFlow paper check. Visual review round 2.
3. Enforcement scan, initially reporting findings.
4. ReaProjectLink migration: main panels and setup, then Reviews, then
   Settings, banners, and Toast. Product changes from section 7 land here.
   The scan becomes failing once `views/` is clean.
5. Documentation (section 10) and visual review round 3.

## 13. Left to the builder

- Exact token names and the adapter mapping for new roles and the inset surface.
- Narrow thresholds for the header collapse and title size.
- N for the Source Reference name list.
- Scan implementation and its literal-detection heuristics.
- Internal API shape of the new components, consistent with existing
  ReaToolUI component conventions (`draw(options)` returning semantic events).
