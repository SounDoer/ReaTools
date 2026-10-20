# ReaToolUI Visual Language: Foundations and Shared Components Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give ReaToolUI the Direction C foundations, layout components, and
Gallery fixtures, plus a reusable layout scan, so ReaProjectLink can migrate
onto them in a follow-up plan.

**Architecture:** Foundations change first: tokens, typography roles, and the
adapter font list. An internal `design_layout` utility owns measurement and
right alignment. New public Components (Action Bar, Card Row, Stat Group,
List, Issue Item, Page Header) and revised Card, Status, Disclosure, and
Review patterns are built on it. Each one is registered in the contract
catalog with a spec document and a Gallery fixture. A PowerShell scan enforces
"no hand-written layout" for product views. This plan stops at visual review
round 2. The ReaProjectLink migration (spec sections 7, 8, and step 4) is a
separate plan written after the review.

**Tech Stack:** Lua 5.4 on ReaImGui 0.9 (REAPER), PowerShell 7 for tooling.

**Spec:** `docs/superpowers/specs/2026-10-20-visual-language-design.md`

## Global Constraints

- No new runtime dependencies, bundled fonts, or icon fonts.
- No change to ReaProjectLink domain behavior. ReaProjectLink must still pass
  `tools/ReaProjectLink/tests/run_validation.ps1` after every task.
- Shared code consumes only Semantic or Component tokens: no `"primitive.`
  strings and no `0x` color literals in `lib/reaui/design_*.lua` (enforced by
  `ui_design_conformance_spec.lua`).
- Every public catalog entry needs a spec document starting with `# ` and a
  Gallery fixture marker string (enforced by the same spec).
- Gallery batch result must stay exactly
  `PASS Design System Gallery matrix (30 scenarios)`. Add fixtures inside
  existing sections only.
- Code, comments, docs: English. Commits: Conventional Commits with scope
  `ui` or `tooling`, and only after the user has approved committing for this
  execution (repository `AGENTS.md`).
- Separator rule (spec 4.5): shared components draw `ImGui.Separator` only
  between a container body and its footer (Card footer, Review footer) and
  inside Menu and Dropdown option groups.
- Accent stays DS019 Teal. Do not introduce blue.

## Review Focus

1. **Card Row height ratchet.** When a card's content shrinks (for example
   `Show Less`), equal-height cards must shrink on the next frame, not keep the
   old maximum. Test in Task 5.
2. **Long text at 320 px.** List row titles, card titles, and status text
   longer than the width wrap. Trailing controls move below instead of
   overflowing horizontally. Test in Task 7.
3. **Oversized action.** A single action label wider than the available width
   gets its own row and does not loop or push other actions off-screen. Test
   in Task 3.
4. **Disabled actions.** Disabled actions in Action Bar, List rows, and Card
   footers never emit events. Test in Task 3.
5. **Empty content.** A List with zero items and a Card with no status, body,
   or footer render without error and emit no events. Tests in Tasks 4 and 7.

---

## Shared conventions for all tasks

- Specs live in `packages/ReaToolUI/tests/`, use fake `ImGui` tables like
  `ui_design_card_spec.lua`, end with the standard runner footer (`local
  passed=0; for name,test in pairs(tests) ... return passed`), and are
  appended to `packages/ReaToolUI/tests/specs.lua`. Every new `lib/reaui`
  module is also added to the module list in `tests/ui_modules_spec.lua`.
- Run all ReaToolUI checks:
  `pwsh -File packages/ReaToolUI/tests/run_validation.ps1`
  Expected: `Core: PASS <n> ReaToolUI tests` and
  `Gallery: PASS Design System Gallery matrix (30 scenarios)`.
- Run ReaProjectLink regression: `pwsh -File tools/ReaProjectLink/tests/run_validation.ps1`
  Expected: every line starts with `PASS` / the script exits 0.
- A new public item means four edits:
  1. a `design_contract.lua` `CATALOG` entry with `id`, `name`, `module`,
     `factory_key`, `spec`, and `fixture`;
  2. a spec document under `packages/ReaToolUI/docs/design-system/`;
  3. a Gallery fixture containing the `fixture` string;
  4. a line in the design-system `README.md` related-documents list.
- Components return `{ events = {...}, ... }`. Event tables are
  `{ type = "<component>.<verb>", id = <component id>, ... }`.

---

### Task 1: Foundations — tokens, typography roles, decision DS022

**Files:**
- Modify: `packages/ReaToolUI/lib/reaui/design_tokens.lua`
- Modify: `packages/ReaToolUI/lib/reaui/design_adapter.lua:19` (font role list)
- Modify: `packages/ReaToolUI/lib/reaui/design_button.lua:48` (`"label"` → `"body"`)
- Modify: `packages/ReaToolUI/tests/ui_design_tokens_spec.lua`, `ui_design_adapter_spec.lua`
- Modify docs: `docs/design-system/decisions.md` (add DS022), `foundations/typography.md`, `foundations/spacing-and-sizing.md`, `foundations/shape.md`, `foundations/tokens.md`

**Interfaces:**
- Produces these token ids (all later tasks use them):

| Id | Resolves to |
|---|---|
| `primitive.font_size.135` | 15 |
| `primitive.font_size.175` | 22 |
| `primitive.size.14` | 56 |
| `primitive.color.radix_amber_light.3` / `.6` | `0xfff7c2ff` / `0xf3d673ff` |
| `primitive.color.radix_amber_dark.3` / `.6` | `0x302008ff` / `0x5c3d05ff` |
| `primitive.color.radix_red_light.3` / `.6` | `0xfeebecff` / `0xfdbdbeff` |
| `primitive.color.radix_red_dark.3` / `.6` | `0x3b1219ff` / `0x72232dff` |
| `semantic.typography.body.font_size` | 14 (was 13) |
| `semantic.typography.status.*` | system, 15, bold |
| `semantic.typography.metric.*` | system, 22, bold |
| `semantic.color.surface.inset` | light `slate_light.2`, dark `slate_dark.3` |
| `semantic.color.tint.warning.background` / `.border` | amber 3 / amber 6 per theme |
| `semantic.color.tint.blocked.background` / `.border` | red 3 / red 6 per theme |
| `semantic.space.block.gap` | 16 |
| `semantic.space.list.gap` | 8 |
| `semantic.space.inset.padding_x` / `.padding_y` | 12 / 8 |
| `semantic.space.footer.padding_x` / `.padding_y` | 16 / 12 |
| `semantic.space.page.padding_compact` | 16 |
| `semantic.space.header.gap_below` / `.gap_below_compact` | 20 / 16 |
| `semantic.size.row.single` / `.double` / `.compact` | 40 / 56 / 32 |
| `semantic.size.control.compact` | 28 |
| `semantic.layout.card_row.stack_below` | 560 |
| `semantic.layout.page_header.collapse_below` | 560 |

- Produces adapter typography roles: `title, heading, status, metric, body, label, metadata, code`.

- [ ] **Step 1: Write failing token tests** in `ui_design_tokens_spec.lua`:

```lua
function tests.direction_c_foundation_values()
  local expect = {
    ["semantic.typography.body.font_size"]=14, ["semantic.typography.status.font_size"]=15,
    ["semantic.typography.metric.font_size"]=22, ["semantic.typography.status.font_weight"]="bold",
    ["semantic.typography.metric.font_weight"]="bold", ["semantic.space.block.gap"]=16,
    ["semantic.space.list.gap"]=8, ["semantic.space.inset.padding_x"]=12, ["semantic.space.inset.padding_y"]=8,
    ["semantic.space.footer.padding_x"]=16, ["semantic.space.footer.padding_y"]=12,
    ["semantic.space.page.padding_compact"]=16, ["semantic.space.header.gap_below"]=20,
    ["semantic.space.header.gap_below_compact"]=16, ["semantic.size.row.single"]=40,
    ["semantic.size.row.double"]=56, ["semantic.size.row.compact"]=32, ["semantic.size.control.compact"]=28,
    ["semantic.layout.card_row.stack_below"]=560, ["semantic.layout.page_header.collapse_below"]=560,
  }
  for _, theme in ipairs({"light","dark"}) do
    for id, value in pairs(expect) do equal(tokens.resolve(id, theme), value, theme.." "..id) end
    for _, id in ipairs({"semantic.color.surface.inset","semantic.color.tint.warning.background",
        "semantic.color.tint.warning.border","semantic.color.tint.blocked.background","semantic.color.tint.blocked.border"}) do
      assert(math.type(tokens.resolve(id, theme)) == "integer", theme.." "..id)
    end
  end
  equal(tokens.resolve("semantic.color.tint.warning.background","dark"), 0x302008ff, "dark amber 3")
  equal(#tokens.validate(), 0, "registry valid")
end
```

  In `ui_design_adapter_spec.lua`, assert that `CreateFont` is called for exactly the eight roles above, and that `push_text("status")` and `push_text("metric")` succeed.

- [ ] **Step 2: Run** `pwsh -File packages/ReaToolUI/tests/run_validation.ps1`. Expected: FAIL, `unknown token semantic.typography.status.font_size`.
- [ ] **Step 3: Implement** the tokens in the table, add `"status"` and `"metric"` to the adapter role list, and switch Button text from `"label"` to `"body"` (spec 4.2: buttons are 14). Update any Button spec assertion that checked the `label` role.
- [ ] **Step 4: Run both validations.** Expected: ReaToolUI PASS, Gallery 30 scenarios, ReaProjectLink PASS.
- [ ] **Step 5: Docs.** Add DS022 to `decisions.md` (Confirmed: 2026-10-20). It records:
  - Direction C;
  - typography roles (spec 4.2);
  - the inset surface and tint roles;
  - the separator rule (4.5);
  - status glyphs replacing visible prefixes with the role label kept as tooltip (4.6), amending `components/status.md`;
  - layout ownership moving into ReaToolUI and revising the DS021 product boundary for card composition, key/value-style rows, and action layout (5.10).

  Update the four foundations docs with the new values.
- [ ] **Step 6: Visual review round 1.** Open the Gallery with `packages/ReaToolUI/gallery/open_gallery.ps1` as described in `docs/design-system/manual-validation-runbook.md`. Capture the Foundations and Components sections in Light and Dark at Compact and Wide previews (8 images) into `.superpowers/review/round-1/`. Show them to the user and stop until the user accepts the type scale and colors.
- [ ] **Step 7: Commit** `feat(ui): calibrate Direction C foundations`.

---

### Task 2: Internal layout utility and Status glyphs

**Files:**
- Create: `packages/ReaToolUI/lib/reaui/design_layout.lua` (internal utility, not in catalog)
- Modify: `packages/ReaToolUI/lib/reaui/design_status.lua`
- Create: `packages/ReaToolUI/tests/ui_design_layout_spec.lua`
- Modify: `packages/ReaToolUI/tests/ui_design_status_spec.lua` (replace the prefix test)
- Modify: `docs/design-system/components/status.md`, Gallery Status fixture

**Interfaces:**
- Produces `design_layout.create(ImGui, ctx, adapter) -> layout` with:
  - `layout.button_width(label: string) -> number`: `body` text width plus `2 * semantic.space.control.padding_x`.
  - `layout.icon_button_width() -> number`: `semantic.size.control.medium`.
  - `layout.trailing(width: number) -> boolean`: called right after a left item. It does `SameLine`, and if `width` fits in the remaining region it moves the cursor so the item ends at the right content edge and returns `false`. Otherwise it starts a new line, right-aligns there, and returns `true` (wrapped).
  - `layout.gap() -> number`: `semantic.space.control.gap` (8).
- Produces `status.draw({ role, text, presentation = "inline"|"prominent", detail?, role_label? }) -> nil` and `status.measure({ role, text, presentation }) -> number` (single-line width).

Status rendering details:

- The glyph is drawn with `reaui.icons`: neutral `dot`, ready `check`, warning `warning`, blocked `cross`. It is sized to the current text line height and colored `component.status.<role>.foreground`.
- After the glyph, a `semantic.space.inline.default` gap, then the text in the same color. Prominent uses the `status` font; inline uses `body`.
- `detail` renders on the next line in `metadata` font with secondary color, indented to the text start.
- Hovering the glyph shows `role_label or ROLES[role]` as a tooltip.

- [ ] **Step 1: Write failing tests.**

```lua
-- ui_design_layout_spec.lua
function tests.trailing_right_aligns_when_it_fits()   -- avail 300 after SameLine, width 100
  -- expect SetCursorPosX(cursor_x + 200) and return false
end
function tests.trailing_wraps_when_it_does_not_fit()  -- avail 80, width 100
  -- expect NewLine called, return true, then right-aligned on the new line
end
function tests.button_width_uses_body_font_and_padding() -- CalcTextSize 50, padding_x 12 -> 74
end

-- ui_design_status_spec.lua
function tests.glyph_replaces_visible_prefix()
  for role, icon in pairs({neutral="dot",ready="check",warning="warning",blocked="cross"}) do
    -- draw({role=role,text="Example"}): drawn icon name == icon, rendered text == "Example" (no "Info:" etc.)
  end
end
function tests.role_label_is_tooltip()   -- IsItemHovered true -> SetTooltip("Note") when role_label="Note"; default "Attention" for warning
function tests.prominent_uses_status_font_and_detail_uses_metadata()
function tests.measure_is_glyph_gap_and_text()        -- line height 16, gap 8, text 100 -> 124
```

- [ ] **Step 2: Run** ReaToolUI validation. Expected: FAIL on the missing `design_layout` module and the old prefix text.
- [ ] **Step 3: Implement** `design_layout.lua` and the Status changes. Keep the existing errors for unknown role and empty text. Inject the icon renderer the same way `design_button` does (`create(ImGui, ctx, adapter, icon_renderer)`).
- [ ] **Step 4: Run both validations.** Expected: PASS. ReaProjectLink still passes because `c.status` delegates to `shared.status.draw`. Its own `inline_status` prefix stays until the migration plan.
- [ ] **Step 5: Docs.** Rewrite the role-cue section of `components/status.md`: glyph table, tooltip label, prominent and inline presentations. Update the Gallery Status fixture to show both presentations and a `detail`.
- [ ] **Step 6: Commit** `feat(ui): add layout utility and status glyphs`.

---

### Task 3: Action Bar component

**Files:**
- Create: `packages/ReaToolUI/lib/reaui/design_action_bar.lua`
- Create: `packages/ReaToolUI/tests/ui_design_action_bar_spec.lua`
- Create: `docs/design-system/components/action-bar.md`
- Modify: `design_contract.lua` (entry `{ id="action_bar", name="Action Bar", module="design_action_bar", factory_key="action_bar", spec="components/action-bar.md", fixture="Action Bar" }`), Gallery Components section, README

**Interfaces:**
- Consumes: `design_layout`, `design_button`.
- Produces `action_bar.draw({ id, context?: string, actions: { {id, label, variant?, disabled?} } }) -> { events, action: string|nil }`. Each event is `{ type="action_bar.activated", id=<bar id>, action=<action id> }`.

Rules:

- Errors when `actions` is empty and `context` is nil.
- Errors when more than one action has `variant == "primary"`.
- Errors when a primary action is not last.
- `context` renders in the `label` font with secondary color.

Layout algorithm (spec 5.6):

1. `total` = the sum of `button_width` values plus gaps.
2. If `context` is set and `context_width + gap + total <= avail`, the context goes left (`AlignTextToFramePadding`) and the actions go on the same line via `layout.trailing(total)`.
3. Otherwise, the context gets its own line (`TextWrapped`). The actions then pack greedily in order into rows no wider than `avail`, and each row is right-aligned. An action wider than `avail` occupies its own row, drawn at its natural width.

- [ ] **Step 1: Write failing tests:**
  - `context_and_actions_share_a_line_when_they_fit`
  - `context_moves_above_when_actions_do_not_fit`
  - `actions_wrap_greedily_with_each_row_right_aligned`: three 100-wide actions, avail 230, gap 8. Expect rows `[1,2]` and `[3]`.
  - `oversized_action_gets_its_own_row`: Review Focus 3. A 400-wide label at avail 300 is placed alone, every action is drawn exactly once, and the call terminates.
  - `disabled_action_never_emits`: Review Focus 4.
  - `rejects_primary_not_last_and_two_primaries`
  - `emits_activated_event_with_action_id`
- [ ] **Step 2: Run.** Expected: FAIL, module missing.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run both validations.** Expected: PASS.
- [ ] **Step 5: Doc and Gallery fixture.** Show the cases: context plus three actions; the wrapped narrow state; and a disabled primary.
- [ ] **Step 6: Commit** `feat(ui): add action bar`.

---

### Task 4: Card anatomy revision

**Files:**
- Modify: `packages/ReaToolUI/lib/reaui/design_card.lua`
- Modify: `packages/ReaToolUI/tests/ui_design_card_spec.lua`
- Modify: `docs/design-system/components/card.md`; Gallery Card fixture and the cross-product scenario call (gallery line ~856), which use the old return value

**Interfaces:**
- Consumes: `design_layout`, `design_status`, `design_button` (`draw_icon`), `design_menu`, `design_action_bar`.
- Produces `card.draw(options, render_body?) -> { events, action: string|nil, body_result, natural_height: number }`.

Options:

- `id`, `title?`, `icon?` (an icon name from `reaui.icons`), `description?` (kept);
- `trailing?`: either `{ kind="icon_button", id, icon, accessible_label }` or `{ kind="menu", id, accessible_label, items }`;
- `status?`: `{ role, text, detail? }`, rendered with `presentation="prominent"`;
- `footer?`: `{ context?, actions }`, passed to Action Bar;
- `variant`: `"default"` or `"emphasized"`;
- `width?`, `min_height?`.

`action` is the trailing button id, the chosen menu item id, or the footer action id. **Breaking:** the return value was `body_result`.

Algorithm (equal height and pinned footer):

- The card stores `natural[id]` from the previous frame.
- First frame (no stored value and no `min_height`): draw with `ChildFlags_AutoResizeY` exactly as today.
- Later frames: `BeginChild` with `height = max(natural[id], min_height or 0)` and no auto-resize.
- Inside the child, draw in order:
  1. the title row, with fixed height `semantic.size.control.medium`; the trailing control goes through `layout.trailing`;
  2. the status;
  3. `render_body`, with `semantic.space.block.gap` between these three blocks.
- Record `body_end = GetCursorPosY()`.
- If there is a footer, `SetCursorPosY(max(body_end, height - footer_h_prev - padding))`, then draw the separator. Draw the Action Bar padded by the `semantic.space.footer.*` tokens, and measure `footer_h` for the next frame.
- `natural[id] = body_end + footer_h + padding`. This is measured independently of `min_height`, so content that shrinks reduces it on the next frame.

- [ ] **Step 1: Update and add tests:**
  - `title_row_height_is_fixed_with_or_without_trailing`
  - `footer_is_pinned_to_bottom_when_min_height_exceeds_content`
  - `natural_height_ignores_min_height`
  - `trailing_menu_and_footer_actions_surface_as_action`
  - `empty_card_renders_without_events`: Review Focus 5.

  Keep the existing balance, emphasis, failure-closing, and invalid-input tests, adapted to the new return table.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.** Update the Gallery callers to read `result.body_result` where they used the old return value.
- [ ] **Step 4: Run both validations.** Expected: PASS. ReaProjectLink uses its own `begin_card`, so it is unaffected.
- [ ] **Step 5: Doc and Gallery.** Update `card.md` anatomy (spec 5.1). Gallery shows default and emphasized cards, a card with a trailing icon, one with a trailing menu, one with status detail, and one with a footer.
- [ ] **Step 6: Commit** `feat(ui)!: give card a title row, status slot, and footer`.

---

### Task 5: Card Row component

**Files:**
- Create: `packages/ReaToolUI/lib/reaui/design_card_row.lua`, `tests/ui_design_card_row_spec.lua`, `docs/design-system/components/card-row.md`
- Modify: catalog (`{ id="card_row", name="Card Row", module="design_card_row", factory_key="card_row", spec="components/card-row.md", fixture="Card Row" }`), Gallery, README

**Interfaces:**
- Consumes: `card.draw` (Task 4) and its `natural_height`.
- Produces `card_row.draw({ id, cards = { { options = <card options>, render_body = fn? } } }) -> { events, actions = { [card_id] = action }, stacked: boolean }`.

Behavior:

- `stacked = avail < semantic.layout.card_row.stack_below`.
- Side by side: width per card is `(avail - gap * (n - 1)) / n`, with gap `semantic.space.block.gap`. `SameLine` goes between cards with that gap.
- Each card gets `min_height = row_max[id]`, where `row_max[id]` is recomputed every frame as the max of the cards' `natural_height` from this frame. It is stored for the next frame, never carried as a running max.
- Stacked: full width, no `min_height`, and the block gap between cards.

- [ ] **Step 1: Write failing tests:**
  - `side_by_side_at_or_above_560`
  - `stacked_below_560`
  - `equal_height_uses_previous_frame_max`
  - `height_shrinks_when_content_shrinks`: Review Focus 1. Naturals are 300/200, then 180/200; expect `min_height` 300, then 200.
  - `actions_are_keyed_by_card_id`
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run both validations.** Expected: PASS.
- [ ] **Step 5: Doc and Gallery.** The fixture has two cards of different content height, viewed at Compact and Wide previews.
- [ ] **Step 6: Commit** `feat(ui): add card row`.

---

### Task 6: Stat Group component

**Files:**
- Create: `packages/ReaToolUI/lib/reaui/design_stat_group.lua`, `tests/ui_design_stat_group_spec.lua`, `docs/design-system/components/stat-group.md`
- Modify: catalog (`{ id="stat_group", name="Stat Group", module="design_stat_group", factory_key="stat_group", spec="components/stat-group.md", fixture="Stat Group" }`), tokens (`component.stat_group.background` → `semantic.color.surface.inset`, `component.stat_group.label` → `semantic.color.text.secondary`), Gallery, README

**Interfaces:**
- Produces `stat_group.draw({ id, stats = { { label: string, value: string|number } } }) -> { events = {} }`. It errors unless `2 <= #stats <= 4`.

Layout:

- Tile width is `(avail - list_gap * (n - 1)) / n`.
- Tile height is `metric line height + metadata line height + 2 * inset.padding_y`.
- The background is drawn with `DrawList_AddRectFilled` using radius `semantic.radius.control`.
- The value uses the `metric` font and the label uses the `metadata` font, both inset by `inset.padding_x` and `inset.padding_y`.
- One `Dummy(avail, tile_height)` reserves the row.
- Values never wrap. A value wider than its tile is clipped with `PushClipRect`.

- [ ] **Step 1: Write failing tests:**
  - `tiles_share_width_equally`: avail 300, gap 8, three tiles; expect widths ≈ 94.67.
  - `uses_metric_and_metadata_fonts`
  - `rejects_fewer_than_two_or_more_than_four`
  - `reserves_one_row_with_dummy`
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run both validations.** Expected: PASS.
- [ ] **Step 5: Doc and Gallery.** Fixtures: two tiles and three tiles, viewed at Compact.
- [ ] **Step 6: Commit** `feat(ui): add stat group`.

---

### Task 7: List and List Row component

**Files:**
- Create: `packages/ReaToolUI/lib/reaui/design_list.lua`, `tests/ui_design_list_spec.lua`, `docs/design-system/components/list.md`
- Modify: catalog (`{ id="list", name="List", module="design_list", factory_key="list", spec="components/list.md", fixture="List and List Row" }`), tokens (`component.list_row.background` → `semantic.color.surface.inset`), Gallery, README

**Interfaces:**
- Consumes: `design_layout`, `design_status`, `design_button`, `design_menu`.
- Produces `list.draw(options) -> { events, action = { row = row_id, id = action_or_menu_item_id } | nil, overflow_toggled = boolean }`.

Options:

- `id`, `variant?`: `"standard"` (the default) or `"compact"`.
- `items`: an array of either:
  - `{ kind = "group", label }`, or
  - `{ kind = "row", id, title, detail?, status? = { role, text }, action? = { id, label, variant?, disabled? }, menu? = { accessible_label, items } }`.
- `overflow?`: `{ label, expanded: boolean }`.

Events: `list.row_action` (fields `row` and `action`) and `list.overflow_toggled`.

Rendering:

- **Row container:** each row is a child window with `ChildBg = component.list_row.background`, rounding `semantic.radius.control`, padding `inset.padding_x` and `inset.padding_y`, and `AutoResizeY`. Rows are separated by `semantic.space.list.gap`. There is no separator.
- **Row height:**
  - standard: minimum `size.row.double` with a detail line, otherwise `size.row.single`;
  - compact: `size.row.compact`. A compact row with `detail` is an error.
- **Title area:** `title` uses the `body` font and `TextWrapped`. `detail` goes below it in the `metadata` font with secondary color.
- **Trailing controls:** in order, status (inline), then the action button (`size.control.compact` height in compact rows), then the menu icon. Their total width goes through `layout.trailing`. If it wraps, the controls sit on their own line under the title.
- **Group label:** `metadata` font with secondary color, `list.gap` above it except at the start of the list.
- **Overflow row:** a compact row with `label` in secondary color and a quiet button labeled `Show All` or `Show Less`, depending on `expanded`. The list does not slice items; the product passes the visible rows.

- [ ] **Step 1: Write failing tests:**
  - `rows_have_no_separator_and_use_list_gap`
  - `double_height_when_detail_present`
  - `trailing_wraps_under_long_title_at_320`: Review Focus 2. An 80-character title at avail 320 with status plus action makes `layout.trailing` return `true`, and no item is positioned beyond the content width.
  - `compact_rejects_detail`
  - `group_labels_render_between_rows`
  - `overflow_toggle_label_and_event`: `Show All` when collapsed, `Show Less` when expanded, and the event is emitted.
  - `disabled_row_action_never_emits`
  - `empty_list_renders_nothing_and_emits_nothing`: Review Focus 5.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run both validations.** Expected: PASS.
- [ ] **Step 5: Doc and Gallery.** Fixtures:
  - four rows in neutral, ready, warning, and blocked states, with actions and menus;
  - a compact grouped list with `Detach...`-style quiet actions, using generic labels such as `Remove...`;
  - an overflow row, both collapsed and expanded.
- [ ] **Step 6: Commit** `feat(ui): add list and list row`.

---

### Task 8: Issue Item and Page Header components

**Files:**
- Create: `design_issue_item.lua`, `design_page_header.lua` in `packages/ReaToolUI/lib/reaui/`
- Create: `tests/ui_design_issue_item_spec.lua`, `tests/ui_design_page_header_spec.lua`
- Create: `docs/design-system/components/issue-item.md`, `components/page-header.md`
- Modify: catalog (`issue_item` / "Issue Item" / fixture "Issue Item"; `page_header` / "Page Header" / fixture "Page Header"), tokens (`component.issue_item.warning.background|border` → `semantic.color.tint.warning.*`, `component.issue_item.blocked.background|border` → `semantic.color.tint.blocked.*`), Gallery, README

**Interfaces:**
- Produces `issue_item.draw({ id, role = "warning"|"blocked", message, detail?, actions? }) -> { events, action }`. It is a child window with the tint background, a 1-unit tint border, rounding `semantic.radius.control`, inset padding, and `AutoResizeY`. Inside, in order:
  1. `status.draw({ role, text = message, presentation = "inline", detail })`;
  2. if there are actions, `action_bar.draw({ id, actions })`.

  It errors on any other role.
- Produces `page_header.draw({ id, title, badge?, meta?, back_label?, actions? = { {id, label, icon?, variant?} } }) -> { events, action, back_requested }`.
  - `collapsed = avail < semantic.layout.page_header.collapse_below`.
  - Left side: an optional back icon button (`back` icon, accessible label `back_label`), the title in the `title` font, and the badge (`metadata` font, 1-unit `semantic.color.border.subtle` outline, radius control, `inset.padding_x / 2` horizontal padding).
  - Right side, through `layout.trailing`: `meta` in the `label` font with secondary color (hidden when collapsed), then the actions. When collapsed, any action with an `icon` renders as an icon button with `accessible_label = label`.
  - Afterwards, a vertical gap of `header.gap_below` (or `gap_below_compact` when collapsed).
  - No separator.

- [ ] **Step 1: Write failing tests:**
  - `issue_item_uses_tint_tokens_per_role`
  - `issue_item_rejects_ready_role`
  - `issue_item_action_event`
  - `header_collapses_text_actions_to_icons_below_560`
  - `header_hides_meta_when_collapsed`
  - `header_never_draws_separator`
  - `header_back_requested`
  - `header_gap_below_uses_compact_value_when_collapsed`
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run both validations.** Expected: PASS.
- [ ] **Step 5: Docs and Gallery fixtures.** Show both Issue Item roles, with and without detail, and Page Header at Compact and Wide.
- [ ] **Step 6: Commit** `feat(ui): add issue item and page header`.

---

### Task 9: Review pattern and Disclosure revision

**Files:**
- Modify: `design_review_header.lua` (delegate to Page Header), `design_review_footer.lua`, `design_review_shell.lua`, `design_disclosure.lua`
- Modify: `tests/ui_design_review_patterns_spec.lua`, `tests/ui_design_information_spec.lua` (holds the Disclosure tests)
- Modify: `docs/design-system/patterns/review.md`, `components/disclosure.md`, Gallery Patterns fixtures

**Interfaces:**
- `review_header.draw` keeps its options (`id, title, back_label, disabled, summary`) and return shape. It renders through `page_header.draw` with `back_label`. `summary` goes under the title in the `label` font with secondary color.
- `review_footer.draw` keeps its options and return shape. It draws one separator, then applies the footer padding tokens, then `status.draw({ role, text = summary, presentation = "inline" })`, then the complete button through `layout.trailing`. The manual `SetCursorPosX` math (current lines 23–28) is removed. Below `semantic.size.field.inline_wide`, the button stretches on its own line as today.
- New `review_shell.section({ id, title }, render: fun(): any) -> any`. It draws the title in the `heading` font and the body below it. Consecutive sections are separated by `semantic.space.section.loose` (24). It returns `render()`'s result.
- `disclosure.draw` gains `variant? = "default"|"inset"`, `detail?: string`, and `role?: string`. The inset variant draws the header row on `semantic.color.surface.inset` with radius control and a row height of `size.row.single`. `detail` is right-aligned in `metadata` secondary. When `role` is set, a status glyph appears after the label. An inset disclosure with a `role` of `warning` or `blocked` defaults to open.

- [ ] **Step 1: Write failing tests:**
  - `review_header_renders_through_page_header_with_back`
  - `review_footer_draws_exactly_one_separator`
  - `review_footer_uses_layout_trailing`
  - `review_sections_are_separated_by_section_loose`
  - `inset_disclosure_auto_opens_for_blocked_role`
  - `inset_disclosure_detail_is_right_aligned`

  Keep the existing Review event-order and stale tests passing unchanged.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run both validations.** Expected: PASS. ReaProjectLink Reviews consume these patterns, so they must keep working, with only visual changes.
- [ ] **Step 5: Docs and Gallery.** Update `review.md` (spec 5.9) and `disclosure.md`. The Gallery Review fixture gains a Stat Group summary, two Issue Items, and inset details.
- [ ] **Step 6: Commit** `feat(ui): restyle review patterns for Direction C`.

---

### Task 10: Gallery Direction C recipes for visual review

**Files:**
- Modify: `packages/ReaToolUI/gallery/design_system_gallery.lua` (Cross-product Scenarios section, `reaprojectlink-scenario` selector)

**Interfaces:**
- Consumes: every component from Tasks 2–9.

Add three selector values next to the existing `settings` view. Each recipe uses only shared components (no `SameLine` or `Separator` in the recipe code) and static fixture data:

- `master-main`: the Master main panel from mockup `master-direction.html` option C. It shows a Page Header, a Card Row with a Reference card (status, Stat Group, footer with `Register`, `Unregister`, and `Review and Publish`) and a Deliveries card (aggregate status plus a List with four rows in mixed states).
- `source-main`: the Source panel from `direction-c-stress.html` scene 1. The highlighted Reference card has a grouped compact list with an overflow row.
- `publish-review`: the Delivery Publish Review from `direction-c-review-light.html` scene 1.

- [ ] **Step 1: Implement the three recipes.**
- [ ] **Step 2: Run ReaToolUI validation.** Expected: PASS with Gallery still at 30 scenarios.
- [ ] **Step 3: Commit** `feat(ui): add Direction C gallery recipes`.

---

### Task 11: Layout scan tool

**Files:**
- Create: `tooling/check_ui_layout.ps1`, `tooling/test_check_ui_layout.ps1`
- Create: `tooling/fixtures/ui_layout/clean/view.lua`, `tooling/fixtures/ui_layout/dirty/view.lua`
- Modify: `tooling/run_all_tests.ps1` (add steps), `.github/workflows/check.yml` (add `./tooling/test_check_ui_layout.ps1` to the `distribution` job), `tooling/README.md`

**Interfaces:**
- Produces `check_ui_layout.ps1 -Path <dir> [-Report]`. It scans `*.lua` files directly under `-Path` and prints one line per finding: `<relative path>:<line>: <rule>: <excerpt>`. It exits 1 when there are findings, unless `-Report` is set, which always exits 0. It prints `PASS ui layout (<n> files)` when clean.

Rules:

- `raw-layout` matches the regex `ImGui\.(SameLine|Separator|NewLine|Dummy|Indent|SetCursorPos\w*|PushStyleVar|PushStyleColor)\s*\(`.
- `layout-literal` applies to the argument list of any single-line call matching `\b(c|ImGui)\.\w+\(([^()]*)\)`. It flags a numeric literal `(?<![\w.])\d+(\.\d+)?(?![\w.])` whose value is not 0 or 1.
- Lines that are entirely `--` comments are ignored.

- [ ] **Step 1: Write fixtures and a failing self-test.**
  - `clean/view.lua` uses only `c.card_row.draw({...})`-style calls with string and table arguments.
  - `dirty/view.lua` contains one `ImGui.SameLine(ctx, 0, 8)`, one `ImGui.Separator(ctx)`, and one `c.same_line_right(120)`.
  - `test_check_ui_layout.ps1` asserts:
    - the clean fixture exits 0 and prints `PASS ui layout (1 files)`;
    - the dirty fixture exits 1 with exactly 4 findings: `raw-layout` twice, plus `layout-literal` for `8` and for `120`;
    - `-Report` on the dirty fixture exits 0.

  It prints `PASS ui layout scan`.
- [ ] **Step 2: Run** `pwsh -File tooling/test_check_ui_layout.ps1`. Expected: FAIL, script missing.
- [ ] **Step 3: Implement** `check_ui_layout.ps1`.
- [ ] **Step 4: Run the self-test.** Expected: `PASS ui layout scan`.
- [ ] **Step 5: Wire it up.**
  - `run_all_tests.ps1` gains step `UI layout scan` (the self-test).
  - It also gains step `ReaProjectLink layout report`, which runs `check_ui_layout.ps1 -Path tools/ReaProjectLink/ReaProjectLink/lib/reaprojectlink/ui/views -Report`. This step is report-only until the migration plan makes it enforcing (spec step 3).
  - Add the self-test to CI.
- [ ] **Step 6: Commit** `feat(tooling): add UI layout scan`.

---

### Task 12: ReaAssetFlow paper check

**Files:**
- Create: `packages/ReaToolUI/docs/design-system/validation/2026-10-reaassetflow-paper-check.md`

- [ ] **Step 1:** For each of Action Bar, Card, Card Row, Stat Group, List, Issue Item, Page Header, Status, and the Review patterns, find the ReaAssetFlow UI that would use it in `tools/ReaAssetFlow/ReaAssetFlow.lua`: settings forms, transfer lists, path rows, action rows, and progress or result summaries. Record a table with columns `Component | ReaAssetFlow surface (function name, line) | Result (covered / covered with note / product-specific) | Note`.
- [ ] **Step 2:** If any row is "covered with note" because a shared API cannot express a ReaAssetFlow need, list the change. Do not implement it; it goes to the user in Task 13.
- [ ] **Step 3: Commit** `docs(ui): record ReaAssetFlow paper check`.

---

### Task 13: Full validation and visual review round 2

- [ ] **Step 1:** Run `pwsh -File tooling/run_all_tests.ps1`. Expected: every step `PASS`. The `ReaProjectLink layout report` step lists the current findings in `views/`, which is input for the migration plan.
- [ ] **Step 2:** Capture the Gallery Components and Patterns sections plus the three Task 10 recipes, in Light and Dark, at Compact and Wide (20 images), into `.superpowers/review/round-2/`.
- [ ] **Step 3:** Show the images, the paper-check notes from Task 12, and the layout report to the user. Stop. Iterate on components until the user accepts. Then write the ReaProjectLink migration plan from spec sections 7, 8, 10 (product docs), and 12 step 4.
