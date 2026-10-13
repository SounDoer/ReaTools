# Path Field Contract

Status: Initial Slice 2B contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual native editing,
selection, copying, horizontal scrolling, focus, and picker-event handoff remain
open before product migration.

Path Field combines one inspectable path value with an explicit request to
choose a File or Folder. It supports editable and read-only selection modes for
ReaProjectLink, ReaAssetFlow, and future REAPER tools without owning a native
picker or filesystem policy.

## Responsibility

The component owns Field Shell composition, path text editing or read-only
selection, complete-value access, Browse action placement, validation
presentation, responsive reflow, and semantic events.

Product code owns picker execution, supported file types, initial picker
location, path normalization, existence and permission checks, allowed roots,
containment, persistence, and every consequence of changing the path. The
component never reads the filesystem and does not reinterpret separators.

## Variants and inputs

`kind` is required and is either `file` or `folder`. It communicates picker
intent in the Browse event; it does not perform validation by itself.

The component accepts the common Field Shell inputs plus:

- `value`: the current path string, defaulting to empty;
- `placeholder`: an optional expected shape or example;
- `read_only`: keeps the path selectable and copyable while preventing edits;
- `disabled`: makes the entire field unavailable;
- `browse_disabled`: disables only the Browse action when the host cannot
  currently provide selection;
- `browse_label`: optional product wording, defaulting to `Browse...`.

Disabled and read-only cannot both be true. A read-only field may still offer
Choose, Change, or Browse because selecting a replacement is distinct from
editing the path text. Products supply pending, valid, invalid, or unavailable
messages through the standard Field Shell validation input.

## Output and events

The result contains the current `value`, `changed`, `committed`,
`browse_requested`, ordered `events`, and the resolved `inline` or `stacked`
layout.

Editable text uses `field.changed` and `field.committed` with `id`, `value`, and
`kind`. Browse emits `path.browse_requested` with the same identity, current
unmodified value, and File or Folder kind. The Product responds to this event
and supplies any selected path on a later frame.

Read-only and disabled text emit no edit events. Disabled or browse-disabled
actions emit no Browse event. If text interaction and Browse happen in one
frame, text events precede the Browse request.

## Layout and long paths

In a sufficiently wide parent, the path input and Browse action share one row.
The input receives the remaining width while preserving a minimum usable entry
area. Below the Component token threshold, the input stays full width and the
Browse action moves below it at full width. The component uses available parent
width, not a global window classification.

Editable and read-only values use native horizontal text scrolling and remain
selectable so a long Windows, macOS, Linux, NAS, or Wwise-like path can be
inspected and copied in full. The stored value is never shortened to its visual
display and the component does not insert ellipses into it.

## Content guidance

Labels name the selected resource, such as `Wwise project` or `Originals
folder`. File extensions, allowed roots, or consequences belong in description
or recovery text. Choose or Change wording may clarify a read-only workflow;
`Browse...` is the neutral default for editable paths.

## Validation

Automated checks cover File and Folder variants, editable and read-only modes,
event order and payloads, disabled action boundaries, invalid presentation,
long-value preservation, responsive reflow, and invalid option combinations.
Gallery fixtures cover both products, long NAS and Wwise-like paths, empty,
disabled, read-only, pending, valid, and invalid states in both themes. Manual
validation covers native editing, selection, copying, horizontal scrolling,
focus, and picker-event handoff before product use.
