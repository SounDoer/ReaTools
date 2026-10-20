# ReaAssetFlow Paper Check — 2026-10

Status: Paper check only, recorded on 2026-10-20 for the visual language plan
(DS022). ReaAssetFlow is not migrated. No native frame or interaction result is
inferred from this document.

## Purpose

DS022 adds Direction C components and patterns using ReaProjectLink as the
reference product. This check maps each new or revised shared surface to the
ReaAssetFlow window so that the shared APIs are not shaped around ReaProjectLink
alone. The source is `tools/ReaAssetFlow/ReaAssetFlow.lua`; line numbers refer to
the file at the commit that contains this document.

Results:

- **covered**: the shared API expresses the ReaAssetFlow need as is.
- **covered with note**: the need is expressible, but a shared API change would
  make it cleaner; the change is listed below and is not implemented.
- **product-specific**: ReaAssetFlow keeps its own UI or workflow for it.

## Mapping

| Component | ReaAssetFlow surface (function, line) | Result | Note |
| --- | --- | --- | --- |
| Action Bar | `loop`: setup actions 2611–2619; name preview actions 2676–2687; auto-name actions 2689–2739; preset actions 2795–2854; target actions 2946–2952; structure row actions 2992–3023; structure preview actions 3067–3080; transfer row 3112–3169 | covered | The transfer row maps directly: `Selected items: N` becomes `context` and `Transfer to Wwise` is the trailing primary after `Render Settings...`. Greedy wrapping replaces the long `SameLine` runs that currently overflow at the default 560 px width. Token buttons (2626–2638, 3031–3040) stay on the existing Token Insert Group pattern. |
| Card | `ui_major_section_title` 2451 and `ui_section_title` 2445; sections at 2623, 2758, 2858, 2922, 2980 | covered with note | Each current subsection (Auto Renamer, Presets, Wwise project & media, Work units & import target, Wwise structures) becomes one Card whose body holds the existing Text Field, Path Field, and Dropdown components. The two top-level groups, Auto Renamer and Wwise Importer, have no shared heading outside the Review shell; see change 1. |
| Card Row | Whole window, `loop` 2580–2583 (560 × 720 default) | covered | No surface needs peer cards side by side. Below `semantic.layout.card_row.stack_below` Card Row stacks, so a single column of Cards needs no Card Row at all. |
| Stat Group | Structure preview summary 3067–3075; auto-name preview summary `render_auto_name_preview` 2555–2573 | covered | Items, Duplicate Paths, and Skipped fit the two-to-four tile rule. The lone `Selected items` count (3113) belongs in Action Bar `context`, not a one-tile group. |
| List | Auto-name preview rows 2740–2755; preview leaf items 3086–3095; items outside the destination 3098–3109 | covered | Auto-name groups (`[Track: … \| Marker: …]`) map to `kind = "group"` labels with compact rows. Items outside the destination use standard rows with the path as `detail`. The selectable structure rows (2981–2990) are not a List; they stay on the Ordered List Editor pattern. |
| Issue Item | Missing prerequisites 2602–2621; transfer validation 3125–3128; multi-track warning 3131–3139; path collision warning 3140–3150 | covered | Missing prerequisites becomes a blocked Issue Item with `Open Installation Folder` and `Check Again` actions. The two transfer warnings become warning Issue Items in a transfer review instead of `ShowMessageBox` prompts; that move is a product decision, not a component gap. |
| Page Header | Window top, `loop` 2602–2603 | covered | Optional. ReaAssetFlow has no page title today; if one is added, `meta` can carry `Selected items: N`, and the Dev tools can sit behind an `icon_only` action. |
| Status | Status area 3171–3184; prerequisite summary 2602–2610 | covered | The status area is a free-text log with no role. Migration needs the product to store a role with each message (for example from the existing `looks_like_error`, 931). That is product work; Status already expresses all four roles. |
| Review patterns | Transfer flow 3119–3169; auto-name confirmation 2689–2693 and 2715–2719 | covered | A "Transfer to Wwise" review fits the Direction C layout: a Stat Group (items, tracks, duplicate paths), an Issues section with the collision warnings, a Details section with the hierarchy preview, and a footer whose primary action names the count. Import progress and result reporting (`run_import` 1535, `monitor_import_status` 636) remain message boxes and console output; replacing them follows the External Operation Status pattern and is product-specific. |
| Disclosure (inset) | `render_preview_hierarchy` 2155; Dev section 3186–3203 | covered | Top-level preview folders can use inset Disclosures with an item count as `detail`, inside the existing Hierarchy Preview pattern. The Dev section uses the default Disclosure. |

## Proposed shared changes

1. **Section heading outside the Review shell.** `review_shell.section` is the only
   shared section heading, and it exists only inside a Review shell. ReaAssetFlow
   needs a heading above a run of Cards (Auto Renamer, Wwise Importer).
   ReaProjectLink main pages do not. Options for round 2:
   - expose the same heading block as a standalone component;
   - make each top-level group a Card and nest its subsections as body headings;
   - drop the top-level level and keep a flat column of Cards.

   Not implemented; the choice goes to the user in Task 13.

No other row needs a shared API change.
