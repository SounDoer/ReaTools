# Design System Implementation Migration Map

Status: Initial baseline for Milestone 0. No product surface has migrated.

This map assigns current UI code to the target design-system layers and names
the first safe seams for implementation. It prevents existing helper names and
file boundaries from becoming the new public contract by accident.

## ReaProjectLink baseline

| Current area | Current responsibility | Target owner | Initial treatment |
| --- | --- | --- | --- |
| `ui/theme.lua` palettes | Literal and derived colors | Foundations | Keep as the product compatibility facade until rebuilt theme maps are ready |
| `ui/theme.lua` fonts and style stack | Font creation and ReaImGui mapping | Foundations adapter | Replace behind the facade after Gallery validation |
| `ui/components.lua` text helpers | Typography rendering | Foundations adapter | Move by contract, not by direct rename |
| `ui/components.lua` buttons | Action controls | Button and Icon Button | First Component slice after the Foundation spine |
| `ui/components.lua` card, status, notice | Information and containers | Components | Migrate after action and input slices |
| `ui/components.lua` dropdown and segmented | Choice controls | Components | Migrate in Slice 2C |
| `ui/components.lua` menu and group | Menu and Disclosure | Components | Migrate in Slice 2D |
| `ui/components.lua` page, width, alignment, clipping | Layout mechanics | Internal utilities | Keep non-public unless promotion criteria are met |
| `ui/components.lua` toast | Feedback composition | Candidate Component and Pattern | Keep behind compatibility until its contract is approved |
| `ui/views/settings.lua` | Product settings composition | Product using shared Components | First product migration pilot |
| Review view modules | Domain content and actions | Product using Review Patterns | Migrate one representative Review after Settings |
| `ui/view_models.lua` | Pure product presentation decisions | Product | Preserve; shared Components consume its semantic state |
| `ui/workflow.lua` and services | Product behavior and effects | Product | Never move into Components or Patterns |

Direct ReaImGui calls inside Product views remain migration evidence. They are
removed only when the corresponding shared contract exists; they are not
mechanically wrapped in advance.

## ReaAssetFlow baseline

The current panel is concentrated in `scripts/rtw_panel.lua`. Shared adoption
must create presentation seams without moving Wwise, WAAPI, filesystem,
rendering, LLM, or preset behavior into the design system.

| Current panel area | Target shared responsibility | Product responsibility retained |
| --- | --- | --- |
| Labeled text entry helpers | Field Shell and Text Field | Naming grammar and validation policy |
| Editable path plus Browse | File or Folder Path Field | Picker, normalization, containment, and persistence |
| Combo helpers | Dropdown in Field Shell | Option loading and Wwise meaning |
| Naming token buttons | Token Insert Group | Supported tokens and expansion |
| Structure row list and movement actions | Single Selection List and Ordered List Editor | Row schema and hierarchy effect |
| Structure preview tree | Hierarchy Preview | Wwise object rules and preview data |
| Preset controls | Preset Manager | Serialization, storage, and naming policy |
| Transfer status text | External Operation Status | Render, process, WAAPI, and retry behavior |

ReaAssetFlow remains read-only during the reference implementation. Its labels,
paths, long values, loading states, and hierarchy shapes are represented by
deterministic Gallery fixtures before integration begins.

## Foundation spine introduced in Milestone 1

The initial implementation adds three boundaries without changing a product
view:

1. typed nested Token data with canonical IDs;
2. pure validation and resolution independent of ReaImGui;
3. a narrow ReaImGui adapter exercised first by the development Gallery.

`ui/theme.lua` remains the active ReaProjectLink product facade. The new adapter
does not become product-active until its token inventory and visual matrix are
ready for the Settings pilot.

The current files are:

- `ui/design_tokens.lua` for typed Token data, validation, canonical IDs, and
  theme-aware resolution;
- `ui/design_adapter.lua` for the first font, color, and spacing mappings into
  ReaImGui;
- `tests/design_system_gallery.lua` for the side-effect-free Gallery shell;
- `tests/ReaProjectLink_DesignSystemGallery.lua` for the development ReaScript
  entry point;
- `tests/ui_design_tokens_spec.lua` and `tests/ui_design_adapter_spec.lua` for
  the initial structural checks.

## Initial compatibility boundary

Short names such as `accent`, `muted`, `bg`, and `blocked_bg` remain historical
product-facing compatibility names. They are not aliases in the canonical
Token registry. Their eventual mapping and removal version are recorded when a
product surface first migrates.

No compatibility alias is added merely to make the Gallery resemble the old
theme.

## First migration slice

Button and Icon Button now have a contract, tokens, reference implementation,
Gallery matrix, structural tests, and contrast checks. They replace no product
call site until manual keyboard-focus validation is complete.

Field Shell, Text Field, Integer Number Field, and File and Folder Path Field now
have the same reference boundaries, automated checks, responsive layouts, and
Light and Dark Gallery frames. Their fixtures exercise both products' naming,
revision, project-file, Originals-folder, long-value, validation, disabled, and
read-only shapes without changing `scripts/rtw_panel.lua`. Manual native input,
step, picker-handoff, and focus checks remain open before Slice 2B can be used
as a migration boundary.

Checkbox, Dropdown, Segmented Control, and Single Selection List now have
reference contracts, automated checks, and both-theme Gallery fixtures for
ReaProjectLink settings and revision content plus ReaAssetFlow policy,
WorkUnit, target, and structure-row content. Dynamic and stale data remain
Product-owned inputs, and neither product has adopted the new Components yet.

Card, Status, Notice, Menu, and Disclosure now have reference contracts,
automated checks, and both-theme Gallery fixtures. Existing product cards,
feedback, menus, and groups remain behind the compatibility facade until manual
inspection and a later product migration slice; Toast remains a candidate and
is not silently promoted by Notice.

After the action slice, Settings is the first product pilot because it exercises
choice, boolean, diagnostic, path, and destructive-entry concerns without
changing Publish, Import, Update, or Synchronize behavior.
