# ReaAssetFlow UI Inventory

Status: Read-only cross-product audit completed on 2026-10-12. This inventory
supports DS012 and later component specifications; it does not change the
ReaAssetFlow implementation.

ReaAssetFlow is a second real consumer for the shared REAPER-tool design
system. Its Transfer Panel exercises form entry, path selection, ordered
structure editing, hierarchical preview, presets, and long-running external
workflow feedback that are not all present in ReaProjectLink.

The inspected implementation is `scripts/rtw_panel.lua` in the separate
ReaAssetFlow repository. Product behavior remains governed by that repository's
README and PRD.

## Product context

The panel supports two connected workflows:

- build naming patterns from REAPER Track, Marker, Region, and index tokens;
- configure and preview a structured transfer into a Wwise project through
  WAAPI.

The current UI is one ReaImGui panel with major sections for Auto Renamer,
presets, Wwise project and media, WorkUnits and import target, Wwise structures,
preview, transfer, status, and development actions.

Wwise, WAAPI, WorkUnit, import destination, object structure, Auto Renamer, and
Transfer are Product concepts. They provide evidence for generic Components and
Patterns but do not enter the shared component API.

## Current control evidence

| Current UI need | Current implementation | Shared-system implication |
| --- | --- | --- |
| Naming and structure patterns | Single-line `InputText` | Text Field is required now |
| Wwise project and Originals folder | Editable text input plus Browse button | File and Folder Path Field variants are required now |
| Index scope and missing-marker behavior | Combo boxes | Dropdown or Select is required |
| Conflict policy | Combo plus explanatory text | Select Field with description is required |
| WorkUnit, target, preset, and object type | Combo boxes | Long-label selection and loading or empty states must be specified |
| Structure row selection | `Selectable` rows | Single-selection List is required |
| Structure editing | Add, Delete, Move Up, Move Down, then edit selected row | Ordered List Editor is a required Pattern |
| Token insertion | Small buttons that append tokens to an active field | Token Insert Group is a required Pattern over Button and Text Field |
| Structure preview | Tree nodes and leaf text | Disclosure or Tree composition must support hierarchy preview |
| Presets | Select, save, load, and delete actions | Preset Manager is a confirmed Pattern candidate |
| Transfer status | Persistent wrapped status region | Status and Notice contracts must support ongoing external work |
| Risk confirmation | Native message boxes for deletion, collisions, and multi-track risk | DS013 covers both Inline Review and isolated confirmation |
| LLM and preset prompts | Native `GetUserInputs` dialogs | Dialog form needs are real, but a shared dialog form is not yet approved |

## Combined essential input inventory

Across ReaProjectLink and ReaAssetFlow, the smallest evidence-backed input set
is now:

- Field Shell;
- Text Field for single-line free text;
- Integer Number Field;
- File Path Field;
- Folder Path Field;
- Checkbox;
- Dropdown or Select Field;
- Segmented Control;
- single-selection List.

Field Shell is the common contract for label, optional description, required
state, validation message, disabled state, and width behavior. It is not a
separate visible box when the underlying control does not need one.

File and Folder Path Fields compose editable text with an explicit Browse
action. The contract must also support read-only selection mode for workflows
such as ReaProjectLink Settings where direct path editing is undesirable.

Dropdown and Select Field share single-choice semantics. Their final
specification should decide whether one contract can cover compact fixed choices
and longer dynamically loaded choices without hiding loading, empty, stale, or
invalid stored values.

## Confirmed pattern evidence

The following are multi-component Patterns rather than new low-level inputs:

- Ordered List Editor: selectable rows plus Add, Delete, Move Up, Move Down,
  and an editor for the active row;
- Token Insert Group: token buttons append a valid token to an associated Text
  Field;
- Path Selection: Path Field plus file or folder browser and validation;
- Preset Manager: select, save, load, delete, and confirmation behavior;
- Hierarchy Preview: Disclosure or Tree composition with leaf items and path
  context;
- External Operation Status: current activity, result, error, and recovery
  actions for Wwise or another external service.

These Patterns may be specified when their owning component contracts and
confirmed product workflows are addressed. Their presence does not authorize a
generic workflow engine.

## Inputs without current evidence

Neither audited product currently requires a shared contract for:

- Search Field;
- Radio Group;
- Switch;
- multiline editable text;
- Slider;
- date or time input;
- color picker;
- drag-and-drop input.

They remain candidates. A familiar control is not added merely because a UI
library offers it.

## Additional component implications

ReaAssetFlow adds evidence beyond input controls:

- Section and Form layout need consistent grouping and responsive behavior.
- Button groups must wrap under DS008 rather than continue indefinitely on one
  line.
- Long paths and Wwise object names need the DS009 copy and truncation rules.
- Dynamically loaded choices need loading, empty, refresh, and stale-value
  states.
- Destructive Delete and potentially destructive Replace behavior must consume
  the DS005 danger intent.
- Preview hierarchies and ordered lists need explicit selection, focus, and
  empty-state treatment.
- External calls need DS010 static activity feedback before any spinner is
  considered.

## Product boundary

The shared system may provide fields, lists, buttons, status, confirmation,
hierarchy display, and the Patterns above. It does not define:

- naming-token meaning or expansion;
- Wwise object types or path syntax;
- WAAPI connection and cache behavior;
- import conflict semantics;
- structure-row defaults;
- render or transfer execution;
- LLM prompts and model choice;
- preset storage format.

Those responsibilities remain in ReaAssetFlow Product code and documentation.

## DS012 impact

The earlier ReaProjectLink-only proposal treated Text Field and Path Field as
future candidates. ReaAssetFlow demonstrates current production workflows for
both, so DS012 includes them in the initial specification set.

Search, Radio Group, Switch, multiline text, and specialized pickers remain
deferred. Ordered List Editor and Token Insert Group enter the Pattern backlog
without being mislabeled as primitive inputs.
