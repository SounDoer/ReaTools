# Structured Data and Long Content

Status: Confirmed by DS014 on 2026-10-12.

Structured data uses responsive rows that can render as aligned columns when
space permits and as labeled stacked details when it does not. The system does
not introduce a universal spreadsheet-style Grid.

Identity, current condition, validation, selection, and the primary available
action remain understandable at every supported width. Secondary and technical
fields may change placement or move into details, but they are not discarded
when they affect a decision.

## Component families

The initial structured-data model distinguishes:

- **Data List:** repeated records whose fields do not require cross-row column
  comparison;
- **Responsive Table:** repeated records whose fields benefit from aligned
  columns at sufficient width;
- **Structured Row:** the shared responsive record used by either presentation;
- **Single Selection List:** the DS012 input family for choosing one active row;
- **Hierarchy Preview:** a Pattern built from Disclosure or Tree behavior, not a
  Table variant.

A product chooses the simplest family that preserves the user's task. A Table
is not the default merely because each record has several fields.

## Information priority

Every field in a repeated record declares one priority:

| Priority | Responsibility | Narrow-layout treatment |
| --- | --- | --- |
| `identity` | The record's primary name or subject | Always visible |
| `decision` | Condition, validation, selection, or data needed for the next action | Always visible |
| `supporting` | Useful context that improves scanning | Stack below identity or move into visible details |
| `technical` | Paths, IDs, timestamps, diagnostics, and low-frequency metadata | Move into details with complete-value access |

Priority describes task importance, not visual color or data type. A path may be
`identity` in a path-repair workflow and `technical` in a routine summary.

An action is prioritized separately:

- one row-level primary or dominant action may remain visible;
- secondary actions move into a Menu when simultaneous visibility is not
  required;
- dangerous actions retain DS005 intent and DS013 confirmation behavior;
- an action needed to resolve a blocked row is not hidden in technical details.

## Structured Row anatomy

A Structured Row may contain:

1. optional selection or disclosure affordance;
2. primary identity;
3. condition or validation summary;
4. supporting fields;
5. technical detail access;
6. one visible primary row action;
7. an optional secondary-action Menu.

The exact visual order follows the task, but reading order, visual order, and
DS004 focus order remain consistent.

The whole row is not automatically clickable when it also contains Buttons,
Menus, or Disclosure controls. Selection and actions use distinct targets so a
user does not trigger an operation while trying to select or expand a row.

## Column presentation

Responsive Table uses columns only when all required columns can meet their
documented minimum widths without ambiguous clipping.

Column definitions record:

- stable field ID and visible label;
- information priority;
- minimum and preferred width;
- flexible or fixed width behavior;
- text alignment;
- wrapping or truncation policy;
- stacked-row label;
- whether the field participates in sorting when sorting is supported.

The identity column is normally flexible and absorbs remaining width. Numeric
values align consistently within the same column. Status and action columns use
only the width required by their approved content and minimum targets.

Headers appear when column alignment carries meaning. A Data List or stacked
row uses local field labels instead of preserving an empty or misleading header
row.

## Responsive transformation

The component selects column or stacked presentation from its own available
logical width, not the global DS008 page range.

When the documented column minimums no longer fit:

1. supporting columns leave the horizontal row and become labeled details;
2. technical fields move into a details region if they are not already there;
3. identity, decision fields, validation, and the primary action remain visible;
4. row actions wrap or use a Menu according to their priority;
5. the row grows vertically rather than making core content inaccessible.

The transformation preserves the same data and action meaning. Compact layout
does not become a separate reduced-capability component variant.

Exact local transformation widths are derived from declared field minimums and
representative content, then aligned to DS006. Product views do not supply
one-screen breakpoint literals.

## Wrapping and truncation

Different content types use different policies:

- **Primary names:** wrap when a second line preserves useful identity; truncate
  only after the component's documented line limit.
- **Status and validation:** wrap and remain complete; never truncate the reason
  a user cannot proceed.
- **Actions:** preserve an unambiguous label; wrap the action group or move
  secondary actions into a Menu instead of shortening labels unpredictably.
- **Paths:** prefer a path-aware middle truncation when one line is required so
  both the origin and final segment remain recognizable.
- **IDs and hashes:** use deterministic start or middle truncation according to
  which portion distinguishes records.
- **Descriptions:** wrap in stacked detail and may use a documented line limit
  only when complete content remains available.

Every truncated value provides a reliable way to inspect or copy the complete
value. Pointer tooltip alone is insufficient because it does not cover keyboard
use or touch-like interaction. Approved mechanisms include a focused detail
view, Disclosure content, a Copy action, or another persistent full-value
presentation.

Typography is measured at runtime under DS009. Character-count truncation is
not used as a substitute for rendered-width measurement.

## Scrolling and clipping

Vertical scrolling is the default for long repeated data. Row virtualization or
ReaImGui list clipping is used when record count justifies it and the row height
contract supports safe clipping.

Fixed-height clipping must not force wrapped validation or stacked details into
a one-line row. Variable-height rows require a compatible measurement,
virtualization, pagination, or chunking strategy rather than silently clipping
content.

Horizontal scrolling is an exception. It is permitted only when:

- cross-row alignment of many fields is itself essential to the task;
- a stacked representation would materially prevent comparison;
- core identity, condition, selection, and actions remain discoverable;
- keyboard and pointer operation remain usable;
- the product specification records why reflow is insufficient.

Core Review decisions, validation, and recovery actions do not depend on
horizontal scrolling.

## Selection and focus

Selected, focused, hovered, and checked states are distinct:

- **selected** identifies the active data record;
- **focused** identifies the current keyboard target;
- **hovered** reflects pointer location;
- **checked** belongs to a Checkbox value and does not replace row selection.

Selection uses a persistent non-color cue and DS003 contrast. Reflow does not
change the selected record merely because its visual layout changed.

After a selected row is deleted, an Ordered List Editor chooses the nearest
remaining logical neighbor when continued editing is useful; otherwise it
clears selection and states that no row is selected. Product code does not leave
an invisible or stale selected ID.

## Row actions

Row actions follow these rules:

- use one visible primary or contextually dominant action at most;
- place secondary and low-frequency actions in a Menu;
- keep the action that resolves a warning or blocked condition visible when it
  is the user's next meaningful step;
- do not make selection itself execute the primary action;
- disable repeated activation while an operation is running;
- retain action association when rows stack or wrap;
- keep bulk actions at list or table level rather than repeating them in every
  row.

Ordered movement actions such as Move Up and Move Down belong to the DS012
Ordered List Editor Pattern. Drag reordering is not required.

## Loading, empty, failure, and partial data

A structured-data region explicitly presents:

- initial loading or refresh in progress;
- no records because none exist;
- no results because a filter excluded them, when filtering exists;
- load or query failure with a useful recovery action;
- stale cached data and its last known state;
- partial data when some records failed to load or validate.

An empty rectangle is not an empty-state design. Loading does not erase a useful
previous result unless retaining it would misrepresent current state.

DS010 static text is sufficient for activity; a spinner is optional and never
the only cue.

## Sorting and filtering

Sorting and filtering are capabilities, not default Table decorations.

- A sortable column exposes a visible sort direction and deterministic default.
- Changing sort preserves selection by stable record identity.
- Sorting does not move an actively edited row without an explicit component
  rule.
- Filtering requires a confirmed workflow and a Search Field or filter control
  promoted under DS012 criteria.
- An unsortable header does not look interactive.

DS014 does not promote Search Field or multi-selection merely because long data
may eventually benefit from them.

## Hierarchical data

Parent-child paths use Hierarchy Preview or Tree composition when hierarchy is
the primary relationship. They do not flatten into columns merely to reuse
Responsive Table.

Hierarchy rows own Disclosure state, indentation, node identity, condition, and
optional actions. Long leaf names and paths follow the same complete-value rules
as Structured Row.

ReaAssetFlow structure preview is the initial evidence for this Pattern. Wwise
object semantics remain in Product.

## Cross-product mapping

| Product data | Shared presentation | Narrow behavior |
| --- | --- | --- |
| ReaProjectLink repeated project or delivery rows | Data List or Responsive Table | Identity, condition, and next action stay visible; metadata stacks |
| ReaProjectLink Review issues and mappings | Structured Rows inside Review | Decision and validation remain inline; technical detail discloses |
| ReaAssetFlow structure editor | Single Selection List plus Ordered List Editor | Selected row summary stays visible; editor stacks below |
| ReaAssetFlow WorkUnit or target choices | Dropdown, not Table | Long choice labels use complete-value access |
| ReaAssetFlow structure preview | Hierarchy Preview | Nodes wrap or disclose; no forced tabular columns |
| Paths, IDs, and diagnostics in either product | Technical Structured Row fields | Move to details with copy or full-value presentation |

## Component contract

A structured-data specification records:

- record identity and selection key;
- field definitions and priorities;
- minimum and preferred column widths;
- column-to-stacked transformation;
- content-specific wrapping and truncation;
- visible and overflow actions;
- loading, empty, failure, stale, and partial states;
- row height and virtualization compatibility;
- sorting, filtering, selection, and editing capabilities actually supported;
- focus and reading order in both presentations;
- maximum tested record count and performance expectation.

Product code provides records, product labels, domain validation, and effects.
It does not override shared row padding, state colors, or local transformation
rules.

## Validation

Representative validation includes:

- empty, one-row, typical, and large record sets;
- shortest and longest expected names and paths;
- ready, warning, blocked, loading, failed, stale, and partial states;
- selected, focused, hovered, disabled, and action-running rows;
- widths immediately around the local transformation boundary;
- Compact, Standard, and Wide parent layouts under DS008;
- both rebuilt themes and DS002 display scales;
- complete-value access without a pointer;
- stable selection and focus after sorting, reflow, deletion, and refresh;
- performance with clipping enabled and disabled where row height differs.

No production list, table, hierarchy, or long-content behavior is changed by
DS014 itself.
