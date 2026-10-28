# Card Content Lists Design

Date: 2026-10-28. Status: agreed in conversation; awaiting approval of this
document.

## Intent

ReaProjectLink cards show only counts (`3 Tracks`, `1 Marker`), so the user
cannot tell **which** Tracks, Markers, and Regions are registered, and the
selection section says how many things are selected in REAPER but not which
ones or whether each is already registered. The user wants both answered at a
glance in the panel:

1. What is registered (and therefore goes out with the next publish)?
2. What is selected in REAPER right now, and is each selected thing
   registered?

"Registered" is the only state shown. "Registered but not yet published" is
not distinguished from "published"; the user thinks of both as "in the link".

## Goals

- Every card that has content lists it by name, grouped by kind, with the
  count in the group header.
- The selection is listed by name, each row marked Registered or Not
  Registered, so the effect of Register / Unregister is visible before
  clicking.
- The three content cards (Master Reference, Source Delivery, Source
  Reference) share one structure.

## Non-goals

- No marking inside the REAPER arrange view (track color, icon, or name).
  REAPER content stays untouched.
- No "pending publish" state.
- No change to the status line's wording or roles.
- The Master Deliveries card keeps its current layout.

## Anti-goals

- Hiding content behind a fixed item limit ("first 5 + Show All"). The user
  rejected this; each kind collapses on its own instead.
- Selected items disappearing from view without any affordance.

## Card structure

Top to bottom, with a divider between every two consecutive parts:

1. **Title row and status line.** Unchanged, except the status `detail` moves
   onto the status line (see Status below).
2. **Body notes.** Existing card notes (`Will record Reference r4`, marker
   errors, `Package Missing` explanation, empty-state guidance) stay where
   they are today, directly under the status line and above the first
   divider. Stat tiles are removed from these three cards.
3. **Content section.**    Section Heading `Registered` (Source Reference:
   `Synchronized`). Groups in the order Tracks, Markers, Regions; a kind with
   zero entries has no group. With no entries at all the section shows the
   muted text `Nothing registered` (Source Reference: `Nothing synchronized`,
   e.g. after everything was detached).
4. **Selection section** (Master Reference and Source Delivery only).
   Section Heading `Selected`. Groups for the selected kinds only, each row
   carrying a trailing status: `Registered` (ready role, check glyph) or
   `Not Registered` (neutral role). With nothing selected it shows the muted
   text `Nothing selected`. Below the groups, on their own row, the secondary
   buttons `Register` and `Unregister` (right-aligned, Action Bar layout).
   Both buttons are always shown. `Register` is disabled when no selected
   entry is Not Registered; `Unregister` is disabled when no selected entry
   is Registered. The service-level errors stay as a fallback.
5. **Footer.** The card action (`Review and Publish`, `Review Update`, ...),
   pinned to the bottom right as today.

Sections stay with the content; only the footer is pinned when Card Row
stretches a card.

### Per card

| Card | Content section | Row trailing | Selection section |
|---|---|---|---|
| Master Reference | `Registered`: Tracks, Markers, Regions | none | Tracks, Markers, Regions |
| Source Delivery | `Registered`: Tracks; header reads `3 Tracks · 5 Items` | the Track's item count, e.g. `2 Items` | Tracks |
| Source Reference | `Synchronized`: Tracks, Markers, Regions; shown only after the first synchronization | `Detach...` (unchanged behavior) | none |

## Groups and collapsing

- A group header reads `▾ 3 Tracks`: a disclosure caret, the count in the
  primary text color, then the noun in the secondary text color. The noun
  agrees with the count (`1 Marker`, `2 Markers`).
- Clicking a header collapses or expands that group. Every group starts
  expanded.
- Collapse state lives in memory for the current panel session, keyed by card,
  section, and kind. It resets to all-expanded when the project changes or
  the app resets. It is not saved to the project.
- There is no item limit and no `Show All` / `Show Less`. A long registration
  makes the card tall and the panel scrolls.

## Typography

- Section Heading: `heading` role (16 bold), primary color, `gap_above =
  false` because the divider already separates it.
- Group header: `body` role (14). Count primary, noun secondary, caret
  secondary.
- Rows: unchanged List rows (`body`, 14).
- Row trailing text (Source Delivery item count): `metadata`, secondary.
- Empty texts (`Nothing registered`, `Nothing selected`): `body`, secondary.

## Status detail on one line

The prominent Status presentation draws `detail` on the same line as the text,
`semantic.space.inline.default` after it, in `metadata` and the secondary text
color, bottom-aligned with the status text. When it does not fit in the
remaining width, it wraps to its own line as today. This changes every card
that passes a `detail` (in ReaProjectLink only Source Reference:
`Up to Date  Reference r2`, `Reference r3 Available  Synchronized r2`).

## Data sources (ReaProjectLink)

All names already exist; no new persisted data.

- Master registered Tracks: `reference_publish.reference_tracks(adapter)`
  (`display_name`). Registered Markers / Regions:
  `reference_publish.timeline_entries(adapter)` entries with `registered`.
- Master selection: `adapter.selected_tracks()` with
  `get_track_reference_lane_id` for the registered flag and
  `adapter.track_name`; Markers / Regions from the same `timeline_entries`
  with `selected`.
- Source registered Tracks: `project_service.delivery_tracks(adapter)`
  (`display_name`, `item_count`). Source selection: `adapter.selected_tracks()`
  with `get_track_lane_id`.
- Source Reference: `reference_subscription.local_surface(adapter)`, as the
  current name list does, including its fallbacks (`Unnamed Track`, ...).
- Empty names use the same fallbacks as today's Reference list.
- When `timeline_entries` fails (invalid Marker/Region registrations), both
  sections omit the Markers and Regions groups, the existing error note
  explains why, and neither section shows its empty text, so the card never
  claims that nothing is registered or selected while it cannot tell.

## Shared ReaToolUI changes

- **Card:** replace the single `selection` option (added by DS023) with an
  ordered `sections = { { id, heading, render } }`. Card draws a divider and a
  Section Heading before each section, after the body. The existing
  `render_body`, footer pinning, and natural-height behavior stay. Cards
  without `sections` (Master Deliveries, Setup, Gallery fixtures) are
  unchanged.
- **List group item:** gains `count`, `collapsible` and `collapsed`; draws
  the header as described above; rows that follow a collapsed group, up to
  the next group, are not drawn; clicking emits
  `{ type = "list.group_toggled", id = <list id>, group = <group id> }`. The
  caller owns the state. Group headers switch from `metadata` to `body`.
- **List row:** gains optional `trailing_text` (metadata, secondary),
  measured with the other trailing parts.
- **Status:** detail on one line as above.
- **Remove** what this design makes unused: the Selection Strip module,
  `component.card.selection.*` tokens, the Card `selection` option, and the
  List `overflow` option if no product still uses it.

## Decisions to record

- ReaToolUI DS024: Card sections, collapsible counted List groups, and the
  one-line status detail. It supersedes DS023's Card selection and amends the
  DS022 separator rule (dividers between status and each section).
- ReaProjectLink D093 amendment: item 3 (first 5 names + Show All) is replaced
  by per-kind collapsible groups; the selection section lists names with their
  registered state; stat tiles leave the three content cards.
- Update `card.md`, `list.md`, `status.md`, and ReaProjectLink `ui-spec.md`.

## Left to the builder

- Exact view-model shapes and function names.
- Group ids and the in-memory collapse-state key format.
- Test layout, following the existing spec style.
