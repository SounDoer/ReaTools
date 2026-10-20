# ReaProjectLink Direction C Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move every ReaProjectLink surface onto the Direction C components so
`ui/views/` contains no hand-written layout, land the five approved product
changes, and turn the layout scan into a failing gate.

**Architecture:** Views compose shared ReaToolUI components
(`env.design_system.components` / `.patterns`) and pure view-model output.
`ui/components.lua` stays the product compatibility layer for the parts spec
5.10 keeps local (grouped Lane Mapping dropdown, clipped lists, Toast), with
every value resolved through the adapter. View models gain the fields the new
anatomy needs; highlight priority logic is unchanged.

**Tech Stack:** Lua 5.4, ReaImGui 0.9, ReaToolUI (`reaui`), PowerShell 5.1
validation scripts.

**Spec:** `docs/superpowers/specs/2026-10-20-visual-language-design.md`
(sections 6, 7, 8, 10, 11, 12 step 4–5). Foundations and components plan:
`docs/superpowers/plans/2026-10-20-visual-language-foundations-components.md`.

## Global Constraints

- Code, comments, tests, and docs are English; conversation is Chinese.
- No domain behavior, persisted data, manifest, or workflow change beyond the
  five spec section 7 product changes.
- No new runtime dependencies, bundled fonts, or icon fonts.
- Views (`tools/ReaProjectLink/ReaProjectLink/lib/reaprojectlink/ui/views/*.lua`)
  must end with zero findings from `tooling/check_ui_layout.ps1`.
- `ui/components.lua` is exempt from the scan, but every layout value it uses
  comes from `adapter.resolve`.
- Containers that may end with a child window end with an item (`layout.settle`
  rule in `packages/ReaToolUI/docs/design-system/architecture.md`).
- Commits: Conventional Commits, explicit `git add` paths, one commit per task
  on `main` after its validation passes.
- Do not interact with the user's own REAPER session; stop only REAPER PIDs the
  validation started.

## Review Focus

1. **Narrow window (320 px).** Three footer actions (Register, Unregister,
   Review and Publish) must stack full width with the primary last; nothing may
   scroll horizontally. Pinned by the view specs in Tasks 4 and 5 asserting the
   footer action order, and by the 320 px smoke scenarios.
2. **Show All state across project switches.** The expanded Source Reference
   list must collapse when the project changes or the app resets. Pinned in
   Task 2 (`app_state` reset test).
3. **Primary uniqueness.** With highlight on Deliveries, only the first row
   needing attention gets the primary button; the card footer must not add a
   second primary. Pinned in Task 5 view spec.
4. **Review issue actions keep their effects.** Converting Notices to Issue
   Items changes action identification from index to id; every former action
   must still trigger the same effect (Continue Existing / Start New,
   Publish Without Them..., Publish Anyway..., Publish Unprocessed Media...,
   Select Item, Allow Difference). Pinned by the Task 6 and Task 7 view specs.
5. **Delivery Publish while publishing.** The two-frame publish handshake
   (`publishing` → `publish_ready`) must survive the Review Shell conversion.
   Pinned by the existing `delivery_publish_running` smoke scenario plus a Task 6
   spec assertion that the footer is disabled with label `Publishing...`.

---

### Task 1: ReaToolUI prerequisites (refresh icon, input height, toast width)

Small shared changes the migration needs.

**Files:**
- Modify: `packages/ReaToolUI/lib/reaui/icons.lua`
- Modify: `packages/ReaToolUI/lib/reaui/design_input_control.lua`
- Modify: `packages/ReaToolUI/lib/reaui/design_tokens.lua`
- Modify: `packages/ReaToolUI/gallery/design_system_gallery.lua` (Page Header
  fixture uses `refresh`)
- Modify: `packages/ReaToolUI/docs/design-system/foundations/` icon list (where
  `M.NAMES` is documented), `components/text-field.md`,
  `patterns/path-selection.md`
- Test: `packages/ReaToolUI/tests/` icon spec (find the spec that asserts
  `icons.NAMES`), the input control or text field spec, the token spec

**Interfaces:**
- Produces: icon name `"refresh"` in `icons.NAMES`; token
  `semantic.layout.toast.max_width` (520 logical units); text inputs whose
  frame height equals `semantic.size.control.medium`.

- [ ] **Step 1: Write failing tests**
  - `icons_include_refresh`: `"refresh"` is in `icons.NAMES`, and
    `icons.draw(ImGui, dl, "refresh", 0, 0, 16, color)` returns `true` and
    calls `DrawList_PathArcTo` once and `DrawList_PathStroke` once, plus at
    least one `DrawList_AddLine` for the arrowhead.
  - `input_frame_height_matches_control_height`: with body font size 14 and
    `semantic.size.control.medium` 32, the input control pushes
    `StyleVar_FramePadding` with y = 9 around the `InputText*` call and pops it
    (push count equals pop count).
  - Token spec: `semantic.layout.toast.max_width` resolves to 520.
- [ ] **Step 2: Run** `powershell -NoProfile -ExecutionPolicy Bypass -File packages\ReaToolUI\tests\run_validation.ps1` and confirm the three new tests fail.
- [ ] **Step 3: Implement.**
  - `refresh`: a 270° arc (`DrawList_PathArcTo` centered, radius `0.32 * size`,
    then `DrawList_PathStroke` with the existing thickness) and a two-segment
    arrowhead at the arc end.
  - Input control: frame padding y = `(control.medium - GetFontSize) / 2`, x
    unchanged (read it with `GetStyleVar`).
  - Token: add the primitive size for 520 if the scale lacks one.
- [ ] **Step 4: Run** the ReaToolUI validation. Expected: `Core: PASS` and `Gallery: PASS ... (30 scenarios)`. Then probe the Patterns section with `.superpowers/review/probe_gallery.ps1 -Section Patterns` (no script error dialog).
- [ ] **Step 5: Commit** `feat(ui): add refresh icon and align input height with controls`.

### Task 2: View models and app state for the new anatomy

Pure functions only; nothing here calls ImGui.

**Files:**
- Modify: `tools/ReaProjectLink/ReaProjectLink/lib/reaprojectlink/ui/view_models.lua`
- Modify: `tools/ReaProjectLink/ReaProjectLink/lib/reaprojectlink/ui/app_state.lua`
- Test: `tools/ReaProjectLink/tests/ui_view_models_spec.lua`, `tools/ReaProjectLink/tests/ui_app_state_spec.lua`

**Interfaces:**
- Produces (all in `view_models`):
  - Card models keep `state`, `status`, `level`, `note`, `action`,
    `attention`, `selection_note`, `selection_actions`, and replace `rows` with
    `stats = { { label, value }, ... }` (value is a number) and
    `status_detail` (string or nil).
  - `SELECTION_ACTIONS` labels become `Register` and `Unregister` (ids unchanged).
  - `M.card_footer(card, highlighted) -> { context = string|nil, actions = { {id,label,variant?}, ... } } | nil`:
    selection actions (secondary) first, then `card.action` with
    `variant = "primary"` when `highlighted`. Returns `nil` when there are no
    actions and no context.
  - `M.deliveries_status(rows) -> { role, text }` for a non-empty row list:
    any row `state == "checking"` and none needing attention →
    `{ "neutral", "Checking..." }`; n rows with `attention` →
    `"1 Needs Attention"` / `"%d Need Attention"`, role `blocked` when any of
    them has level `blocked`, otherwise `warning`; otherwise
    `{ "ready", "All Up to Date" }`.
  - `M.REFERENCE_NAME_LIMIT = 5`.
  - `M.reference_name_list(surface, expanded) -> items, overflow, lookup`:
    `items` is a List item array in the order Tracks, Markers, Regions, each
    kind preceded by `{ kind = "group", label = "Tracks" | "Markers" | "Regions" }`
    and only when that kind has visible names; rows are
    `{ kind = "row", id = "track-1", title = <name or "Unnamed Track">, action = { id = "detach", label = "Detach..." } }`.
    Collapsed shows the first `REFERENCE_NAME_LIMIT` names in total.
    `overflow` is `nil` when the total ≤ limit, else
    `{ label = "+ %d more", expanded = false }` collapsed or
    `{ label = "Showing all %d", expanded = true }` expanded.
    `lookup[row id]` is the existing detach action table
    (`{ id = "detach_track", ref, name, kind = "Track" }` or
    `{ id = "detach_entry", entry_id, kind, name }`).
- Produces (`app_state`): field `reference_names_expanded` (boolean, default
  `false`), cleared by `app:reset()`.

- [ ] **Step 1: Write failing tests** in `ui_view_models_spec.lua`:
  - Update existing label assertions to `Register` / `Unregister`.
  - `source_reference_moves_revision_to_status_detail`: newer state with
    synchronized 2 → `status_detail == "Synchronized r2"`, `stats` labels
    `Tracks, Markers, Regions`; current → `status_detail == "Reference r2"`;
    unsubscribed → `status_detail == nil` and `stats == nil`.
  - `source_delivery_stats`: `stats` = Tracks 3, Items 12.
  - `master_reference_stats`: Tracks/Markers/Regions numbers.
  - `card_footer_orders_primary_last`: highlighted Master Reference published →
    actions `register_selected, unregister_selected, review_publish`, last has
    `variant == "primary"`, context `"Selected: 2 Tracks"`; not highlighted →
    no `variant` on any action.
  - `deliveries_status_aggregates`: two warning rows → `"2 Need Attention"`,
    `warning`; one blocked + one warning → `blocked`; one current + one
    checking → `Checking...`; all current → `All Up to Date`, `ready`.
  - `reference_name_list_collapses_after_limit`: 4 tracks, 2 markers, 1 region,
    collapsed → items `group Tracks, 4 rows, group Markers, 1 row`, overflow
    label `+ 2 more`; expanded → all 7 rows with three groups, overflow label
    `Showing all 7`; 3 names total → overflow `nil`; `lookup["marker-1"].id == "detach_entry"`.
  - In `ui_app_state_spec.lua`: `reset_collapses_reference_names`.
- [ ] **Step 2: Run** `powershell -NoProfile -ExecutionPolicy Bypass -File tools\ReaProjectLink\tests\run_validation.ps1` and confirm the new tests fail.
- [ ] **Step 3: Implement** the interfaces above. Keep `rows` out of the models; Task 3–5 views are the only consumers.
- [ ] **Step 4: Run** the ReaProjectLink validation. Unit tests pass; the smoke may fail because views still read `rows`. If it does, keep `card.lua` drawing `stats` as value rows temporarily (one-line adapter in `card.lua`), so this task commits green.
- [ ] **Step 5: Commit** `feat(reaprojectlink): add Direction C view model fields`.

### Task 3: Header, banners, and setup

**Files:**
- Modify: `.../ui/views/header.lua`, `.../ui/views/setup.lua`, `.../ui/workflow.lua`, `.../ui/components.lua`
- Test: create `tools/ReaProjectLink/tests/ui_views_spec.lua` (fake env pattern of `ui_settings_spec.lua`); register it in `tools/ReaProjectLink/tests/specs.lua`

**Interfaces:**
- Produces: `c.block_gap()` in `components.lua`: moves the cursor so the next
  item starts `semantic.space.block.gap` below the previous one (replace item
  spacing, the same conversion the shared components use).
- Produces: a fake env builder `fake_view_env(overrides)` local to
  `ui_views_spec.lua` that records the options passed to
  `components.page_header`, `card_row`, `card`, `list`, `notice`,
  `stat_group`, `issue_item`, `patterns.review_shell`, and returns scripted
  results. Tasks 4–7 extend it.

- [ ] **Step 1: Write failing tests** in `ui_views_spec.lua`:
  - `header_uses_page_header`: `page_header` receives `title` = project name,
    `badge = "Master"`, `meta` = `"All Up to Date  ·  Checked just now"` style
    text, actions `{ check: label "Check Now", icon "refresh" }` and
    `{ settings: icon "gear", icon_only = true }`; action `"check"` calls
    `app:request_check()`, action `"settings"` calls `app:open_settings()`.
  - `notices_are_followed_by_block_gap`: unsaved state draws the `unsaved`
    Notice and then calls `c.block_gap` once.
  - `setup_uses_card_row`: `card_row` receives two cards with ids
    `setup-source` / `setup-master`, icons `upload` / `download`, the existing
    descriptions, and footers with one action each (`Initialize Source Project`,
    `Initialize Master Project`, both secondary); `page_header` receives title
    `Set Up ReaProjectLink` and summary `Choose the type for this project.`;
    action on `setup-master` calls `initialize_master`.
- [ ] **Step 2: Run** the ReaProjectLink validation; the new spec fails.
- [ ] **Step 3: Implement.** Header draws one `page_header` (id `main-header`)
  and then `workflow.draw_notices`. Setup keeps `c.begin_page` / `c.end_page`.
  Remove `ImGui.Separator`, `SameLine`, and `Dummy` from these files.
- [ ] **Step 4: Run** the validation. Expected `Core: PASS ...` and `Product UI: PASS ReaProjectLink UI frames (52 scenarios)`. Run `tooling\check_ui_layout.ps1 -Report -Path tools\ReaProjectLink\ReaProjectLink\lib\reaprojectlink\ui\views`; header and setup report zero findings.
- [ ] **Step 5: Commit** `feat(reaprojectlink): move header and setup onto shared layout`.

### Task 4: Source main panel

**Files:**
- Modify: `.../ui/views/source_main.lua`
- Test: `tools/ReaProjectLink/tests/ui_views_spec.lua`

**Interfaces:**
- Consumes: Task 2 view-model fields; `c.small` for notes.
- Card options per card: `{ id, icon, title, variant = highlighted and "emphasized" or nil, status = { role = level, text = status, detail = status_detail }, footer = view_models.card_footer(card, highlighted) }`; body renders `stat_group` when `stats` exist (ids `source-reference-stats`, `source-delivery-stats`), then the note, then for the Reference card the name List.

- [ ] **Step 1: Write failing tests:**
  - `source_cards_use_card_row`: `card_row` receives `source-reference` and
    `source-delivery`; the highlighted one has `variant = "emphasized"`; the
    Delivery footer actions are `Register, Unregister, Review and Publish` with
    the last primary when highlighted, and its context is the selection text.
  - `source_reference_names_list`: with synchronized 2 and 8 names, the body
    calls `list.draw` with `variant = "compact"`, 5 rows, and overflow
    `+ 3 more`; a scripted `overflow_toggled` result sets
    `app.reference_names_expanded = true`; a scripted row action
    `{ row = "track-1", id = "detach" }` requests the Detach Reference Track
    confirmation.
  - `source_reference_without_sync_has_no_list`: synchronized 0 → no
    `list.draw` call.
- [ ] **Step 2: Run** the validation; the tests fail.
- [ ] **Step 3: Implement.** Body results are captured by closure, since
  Card Row returns only card actions. Map a footer action id to the existing
  `handle(env, action)` path; map list actions through `lookup`.
- [ ] **Step 4: Run** the validation (52 scenarios pass) and the layout report (source_main zero findings).
- [ ] **Step 5: Commit** `feat(reaprojectlink): compose Source main from shared cards`.

### Task 5: Master main panel

**Files:**
- Modify: `.../ui/views/master_main.lua`
- Test: `tools/ReaProjectLink/tests/ui_views_spec.lua`

**Interfaces:**
- Consumes: `view_models.deliveries_status`, `card_footer`, `stats`.
- Reference card: as in Task 4 (`master-reference`, `film`).
- Deliveries card: `{ id = "master-deliveries", icon = "download", title = "Deliveries", trailing = { kind = "icon_button", id = "add", icon = "plus", accessible_label = "Add Delivery" } }`.
  With rows: `status = deliveries_status(rows)` and a standard List whose rows
  are `{ id = row.id, title = row.name, detail = row.note, status = { role = row.level, text = row.status }, action = row.action and { id, label, variant = primary and "primary" or nil }, menu = { accessible_label = "Subscription actions", items = ROW_MENU } }`.
  With no rows: `status` from `deliveries_empty`, the note as body text, and
  `footer = { actions = { { id = "add_delivery", label = "Add Delivery", variant = highlighted and "primary" or nil } } }`.

- [ ] **Step 1: Write failing tests:**
  - `master_deliveries_rows_use_list`: three rows (newer, current, unmapped),
    highlight on deliveries → only row 1 action has `variant = "primary"`; the
    card has no footer; status text `2 Need Attention`.
  - `master_deliveries_actions_route`: card action `add` opens import; list
    action `{ row = <id>, id = "sync" }` opens update for that row; menu id
    `remove` requests the Remove Subscription confirmation.
  - `master_deliveries_empty_state`: no rows → footer action `Add Delivery`
    primary when highlighted.
- [ ] **Step 2: Run** the validation; the tests fail.
- [ ] **Step 3: Implement**, removing `draw_row`, `draw_deliveries` layout code, and the `marker_error` note handling stays (note on the Reference card).
- [ ] **Step 4: Run** the validation and layout report (master_main zero findings).
- [ ] **Step 5: Commit** `feat(reaprojectlink): compose Master main from shared cards`.

### Task 6: Reference Update, Reference Publish, and Delivery Publish Reviews

**Files:**
- Modify: `.../ui/views/reference_update_review.lua`, `.../ui/views/reference_publish_review.lua`, `.../ui/views/delivery_publish_review.lua`, `.../ui/workflow.lua`
- Test: `tools/ReaProjectLink/tests/ui_views_spec.lua`

**Interfaces:**
- Produces: `workflow.review_flags(result) -> { back, complete, refresh }`
  reading Review Shell events `review.back_requested`,
  `review.complete_requested`, `review.refresh_requested`.
- Each Review draws one `patterns.review_shell.draw({ id, header = { title, summary }, footer = { summary, role, complete_label, enabled }, stale = stale and { title = "Review Out of Date", message = ..., refresh_label = "Refresh Review" } or nil, render_body })`.
- Body order: Stat Group scope (Reference Publish: Tracks/Markers/Regions;
  Delivery Publish: Tracks/Items; Reference Update: none), section `Issues`
  with `issue_item.draw_list` (omitted when empty), Decisions sections
  (`Decision`, `Checked Against Reference`), Details section
  (`Contents` / `Items`) with inset Disclosures
  (`variant = "inset"`, `detail` = count text, `role` = `blocked` when the
  group has blockers).
- Issue ids and action ids (effects unchanged):
  - `save-as`: actions `continue` / `new` → `options.save_as_decision`.
  - `removed`: `publish-without` → existing confirmation.
  - `unchanged`: `publish-anyway` → existing confirmation.
  - `unprocessed-fx`: `publish-unprocessed` → existing confirmation.
  - `clip-<lane>-<i>-<j>`: `select-item` → `adapter.select_items`.
  - Accepted states (`removed-accepted`, `unprocessed-fx-accepted`) become
    warning Issue Items without actions.
- `workflow.draw_notices(env)` stays above the shell (banners).

- [ ] **Step 1: Write failing tests:**
  - `reference_publish_issues_route_by_id`: scripted `draw_list` action
    `{ item = "save-as", id = "new" }` sets `save_as_decision = "new"` and
    refreshes; `{ item = "unchanged", id = "publish-anyway" }` requests the
    Publish Unchanged Reference confirmation.
  - `delivery_publish_running_footer`: `review.publishing = true` → footer
    `complete_label == "Publishing..."`, `enabled == false`, summary
    `Publishing Delivery...`.
  - `delivery_publish_select_item`: action `select-item` on a clip issue calls
    `adapter.select_items({ item_ref })`.
  - `reference_update_shift_decision`: when `can_shift_entire_project`, a
    section `Decision` contains the checkbox; footer label `Synchronize`.
  - `stale_review_passes_stale`: stale data → `review_shell` gets `stale` and
    refresh flag triggers `refresh`.
- [ ] **Step 2: Run** the validation; the tests fail.
- [ ] **Step 3: Implement.** The Delivery Publish details keep `c.clipped`
  inside the Disclosure body (virtualized list stays product-local).
- [ ] **Step 4: Run** the validation (all 52 smoke scenarios, including `delivery_publish_running`) and the layout report (these three files zero findings).
- [ ] **Step 5: Commit** `feat(reaprojectlink): move publish and update reviews onto Review Shell`.

### Task 7: Delivery Import and Update Reviews

**Files:**
- Modify: `.../ui/views/delivery_sync_review.lua`, `.../ui/components.lua`
- Test: `tools/ReaProjectLink/tests/ui_views_spec.lua`

**Interfaces:**
- Produces: `c.mapping_row(id, title, detail, draw_control)` in
  `components.lua`: an inset row (`component.list_row.background`, control
  radius, `semantic.space.inset.*` padding) with the title (body) and detail
  (metadata, secondary) on the left and `draw_control()` filling the right
  part. Rows are separated by `semantic.space.list.gap`. Below
  `semantic.size.field.inline_wide` of available width the control moves under
  the text at full width. Returns `draw_control()`'s result. All values come
  from the adapter.
- Lane rows: `c.mapping_row("lane-" .. lane_id, lane.display_name, count text, function() return c.dropdown(...) end)`; orphaned note and row errors render under the row as warning text through existing `c.colored` / `c.small`.
- Parent choice: `segmented_control.draw_field({ id = "parent", label = "New tracks go under", ... })`; `Use Current Selection` stays a secondary button below `Under <track>` text.
- Target revision: `number_field.draw` then a `Load` button on its own line via `action_bar.draw({ id = "target", context = "Latest is r%d", actions = { { id = "load", label = "Load" } } })`.
- Reference warning issue: action `{ id = "allow", label = "Allow Difference" }` (spec section 7 item 2); the accepted state text stays `Made against a different Reference revision. Continuing anyway.`

- [ ] **Step 1: Write failing tests:**
  - `import_reference_warning_allows_difference`: issue action
    `{ item = "reference-warning", id = "allow" }` sets
    `review.allow_reference = true`; the action label is `Allow Difference`.
  - `mapping_row_routes_dropdown_choice`: a scripted dropdown choice
    `{ id = "unmapped" }` sets `review.mappings[lane_id].kind == "unmapped"`.
  - `update_load_reopens_review`: action bar `load` calls `open_update` with
    the typed target.
- [ ] **Step 2: Run** the validation; the tests fail.
- [ ] **Step 3: Implement**, removing every `Separator`, `SameLine`, and
  `AlignTextToFramePadding` from the view.
- [ ] **Step 4: Run** the validation and the layout report (delivery_sync_review zero findings).
- [ ] **Step 5: Commit** `feat(reaprojectlink): move delivery sync reviews onto shared layout`.

### Task 8: Settings in the Review layout

**Files:**
- Modify: `.../ui/views/settings.lua`, `.../ui/components.lua` (drop `create_settings_compat`), `.../ui/app.lua` (drop `settings_compat`)
- Test: `tools/ReaProjectLink/tests/ui_settings_spec.lua`

**Interfaces:**
- Layout: `c.begin_page("settings", false)`; `page_header.draw({ id = "settings", title = "Settings", back_label = "Back" })`; groups Project, Reference (Source only), Appearance, About, Reset through `section_heading.draw` (first one `gap_above = false`).
- Project and About rows use one standard List per group: rows
  `{ id, title = <label>, detail = <value> }`; Project rows add
  `action = { id = "copy", label = "Copy" }`, which calls
  `ImGui.SetClipboardText(ctx, value)`.
- Reference keeps `path_selection` and the alignment checkbox; Appearance keeps
  the segmented field; Reset keeps the explanation (via `c.small`) and the
  danger button.

- [ ] **Step 1: Update tests** in `ui_settings_spec.lua`: replace the compat
  fakes with `page_header`, `section_heading`, and `list` fakes;
  `copies[4].value == "delivery-1"` becomes "the Project List's fourth row has
  detail `delivery-1` and a Copy action"; add
  `copy_action_writes_clipboard` (scripted list action `{ row = "project-id", id = "copy" }` calls `SetClipboardText` with the project ID). Keep the
  reset and back tests unchanged in intent.
- [ ] **Step 2: Run** the validation; the updated tests fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the validation (settings smoke scenarios pass) and the layout report (settings zero findings).
- [ ] **Step 5: Commit** `feat(reaprojectlink): lay out Settings with shared sections and lists`.

### Task 9: Retire compatibility helpers and enforce the scan

**Files:**
- Delete: `.../ui/views/card.lua`; `.../ui/icons.lua` if no longer required
- Modify: `.../ui/components.lua`, `tools/ReaProjectLink/tests/ui_modules_spec.lua`, `tools/ReaProjectLink/tests/run_validation.ps1`, `tooling/run_all_tests.ps1`

**Interfaces:**
- `components.lua` keeps only helpers that views still call. Remove
  `card_width`, `same_line_right`, `begin_card`, `end_card`, `card_header`,
  `inline_status`, `status_width`, `key_value`, `value_row`, `copy_value`,
  `section`, `badge`, `icon`, `review_header`, `footer`, `stale`, `begin_group`,
  `end_group`, and the constants they used (`VALUE_COLUMN`, `STACK_BELOW`,
  `CARD_FLAGS`, `LEVEL_LABEL`) once unused.
- Toast width uses `semantic.layout.toast.max_width`.
- ReaProjectLink validation gains a third step: `check_ui_layout.ps1 -Path <views>` without `-Report`, reported as `Layout: PASS ui layout (n files)`.
- `run_all_tests.ps1` step `ReaProjectLink layout report` becomes `ReaProjectLink layout scan` without `-Report`.

- [ ] **Step 1:** Run `rg -n "c\.(card_width|same_line_right|begin_card|card_header|inline_status|status_width|key_value|value_row|badge)\(" tools/ReaProjectLink` and confirm zero matches before deleting.
- [ ] **Step 2:** Delete and trim; update `ui_modules_spec.lua` module list.
- [ ] **Step 3: Run** the ReaProjectLink validation. Expected three lines: `Core: PASS ...`, `Product UI: PASS ReaProjectLink UI frames (52 scenarios)`, `Layout: PASS ui layout (9 files)` (count after deleting `card.lua`).
- [ ] **Step 4: Run** `tooling\run_all_tests.ps1`. Expected: everything passes except the two known local PowerShell 5.1 failures (release inventories and ReaPack, `[IO.Path]::GetRelativePath`).
- [ ] **Step 5: Commit** `refactor(reaprojectlink): retire layout helpers and enforce layout scan`.

### Task 10: Documentation

**Files:**
- Modify: `tools/ReaProjectLink/docs/decisions.md` (add D093),
  `tools/ReaProjectLink/docs/ui-spec.md` (1.1, 2, 2.1, 2.3, 2.4, 4, 5; replace
  7.1–7.5 with a reference to ReaToolUI tokens and components, keeping only
  product composition), `tools/ReaProjectLink/docs/architecture.md` and
  `tools/ReaProjectLink/docs/validation.md` wherever they name `card.lua`,
  `Register Selected`, or retired helpers, `tools/ReaProjectLink/CHANGELOG.md`
  (Unreleased).

- [ ] **Step 1:** D093 records the five spec section 7 changes plus N = 5 and the Settings List rows.
- [ ] **Step 2:** `rg -n "Register Selected|Unregister Selected|Allow Reference revision|card\.lua|same_line_right" tools/ReaProjectLink/docs tools/ReaProjectLink/ReaProjectLink` returns only historical plan/spec files.
- [ ] **Step 3: Run** `tooling\run_all_tests.ps1` (documentation checks included).
- [ ] **Step 4: Commit** `docs(reaprojectlink): record Direction C product changes (D093)`.

### Task 11: Visual review round 3

**Files:**
- Modify: `tools/ReaProjectLink/tests/run_ui_smoke.lua`
- Dev-only (gitignored): `.superpowers/review/capture_reaprojectlink.ps1`

**Interfaces:**
- `run_ui_smoke.lua`: when `REAPROJECTLINK_UI_CAPTURE=<n>` is set, the
  scenario list is scenario `n` repeated 600 times, so the window holds that
  view long enough to capture. Validation behavior is unchanged when the
  variable is unset.

- [ ] **Step 1:** Add the capture hook; run the ReaProjectLink validation (unchanged result).
- [ ] **Step 2:** Capture all 13 views in Light and Dark at 320 and 1040 (52 images) into `.superpowers/review/round-3/` with a visible window, following `capture_gallery.ps1`.
- [ ] **Step 3:** Inspect every image; fix layout defects in a follow-up commit per defect.
- [ ] **Step 4:** Open the folder for the user, ask for acceptance, and iterate until accepted.
- [ ] **Step 5: Commit** the hook: `test(reaprojectlink): hold one smoke scenario for captures`.

## Decisions confirmed by the user (2026-10-20)

1. **`Allow Difference` placement.** Spec section 7 item 2 renames
   `Allow Reference revision difference`, but the code button today reads
   `Import Anyway` / `Sync Anyway` (Delivery Import and Update Reviews). The
   plan renames those buttons to `Allow Difference`.
2. **Settings rows.** Spec section 8 keeps copy/value rows product-local in one
   inset block per group. The plan uses the shared List instead (one inset row
   per value, `Copy` as the row action), which removes the last product layout
   code. The visual difference is separate rows instead of one shared block.
3. **Header status.** Round 2 decided not to add a Page Header status slot, so
   `All Up to Date` stays in the header meta text as today, and the Deliveries
   card also shows it as its status line.
