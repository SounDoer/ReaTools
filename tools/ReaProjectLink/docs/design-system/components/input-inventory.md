# Initial Input Component Inventory

Status: Confirmed by DS012 on 2026-10-12.

The initial input inventory contains only controls required by confirmed
ReaProjectLink and ReaAssetFlow workflows. Inclusion means that the design
system must define a stable contract before migration; it does not require both
products to be rewritten at once.

The confirmed families are Field Shell, Text Field, Integer Number Field, Path
Field, Checkbox, Dropdown, Segmented Control, and Single Selection List.

## Selection rule

An input enters the initial inventory when:

- a current confirmed workflow already uses it;
- its responsibility can be expressed without product-specific data or actions;
- it needs shared state, validation, accessibility, or layout behavior;
- a simpler confirmed control cannot express the same interaction accurately.

A control is not added because ReaImGui exposes it, another design system has
it, or it might be useful someday.

## Field Shell

Field Shell is the shared composition around a field. It owns:

- visible label and label association;
- optional description or instruction;
- optional or required indication when the distinction is meaningful;
- validation and recovery message placement;
- disabled and read-only explanation where needed;
- field width, vertical spacing, and responsive stacking;
- stable placement that does not jump when a validation message appears.

Field Shell does not imply an extra visible container. It supplies structure to
Text, Number, Path, and Dropdown fields while allowing the underlying control to
retain its own interaction contract.

Product views provide product wording and validation results. They do not
locally rebuild label and error layout.

## Text Field

Text Field accepts editable single-line text. Confirmed uses include naming
patterns, fallback marker names, import destinations, and structure-name
patterns in ReaAssetFlow.

Its specification must cover:

- empty, filled, focused, disabled, read-only, and invalid states;
- placeholder use without treating placeholder text as a label;
- commit and change-event semantics;
- maximum-length and character-policy messages supplied by Product;
- long-value scrolling and complete-value access;
- token insertion without losing the active value or selection where supported;
- DS008 width behavior.

Search and multiline editing are not Text Field variants in the initial
inventory.

## Integer Number Field

Integer Number Field accepts an integer value. The confirmed use is a target
revision in ReaProjectLink.

Its specification must distinguish:

- the editable text buffer from a successfully parsed value;
- incomplete, invalid, out-of-range, and committed states;
- optional minimum and maximum constraints;
- manual entry from optional step controls;
- when validation occurs and whether an invalid value can leave the field.

Floating-point, unit-bearing, slider, and expression inputs are not approved by
this family. Product code owns the meaning and allowed range of the number.

## Path Field

Path Field is one family with File and Folder variants. It combines a path value
with an explicit Browse action when the host can provide one.

Confirmed modes are:

- editable path plus Browse;
- read-only selected path plus Choose or Change;
- file selection with a product-supplied file type or validation rule;
- folder selection with a product-supplied root or containment rule.

The component owns field composition, full-value access, truncation, Browse
placement, and generic invalid or unavailable presentation. Product code owns
the picker implementation, allowed location, normalization, existence checks,
and consequences of changing the path.

A displayed path remains copyable or otherwise inspectable in full. Narrow
layouts stack the Browse action when an inline arrangement is no longer usable.

## Checkbox

Checkbox represents an independent boolean choice. Confirmed uses include
timeline-mirroring and Review options in ReaProjectLink.

The visible label is part of the activation target where the host permits it.
The contract covers checked, unchecked, focused, disabled, and invalid states.
An indeterminate state is not included until a confirmed workflow needs it.

A Checkbox is not replaced with a Switch merely for appearance. A future Switch
would require a distinct immediate-effect meaning and workflow evidence.

## Dropdown

Dropdown selects one value from a set that is not best shown as simultaneous
choices. Confirmed uses include ReaProjectLink lane selection and ReaAssetFlow
scope, conflict policy, WorkUnit, target, preset, and object-type selection.

When placed in a Field Shell, the resulting composition may be described as a
Select Field. Dropdown remains the low-level Component name established by
DS011.

The contract covers:

- static and dynamically loaded options;
- selected, unselected, focused, disabled, and invalid states;
- loading, empty, query-failed, and refreshed option sets;
- a stored value that is no longer present in the available options;
- long labels and complete-value access;
- optional descriptions that explain consequences without being encoded into
  the option value.

Searchable selection and multi-selection are not initial variants.

## Segmented Control

Segmented Control presents a small set of short, mutually exclusive choices
that benefit from simultaneous visibility. Confirmed uses include theme choice,
parent choice, and reviewed revision choice in ReaProjectLink.

It is not a substitute for every Dropdown. Options must fit the available width
without ambiguous truncation. The control wraps or changes to another approved
composition only through a documented responsive rule.

The contract covers selected, unselected, focused, disabled, and invalid states.
DS004 does not require a custom single-tab-stop arrow-key model in the first
version.

## Single Selection List

Single Selection List displays multiple rows and maintains one active row.
ReaAssetFlow uses it to select a structure row for editing.

The List owns selection presentation, row hit areas, focus, empty state,
overflow, and the relationship between selected and focused rows. Product code
owns row data and what editing the active row means.

The initial family does not include multiple selection, drag reordering,
tree-grid behavior, or spreadsheet editing. Ordered movement remains explicit
through the Ordered List Editor Pattern.

## Required states

Every applicable input specification considers:

- empty and populated;
- default, hover, focused, pressed, and disabled;
- read-only where semantically valid;
- valid, invalid, and validation-pending;
- loading, empty-data, failed-data, and stale-value for dynamic choices;
- Compact, Standard, and Wide behavior under DS008;
- both rebuilt themes and DS003 contrast;
- DS004 keyboard and visible focus behavior.

A family omits a state only when that state has no coherent meaning for the
control, not because the current implementation has not drawn it yet.

## Confirmed multi-component Patterns

Cross-product evidence confirms these Pattern responsibilities:

- Ordered List Editor;
- Token Insert Group;
- Path Selection composition;
- Preset Manager;
- Hierarchy Preview;
- External Operation Status.

They are not additional primitive inputs. Their specifications compose the
confirmed Components and retain Product-owned data and effects.

## Deferred inputs

The following remain candidates without an initial supported contract:

- Search Field;
- Radio Group;
- Switch;
- multiline editable text;
- floating-point or unit-bearing Number Field;
- Slider;
- date or time input;
- Color Picker;
- drag-and-drop input;
- searchable or multi-select Dropdown;
- multi-selection List.

A deferred input is promoted only through the DS011 criteria and a confirmed
workflow. Product code may temporarily use a direct host control when necessary,
but that use does not silently create a shared contract.

## Product mapping

| Product need | Shared input or Pattern | Product responsibility |
| --- | --- | --- |
| ReaProjectLink target revision | Integer Number Field | Revision validity and loading behavior |
| ReaProjectLink timeline option | Checkbox | Timeline semantics |
| ReaProjectLink lane and revision choices | Dropdown or Segmented Control | Available choices and domain meaning |
| ReaProjectLink selected project path | Read-only Path Field | REAPER project selection and persistence |
| ReaAssetFlow naming patterns | Text Field plus Token Insert Group | Token grammar and expansion |
| ReaAssetFlow project and Originals paths | File or Folder Path Field | Picker, normalization, and Wwise containment rules |
| ReaAssetFlow WorkUnit and target | Dropdown in Field Shell | WAAPI loading, cache, and value validity |
| ReaAssetFlow structure rows | Single Selection List plus Ordered List Editor | Wwise row schema and ordering effects |
| ReaAssetFlow presets | Preset Manager | Serialization, storage, and naming policy |

## Specification and migration order

1. Specify Field Shell and common input states.
2. Specify Text Field, Integer Number Field, Path Field, Checkbox, Dropdown,
   Segmented Control, and Single Selection List.
3. Validate each component independently with both product content sets.
4. Specify the confirmed Patterns over those contracts.
5. Migrate product workflows in small slices without changing domain behavior.
6. Add deferred controls only when new confirmed evidence appears.

No production control or workflow is changed by DS012 itself.
