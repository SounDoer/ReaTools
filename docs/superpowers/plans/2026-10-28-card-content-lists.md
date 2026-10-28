# Card Content Lists Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ReaProjectLink cards list what is registered and what is selected by
name, grouped by kind in collapsible counted groups, on top of three shared
ReaToolUI changes.

**Architecture:** ReaToolUI gains Card `sections`, collapsible counted List
groups with row `trailing_text`, and a one-line Status detail; the Selection
Strip and List overflow go away. ReaProjectLink services return selected
Tracks with their registered flag, pure view models turn names into List
items, and views compose them into Card sections with in-memory collapse
state.

**Tech Stack:** Lua 5.4, ReaImGui 0.9, REAPER-hosted test runners.

**Spec:** `docs/superpowers/specs/2026-10-28-card-content-lists-design.md`

## Global Constraints

- Code, identifiers, comments, docs: English. Copy is exact as below.
- Implementations resolve only semantic/component tokens (conformance tests
  forbid primitive tokens).
- ReaImGui: call `EndChild` only when `BeginChild` returned true.
- No new runtime dependencies; no persisted data changes.
- Copy: `Registered`, `Synchronized`, `Selected`, `Nothing registered`,
  `Nothing synchronized`, `Nothing selected`, `Registered` /
  `Not Registered` row tags, `Register`, `Unregister`, nouns `Track`,
  `Marker`, `Region`, `Item` (plural adds `s`).
- Group order Tracks, Markers, Regions; zero-entry kinds have no group.
- Commit after each task with Conventional Commits; never push.

## Review Focus

- Very long names in a 320 px card: rows wrap, trailing tag moves below
  (existing List behavior) — covered by the existing List wrap test; add a
  `trailing_text` case in Task 2.
- A collapsed group followed by another group: only the collapsed group's
  rows are hidden — Task 2 `collapsed_group_hides_only_its_rows`.
- Invalid Marker/Region registry on Master: no Markers/Regions groups and no
  empty texts — Task 5 `master_sections_hide_kinds_when_registry_is_invalid`.
- Project change: collapse state resets — Task 5
  `reset_expands_every_group`.
- Selection with only registered entries: `Register` disabled, `Unregister`
  enabled — Task 4 `selection_actions_disable_what_would_do_nothing`.

---

### Task 1: Status detail on the status line

**Files:**
- Modify: `packages/ReaToolUI/lib/reaui/design_status.lua`
- Test: `packages/ReaToolUI/tests/ui_design_status_spec.lua`
- Docs: `packages/ReaToolUI/docs/design-system/components/status.md`

**Interfaces:** Produces no new API; `status.draw({ ..., detail })` changes
placement only.

- [ ] **Step 1: Write failing tests** `detail_follows_text_on_one_line_when_it_fits`
  (wide region: detail drawn with `SameLine` spacing
  `semantic.space.inline.default`, in `metadata` role and
  `semantic.color.text.secondary`, its y = status text y + status line height
  − metadata line height) and `detail_wraps_below_when_it_does_not_fit`
  (narrow region: detail y > status text y, x = text x).
- [ ] **Step 2: Run** `powershell -File packages/ReaToolUI/tests/run_validation.ps1`; expect the two new tests to fail.
- [ ] **Step 3: Implement.** Inside the group, after the status text: if the
  text took one line and `CalcTextSize(text) + inline gap + CalcTextSize(detail)`
  (detail measured in `metadata`) fits `GetContentRegionAvail` measured
  before drawing the text, `SameLine(0, gap)` then bottom-align the detail;
  otherwise draw it below as today.
- [ ] **Step 4: Run** the validation script; expect PASS.
- [ ] **Step 5:** Update `status.md` (detail placement rule). Commit
  `feat(ui): keep status detail on the status line`.

### Task 2: List groups collapse and count; rows get trailing text

**Files:**
- Modify: `packages/ReaToolUI/lib/reaui/design_list.lua`
- Modify: `packages/ReaToolUI/gallery/design_system_gallery.lua` (List fixture around line 296–330: drop `overflow`, show two collapsible groups with counts and one `trailing_text` row; keep scenario count at 30)
- Test: `packages/ReaToolUI/tests/ui_design_list_spec.lua`
- Docs: `packages/ReaToolUI/docs/design-system/components/list.md`, `README.md` line ~260 (drop "overflow toggle")

**Interfaces — Produces:**
- Group item: `{ kind = "group", id = string?, label = string, count = integer?, collapsible = boolean?, collapsed = boolean? }`. `collapsible` requires `id`.
- Row item gains `trailing_text = string?` (drawn first among trailing parts).
- Result: `{ events, action, toggled_group = string|nil }`; event `{ type = "list.group_toggled", id = <list id>, group = <group id> }`.
- Removed: `options.overflow`, `overflow_toggled`, `list.overflow_toggled`.

- [ ] **Step 1: Write failing tests:**
  - `group_header_shows_count_then_noun_in_body`: group `{ id="tracks", label="Tracks", count=3, collapsible=true }` → texts `"3"` (role `body`, color `semantic.color.text.primary`) then `"Tracks"` (role `body`, color `semantic.color.text.secondary`) on the same y.
  - `collapsed_group_hides_only_its_rows`: items group A (collapsed) + 2 rows + group B + 1 row → exactly 1 row child drawn.
  - `toggling_a_group_reports_it`: fake tree node returns the opposite of the requested open state → `result.toggled_group == "tracks"`, event as above.
  - `trailing_text_sits_beside_the_title`: row `trailing_text = "2 Items"` → text in `metadata`, right edge at content edge.
  - `collapsible_group_requires_id`: validation error.
  - Replace `group_labels_render_between_rows` role expectation `metadata` → `body`; delete `overflow_toggle_label_and_event`; drop the `overflow_toggled` assertion in the empty-list test.
- [ ] **Step 2: Run** validation; expect the new tests to fail.
- [ ] **Step 3: Implement.** Collapsible header: `SetNextItemOpen(ctx, not collapsed, Cond_Always)` then `TreeNodeEx(ctx, "##group-" .. list_id .. "-" .. id, "", SpanAvailWidth | NoTreePushOnOpen)` with the arrow in the secondary text color; `toggled` when the return differs from `not collapsed`. Then `SameLine` count and noun (the noun follows after one space width). Non-collapsible groups draw count (if any) and label the same way without the tree node. Skip rows until the next group while the current group is collapsed. `trailing_text` is a new trailing part measured with `text_width("metadata", …)`, vertically centered like status.
- [ ] **Step 4: Run** validation; expect PASS and `PASS Design System Gallery matrix (30 scenarios)`.
- [ ] **Step 5:** Update `list.md` (Groups section: count, collapse, caller-owned state; trailing text; remove overflow). Commit `feat(ui): add collapsible counted list groups`.

### Task 3: Card sections replace the selection strip

**Files:**
- Modify: `packages/ReaToolUI/lib/reaui/design_card.lua`
- Delete: `packages/ReaToolUI/lib/reaui/design_selection_strip.lua`, `packages/ReaToolUI/tests/ui_design_selection_strip_spec.lua`
- Modify: `packages/ReaToolUI/tests/specs.lua`, `packages/ReaToolUI/tests/ui_modules_spec.lua` (unregister the strip)
- Modify: `packages/ReaToolUI/lib/reaui/design_tokens.lua` (remove both `component.card.selection` blocks, lines ~326 and ~837)
- Modify: `packages/ReaToolUI/gallery/design_system_gallery.lua` (fixtures at ~248, ~256, ~936, ~993, ~999: use `sections`)
- Test: `packages/ReaToolUI/tests/ui_design_card_spec.lua`
- Docs: `components/card.md`, `decisions.md` (DS024)

**Interfaces — Produces:** `card.draw({ ..., sections = { { id = string, heading = string, render = function() -> action|nil } } }, render_body)`. Each section is drawn after the body: block gap, `Separator`, `semantic.space.footer.padding_y`, `section_heading.draw({ id = <card id> .. "-" .. id, title = heading, gap_above = false })`, then `render()`; a non-nil return goes through `choose` (so it lands in `result.action` and Card Row `actions[card id]`). `options.selection` is removed (validation rejects it with an error naming `sections`). Card takes a `section_heading` dep.

- [ ] **Step 1: Write failing tests** (replace the two selection tests and the `selection_strip` fake with a `section_heading` fake recording `{ title, gap_above, y }`):
  - `sections_follow_the_body_each_behind_a_separator`: two sections → 2 separators; first separator y = body bottom + 16; heading y = separator y + 12; headings `gap_above == false`; renders called in order.
  - `section_action_surfaces_as_card_action`: render returns `"register_selected"` → `result.action` and `events[1].action` equal it.
  - `pinned_footer_leaves_sections_with_the_content`: with `min_height = 400` section heading y unchanged; 3 separators; footer separator at `400 - 16 - 40`.
  - `rejects_selection_option`.
- [ ] **Step 2: Run** validation; expect failures.
- [ ] **Step 3: Implement** in `draw_contents`, replacing the `options.selection` block; validate each section's `id`/`heading` strings and `render` function.
- [ ] **Step 4: Run** validation; expect PASS, gallery 30 scenarios.
- [ ] **Step 5: Docs.** `card.md` anatomy: item 5 becomes Sections; a card has one separator per section plus the footer separator. `decisions.md`: add `### DS024: Cards list their content in sections` (sections, counted collapsible List groups without overflow, one-line status detail; supersedes DS023's `selection`; amends DS022's separator rule). Mark DS023 superseded by DS024 in its heading line. Commit `feat(ui): replace card selection with sections`.

### Task 4: Services and view models for names

**Files:**
- Modify: `tools/ReaProjectLink/ReaProjectLink/lib/reaprojectlink/project_service.lua` (replace `selection_counts`)
- Modify: `tools/ReaProjectLink/ReaProjectLink/lib/reaprojectlink/reference_publish.lua` (replace `service.selection_counts`)
- Modify: `tools/ReaProjectLink/ReaProjectLink/lib/reaprojectlink/ui/view_models.lua`
- Test: `tests/project_service_spec.lua`, `tests/reference_publish_spec.lua`, `tests/ui_view_models_spec.lua`

**Interfaces — Produces:**
- `project_service.selected_tracks(adapter) -> { { display_name = string, registered = boolean } }` (registered = non-empty `get_track_lane_id`).
- `reference_publish.selected_tracks(adapter) -> same shape` (registered = non-empty `get_track_reference_lane_id`).
- `view_models.registered_items(entries) -> items`, where `entries = { tracks = { { name, item_count? } }?, markers = { { name } }?, regions = { { name } }? }`. A kind that is `nil` or empty gets no group. Group: `{ kind="group", id=<key>, label=<plural noun>, count=#rows, collapsible=true }`; when the kind's entries carry `item_count`, label is `"Tracks · " .. view_models.count(total, "Item")` (the count helper: `count(5,"Item") == "5 Items"`). Rows: `{ kind="row", id=<key>.."-"..index, title=<name or fallback>, trailing_text = item_count and view_models.count(item_count, "Item") }`. Fallbacks `Unnamed Track` / `Unnamed Marker` / `Unnamed Region`. Group label uses the singular noun when `count == 1` (`1 Track`, `1 Track · 2 Items`).
- `view_models.selected_items(entries) -> items`, entries carry `{ name, registered }`; rows get `status = { role = "ready", text = "Registered" }` or `{ role = "neutral", text = "Not Registered" }`.
- `view_models.selection_actions(entries) -> { { id="register_selected", label="Register", disabled=bool }, { id="unregister_selected", label="Unregister", disabled=bool } }`: Register disabled when no entry has `registered == false`; Unregister disabled when none has `registered == true`.
- `view_models.reference_name_list(surface) -> items, lookup` (no `expanded`, no overflow; groups as above with Detach rows; lookup unchanged).
- Removed: `M.selection`, `SELECTION_LABELS`, `SELECTION_ACTIONS`, `count_stats`, every card model's `stats` and `selection`, `M.REFERENCE_NAME_LIMIT`.

- [ ] **Step 1: Write failing tests:** `selected_tracks_report_registration` (both services: two selected tracks, one with a lane id → `registered` true/false, names from `track_name`); `registered_items_group_by_kind_with_counts` (2 tracks, 0 markers, 1 region → items: group tracks count 2, 2 rows, group regions count 1 label `Regions`, 1 row; no markers group); `delivery_tracks_show_item_counts` (rows `trailing_text "2 Items"`, `"1 Item"`; group label `Tracks · 3 Items`); `selected_items_tag_registration`; `selection_actions_disable_what_would_do_nothing` (all registered → Register disabled, Unregister enabled; none → reversed; empty → both disabled); `reference_name_list_lists_every_name` (7 names → 7 rows, no overflow return). Update/remove the old `selection_*`, stats and overflow assertions (`ui_view_models_spec.lua` ~151, ~235, ~416–479; `project_service_spec.lua` ~124; `reference_publish_spec.lua` ~255).
- [ ] **Step 2: Run** `powershell -File tools/ReaProjectLink/tests/run_validation.ps1`; expect core failures for the new tests.
- [ ] **Step 3: Implement** the interfaces above.
- [ ] **Step 4: Run** validation; core PASS (UI smoke may fail until Task 5 — acceptable only if the failure is in `views/`).
- [ ] **Step 5: Commit** `feat(reaprojectlink): build registered and selected lists`.

### Task 5: Card views, collapse state, docs

**Files:**
- Modify: `ui/views/card.lua`, `ui/views/source_main.lua`, `ui/views/master_main.lua`, `ui/app_state.lua`, `ui/components.lua`, `ui/app.lua` (~216)
- Test: `tests/ui_views_spec.lua`, `tests/ui_app_state_spec.lua`, `tests/ui_smoke_scenarios.lua`
- Docs: `tools/ReaProjectLink/docs/decisions.md` (D093 amendment), `tools/ReaProjectLink/docs/ui-spec.md` (§2, §2.1, §2.2)

**Interfaces — Consumes:** Task 3 `sections`, Task 2 group fields/`toggled_group`, Task 4 services and view models.
**Produces:**
- `app.collapsed_groups = {}` set in `app:reset()` (replaces `reference_names_expanded`); key `<list id> .. "/" .. <group id>`.
- `c.muted(text)`: body role, secondary color, wrapped.
- `card.section(env, list_id, spec) -> { id, heading, render }`, `spec = { id, heading, items, lookup?, empty?, actions? }`. `render`: copy `collapsed` from `app.collapsed_groups` onto group items, `list.draw({ id = list_id, variant = "compact", items })` when items exist, flip the toggled key, return `lookup[row]` for a row action; else `c.muted(spec.empty)` when `empty`; then `action_bar.draw({ id = list_id .. "-actions", actions })` when `actions`, returning its action.
- `card.options(model, id, icon, title, highlighted, sections)`; `card.body` no longer draws stats.

Card composition (list ids `<card id>-registered` / `<card id>-selected`):
- Source Reference, `synchronized > 0` only: `{ id="synchronized", heading="Synchronized", items, lookup = reference_name_list(surface), empty="Nothing synchronized" }`. The detach action returns through Card Row actions; `handle` already routes tables to `handle_detach` (drop `draw_reference_names` and the `detach` local).
- Source Delivery: registered from `delivery_tracks` (`display_name`, `item_count`) with `empty="Nothing registered"`; selected from `project_service.selected_tracks` with `empty="Nothing selected"` and `selection_actions`.
- Master Reference: registered tracks from `reference_tracks` (names only), markers/regions from `timeline_entries` with `registered`; selected tracks from `reference_publish.selected_tracks`, markers/regions with `selected`. When `timeline_entries` returned an error, pass `markers`/`regions` as `nil` and omit both `empty` texts.

- [ ] **Step 1: Write failing tests.** Make `fake_view_env`'s `card_row` call each `entry.options.sections[i].render()` after `render_body` and record `calls.lists[id]`; add `action_bar` to the recorder keys; add `selected_tracks` fakes to both services. Tests:
  - `source_cards_use_sections`: delivery sections ids `registered`, `selected`; headings `Registered`, `Selected`; Selected actions `Register`/`Unregister`; reference has one section `Synchronized`; delivery footer still one `Review and Publish` primary; `reference.status.detail == "Reference r2"`.
  - `source_reference_lists_every_name`: 6 tracks + 2 markers → 8 rows, no `overflow`; a scripted `detach` row action requests `detach-reference-track` confirmation.
  - `source_reference_without_sync_has_no_sections`.
  - `group_toggle_flips_collapse_state`: scripted list result `toggled_group = "tracks"` → `env.app.collapsed_groups["source-delivery-registered/tracks"] == true`, next draw passes `collapsed = true`.
  - `empty_sections_show_muted_text`: no lanes, no selection → order contains `muted:Nothing registered` and `muted:Nothing selected`.
  - `master_sections_hide_kinds_when_registry_is_invalid`: `timeline_entries` returns `nil, "bad"` → no markers/regions groups, no `muted:` entries, note `bad` shown.
  - `ui_app_state_spec`: `reset_expands_every_group` replaces the `reference_names_expanded` test.
  - Update `source_cards_use_card_row` / `source_reference_names_list` / `source_reference_without_sync_has_no_list` accordingly.
- [ ] **Step 2: Run** validation; expect failures.
- [ ] **Step 3: Implement** per the interfaces. Smoke scenarios: replace `selection_counts` overrides with `selected_tracks` (Source: `{ { display_name = "SFX_Impacts", registered = true }, { display_name = "Room Tone", registered = false } }`; Master: two tracks one registered), give Master `reference_tracks` names and `timeline_entries` names plus one selected marker, and replace the `reference_names_expanded = true` scenario with one seeding a collapsed group via a new `collapsed_groups` scenario field applied in `app.lua` (keeps the scenario count).
- [ ] **Step 4: Run** validation; expect Core, Product UI and Layout PASS.
- [ ] **Step 5: Docs.** `decisions.md`: append a D093 Amendment (2026-10-28) replacing item 3 (5 names + Show All) with collapsible per-kind groups, recording names in Registered/Selected sections, disabled Register/Unregister rules, removed stat tiles. `ui-spec.md` §2/§2.1/§2.2 to match. Commit `feat(reaprojectlink): list registered and selected content by name`.

### Task 6: Repository validation

- [ ] Run `powershell -File packages/ReaToolUI/tests/run_validation.ps1`, `powershell -File tools/ReaProjectLink/tests/run_validation.ps1`, `powershell -File tooling/check_ui_layout.ps1`, `powershell -File tooling/test_check_ui_layout.ps1`, and the ReaAssetFlow smoke / pytest steps from `tooling/run_all_tests.ps1` (the release step needs PowerShell 7 and is skipped on this machine; say so in the report).
- [ ] `rg "selection_strip|component\.card\.selection|overflow_toggled|reference_names_expanded|REFERENCE_NAME_LIMIT|selection_counts"` over `packages tools` returns nothing outside docs history.
- [ ] Stop the brainstorm server (`.superpowers/brainstorm/1478-1793153563/state/server.pid`).
