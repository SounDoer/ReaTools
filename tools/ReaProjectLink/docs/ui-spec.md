# ReaProjectLink UI specification

ReaProjectLink is a workflow tool embedded in REAPER. The UI shows each
domain's state and the one next step, keeps setup and rare operations out of
the way, and routes every mutation through a Review. Decisions: D085, D086.

## 1. Information architecture

The former left-hand navigation sidebar and the Overview/Reference/Delivery/Settings pages are
removed. The UI has three layers:

| Layer | Content | Enter / leave |
|---|---|---|
| Main panel | Header + two domain cards | Always present |
| Review | Full-panel workflow view | Entered from a card action; leaves on Back, on completion, or when the project changes |
| Settings | Full-panel project information and preferences | Entered from the header gear; leaves on Back |

Source cards: **Reference**, **Delivery**.
Master cards: **Reference**, **Deliveries**.

### 1.1 Header

The header is a ReaToolUI Page Header.

Left: project name, `Source` / `Master` badge.
Right: `Checked N min ago` metadata, `Check Now` button with a refresh icon,
gear icon button. On a Master with nothing to do, the metadata reads
`All Up to Date  ·  Checked N min ago`. In a narrow window the metadata hides
and `Check Now` collapses to a refresh icon button with a tooltip (D093).

Blocking global conditions (project not saved, Publishing Is Locked) appear as a
banner directly under the header, followed by one block gap. The banner
carries its own action (for example `Unlock Publishing…`).

### 1.2 Next-step highlight

Exactly one card at most is highlighted: accent border and the view's only
primary (filled) button. All other card buttons are secondary. This replaces
the separate Next Action panel.

Source priority (first match wins):

1. Reference not subscribed
2. Reference unreachable or blocked (for example media file not found)
3. Newer Reference Revision available
4. No Delivery Tracks registered
5. Delivery (daily publish) — Source always has a highlighted card

Master priority:

1. Nothing registered (no Reference Tracks, Markers, or Regions)
2. Reference never published
3. No Delivery subscriptions
4. Any subscription with a newer Delivery Revision, unmapped Lanes, or a read failure
5. Otherwise nothing is highlighted and the header shows `All Up to Date`

### 1.3 Responsive layout

- Cards sit side by side with equal width in a ReaToolUI Card Row and stack
  below its breakpoint (`semantic.layout.card_row.stack_below`).
- Review content is capped at `component.review_shell.content.max_width` and
  centered in wide windows. Settings is capped at
  `semantic.layout.content.max_width` and centered the same way; setup uses the
  same cap but stays left-aligned with the banners above it.
- Long paths wrap; nothing forces horizontal scrolling.

### 1.4 First run

An uninitialized project shows only a setup view, titled `Set Up
ReaProjectLink` with the line "Choose the type for this project." and two
cards laid out like the main panel's:

- `Source Project` — "An editing project that publishes Deliveries to the
  Master Project." → `Initialize Source Project`
- `Master Project` — "An integration project that publishes the Reference and
  receives Deliveries." → `Initialize Master Project`

After initialization the main panel appears and card empty states guide the
remaining setup.

## 2. Cards

Every card is a ReaToolUI Card with the same anatomy: icon + title + optional
trailing icon button; one status line (status glyph + text) with an optional
secondary detail such as the revision, on the same line when it fits; an
optional note; content sections; and a footer Action Bar. Each section sits
behind a divider (D093):

- `Registered` (`Synchronized` on the Source Reference) lists every name in a
  collapsible group per kind, for example `▾ 3 Tracks`, expanded by default.
  Kinds without names have no group. An empty section reads `Nothing
  registered` or `Nothing synchronized`.
- `Selected` (Master Reference and Source Delivery) lists what is selected in
  REAPER, each row tagged `Registered` or `Not Registered`, or reads `Nothing
  selected`. A row of two secondary buttons, `Register` and `Unregister`,
  acts on the selection; `Register` is disabled when everything selected is
  registered and `Unregister` when nothing selected is.

Group collapse state resets when the project changes. The footer holds only
the card-level button, pinned to the bottom right and primary only on the
highlighted card.

### 2.1 Source · Reference

| State | Status line | Info | Button |
|---|---|---|---|
| Not subscribed | `Not Connected` (warning) | "Choose the reference.json the Master Project published." | `Choose reference.json` |
| Checking | `Checking…` (neutral) | Last known revision | — |
| Unreachable | `Couldn't Reach Shared Storage` (blocked) | Last known revision | `Retry` |
| Invalid (pointer unreadable or identity changed) | `Couldn't Read the Reference` (blocked) | Error detail | `Retry` |
| Blocked (e.g. media missing) | Condition text per D080 (blocked) | Last known revision | `Review Update` |
| Newer available | `Reference rN Available` (warning), detail `Synchronized rM` | Tracks, Markers, and Regions currently in the project | `Review Update` |
| Up to date | `Up to Date` (ready), detail `Reference rN` | Tracks, Markers, and Regions currently in the project | — |

The "synchronized but not reviewed" state no longer exists (D086).

When a Reference revision is already in the project, a `Synchronized` section lists its Tracks, Markers, and Regions in one collapsible group per kind, each name with its own `Detach...` (D093). It describes the revision already in the project, including while a newer revision is available; before the first synchronization the section is omitted. There is no separate Contents section. Detach leaves the object in the project and stops later synchronizations from changing it. The next synchronization adds a new managed copy. Detaching a Track also detaches the Reference Items on it; those Items are not listed separately. There is no `···` menu on this card.

### 2.2 Source · Delivery

The `Registered` section lists the Delivery Tracks with their Item counts
(`3 Tracks · 5 Items`). The `Selected` section and its `Register` /
`Unregister` buttons act on whatever Tracks are selected in REAPER. There is
no `···` menu on this card.

| State | Status line | Info | Button |
|---|---|---|---|
| No tracks | `No Delivery Tracks` (warning) | "Select tracks in REAPER first."; `Nothing registered` | — |
| Never published | `Not Published Yet` (neutral) | Registered Tracks | `Review and Publish` |
| Published | `Last Published rN` (ready) | Registered Tracks | `Review and Publish` |

When the Delivery card is not highlighted because a newer Reference is pending,
the button stays enabled and a hint reads `Will record Reference rN`.

### 2.3 Master · Reference

The `Selected` section's `Register` / `Unregister` buttons register or
unregister whatever Tracks, Markers, or Regions are selected in REAPER.

| State | Status line | Info | Button |
|---|---|---|---|
| Nothing registered | `Nothing Registered` (warning) | "Select Tracks, Markers, or Regions in REAPER, then register them." | — |
| Never published | `Not Published Yet` (warning) | Registered Tracks, Markers, and Regions | `Review and Publish` |
| Published | `Published rN` (neutral) | Registered Tracks, Markers, and Regions | `Review and Publish` |
| Package Missing | `Package Missing` (blocked) | Registered content; note explains published files weren't found | `Review and Publish` |

There is no `···` menu on this card.

`Unregister` acts immediately, without a confirmation dialog; the
consequence only becomes real at Publish, where Publish Review blocks on
content removed since the last published revision (D089).

### 2.4 Master · Deliveries

Title bar has a `+` icon button: `Add Delivery` (file dialog for
`delivery.json`, then the Delivery Import Review). With no subscriptions the card
shows `No Deliveries Yet` (warning), a note, and an `Add Delivery` footer
button, primary when the card is highlighted.

With subscriptions, the status line aggregates the rows (D093): `N Need
Attention` (blocked if any of those rows is blocked, otherwise warning),
`Checking...`, or `All Up to Date`. Below it, a standard List has one row per
subscription: name, status, an action button when the row needs attention, and
a `···` menu. Only the first row needing attention on the highlighted card gets
the primary button.

| Row state | Status text | Row action |
|---|---|---|
| Newer revision | `rN Available · Have rM` (warning) | `Sync` |
| Unmapped Lanes | `N Lanes Not Imported` (neutral) | `Map Lanes` |
| Unreachable | `Couldn't Reach` (blocked) | `Retry` |
| Invalid | `Couldn't Read Delivery` (blocked) | `Retry` |
| Older Reference | `Made Against Reference rN` (warning) | `···` |
| Up to date | `Up to Date · rN` (ready) | `···` |

When several states apply, the row shows the first in this order: Unreachable,
Invalid, Newer revision, Unmapped Lanes, Older Reference, Up to date.

Row `···` menu: `Sync to Another Revision…`, `Remove Subscription…`.

## 3. Update checks

- Reference and Delivery pointers (small JSON files only, never media) are read
  once when the window opens and once when the active REAPER project changes,
  plus on `Check Now` and `Retry`.
- The first frame renders `Checking…`; the read happens on the next frame.
- A read failure sets that card or row to Unreachable (the pointer file is
  missing, for example the share is offline) or Invalid (the file can't be
  parsed or its identity changed); it never opens an error dialog.
- Known limitation: Lua file I/O has no timeout, so an unreachable SMB share can
  stall the UI for a few seconds during a check. Accepted.
- No periodic polling.
- On a Master with a published Reference, the same check also confirms its own
  `reference.json` still exists next to the manifest; if not, the Reference
  card shows Package Missing instead of Published (D088).

## 4. Review pattern

All Reviews use the ReaToolUI Review Shell and share one skeleton. Sections
are headed (`Issues`, `Decision`, `Checked Against Reference`, `Lanes`,
`Revision`, `Contents`, `Items`, ...); empty sections are omitted.

1. **Header** — Back arrow, verb-first title with the target revision
   (for example `Publish Delivery r13`), one summary line. Publish Reviews add
   a Stat Group with the scope counts.
2. **Issues** — Issue Items for blockers and warnings. Each item carries an
   inline fix or acknowledgment action (for example `Select Item` selects the
   offending Item in REAPER; `Publish Unprocessed Media...`; `Allow Difference`
   (D093); `Publish Without Them...` for Tracks, Markers, Regions, or Lanes
   removed since the last published revision (D089); Save As identity as two
   buttons `Continue Existing` / `Start New`).
3. **Decisions** — choices the operation needs (Reference declaration, Lane
   Mapping table, target revision, parent for new tracks).
4. **Details** — inset Disclosures per Lane or kind, collapsed by default,
   auto-expanded when the group contains an issue. Long Item lists use
   clipping.
5. **Footer** — fixed at the bottom: one-sentence effect summary and the only
   primary button. With blockers the button is disabled and the text reads
   `Fix N issues to publish` (or the matching verb).

**Stale state:** when the project changes after the Review was built, the whole
body is replaced by `Review Out of Date` + explanation + `Refresh Review`. Stale
decisions are never actionable (existing D067 behavior). This applies to the
Delivery Publish and Reference Publish Reviews; the Delivery Import, Delivery
Update, and Reference Update Reviews are not tracked for project changes.

**Checking state (D094):** a Review that hashes media opens at once with a
plain title (`Publish Delivery`, `Publish Reference`, `Update Reference`,
`Add Delivery`, `Sync Delivery`), an External Operation Status block
`Checking media: Hashing media files` with measured progress and `Cancel`,
and a disabled footer reading `Checking media...`. Delivery Update `Load`
keeps the current revision visible but disabled, with the status block above
it.

**Publishing state (D094):** the status block reads `Publishing:` plus the
phase (`Copying and verifying media`, `Cancelling after the current file`,
`Finishing`), progress for Delivery Publish, and
`Edits made now will be in the next revision. Cancel or wait for Publish to
finish.` `Cancel` is offered until `Finishing`. Back, the body, and the footer
(`Publishing...`) are disabled, and edits in REAPER don't switch the Review to
Out of Date while it runs. A failed or cancelled Publish shows the reason with
`Retry`, which refreshes the Review.

### 4.1 Review inventory

| Review | Title | Decisions | Details | Primary |
|---|---|---|---|---|
| Reference Update (Source) | `Update Reference to rN` | Whole-project shift toggle, only when every stable element moved together | Alignment mode, then the same Contents groups as Reference Publish: Tracks with Item counts, Marker names, Region names | `Synchronize` |
| Reference Publish (Master) | `Publish Reference rN` | Unchanged-publish confirmation when nothing changed | Registered Tracks, Markers/Regions | `Publish` |
| Delivery Publish (Source) | `Publish Delivery rN` | Checked Against Reference (D086); Save As identity | Clips per Lane | `Publish` |
| Delivery Import / Update (Master) | `Add <name>` / `Sync <name> to rN` | Lane Mapping table; target revision; parent for new tracks | Mapped Lanes with editable target | `Import` / `Sync` |

Reference Update is a new Review view; its controls previously sat inline on
the Reference page and now live in the Reference Update Review. The separate
Reference-review confirmation step is removed (D086).

### 4.2 Lane Mapping table

Replaces the per-Lane button rows.

- One inset row per Lane: Lane name, Item count, one dropdown. In a narrow
  window the dropdown moves under the text at full width.
- Dropdown groups: suggested Tracks (name match) first; then `New Track`,
  `Selected Track`; then `Don't Import`.
- Default is `New Track` in both the Delivery Import and Delivery Update
  Reviews. A Lane the user previously chose not to import stays `Don't Import`
  until they map it. Suggestions are never preselected (D054 unchanged).
- Header control `New tracks go under: Top Level | Selected Folder Track`
  replaces `Create All Under Selected Folder Track`.
- `Selected Track` with zero or several selected tracks shows an inline issue
  on that row instead of a toast.
- Already-mapped Lanes (Update Review) list their current target in the same
  dropdown so a Lane can be re-bound.

## 5. Settings

| Group | Source | Master |
|---|---|---|
| Project | Name, `.rpp` path, Project ID, Delivery ID (copyable) | Name, `.rpp` path, Project ID, Reference ID (copyable) |
| Reference | `reference.json` path + `Change…`; Mirror Master Timeline toggle | — |
| Appearance | Theme: Auto / Light / Dark | Same |
| About | ReaProjectLink, REAPER, ReaImGui versions | Same |
| Reset | `Reset ReaProjectLink State…` button. It removes this project's published package as well as its ReaProjectLink state. Audio and video Items in the project are kept | Same |

Settings has a Page Header with a back control. Each group is a heading
section. Project and About values are standard List rows (label as the title,
value as the detail); Project rows have a `Copy` action (D093).

`Unlock Publishing…` lives in the lock banner, not in Settings.

## 6. Notifications

- Transient toast floating over the bottom of the window, so it never moves
  the content underneath. Persistent banners (unsaved project, Publishing Is
  Locked) stay in the layout under the header.
- Success toasts disappear after ~4 s; error toasts stay until dismissed.
- Errors that belong to a Review are shown as Review issues, not toasts.
- A success toast appears only when the result is not already visible in the
  panel: publishing a Reference or a Delivery, synchronizing a Reference,
  importing or synchronizing a Delivery, and keeping moved Items as local
  content. These write outside the panel — a published package, or a batch of
  Items in REAPER — and their toast names the revision or the counts.
- Everything else is silent on success, because the view already shows the
  result: registering and unregistering, detaching, initializing a project,
  subscribing to a Reference, removing a
  subscription, the alignment toggle, unlocking, and resetting the project.
- Errors always show a toast, for every operation.
- A Publish that keeps running after a project tab switch shows a banner at
  the top of the new tab's view: `Publishing <project>`, the phase, progress,
  and `Cancel`. The view below is disabled until it ends. Success shows the
  usual toast; a failure or cancellation stays in the banner with `Dismiss`
  (D094).
- Closing the window during a Publish asks `Cancel Publish and Close`
  (`Publishing is still running. Closing cancels it and removes the partial
  upload.`). During `Finishing` the window closes by itself when Publish ends.

## 7. Visual system

Colors, typography, spacing, shape, icons, and components come from ReaToolUI
(`packages/ReaToolUI/docs/design-system/`). Views compose those components and
resolve every layout value through the design-system adapter;
`tooling/check_ui_layout.ps1` enforces this for `ui/views/` in validation.

Product rules on top of ReaToolUI:

- Theme preference `Auto | Light | Dark` is stored globally in ExtState (not
  per project), default `Auto`. `Auto` reads REAPER's main background theme
  color and picks Light or Dark by luminance.
- UI text uses ASCII `...` instead of the `…` character, which the default
  font's glyph range does not include.
- `ui/components.lua` keeps only the product-local parts: Toast, the Lane
  mapping row with its grouped dropdown, virtualized Item lists, banner and
  confirmation plumbing, and two gap helpers.
