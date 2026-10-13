# Field Shell and Text Field Contract

Status: Initial Slice 2B reference implementation completed on 2026-10-12.
Automated Light and Dark Gallery frames pass. Manual native editing, selection,
copying, horizontal scrolling, and focus inspection remain open before product
migration.

Field Shell provides the repeated structure around an input: its visible label,
optional description, requirement indication, control slot, and validation
message. Text Field supplies editable single-line text inside that structure.
They are separate responsibilities so future Number, Path, and Dropdown fields
can reuse the same surrounding language and layout.

## Field Shell responsibility

Field Shell owns:

- one required visible label;
- an optional `required` or `optional` indication;
- optional descriptive or instructional text;
- one control slot with a stable ReaImGui identity;
- validation-pending, valid, and invalid message presentation;
- a reserved minimum message line so validation does not move following fields
  when a one-line message appears;
- full-width field layout within the width supplied by its parent.

Field Shell does not draw an extra card or border. It does not validate a value,
choose product wording, execute Browse behavior, or decide whether a field is
required.

## Text Field responsibility

Text Field accepts and returns one single-line string. Confirmed examples are
ReaAssetFlow naming patterns, marker fallbacks, import destinations, and
structure-name patterns.

Text Field does not provide search, multiline editing, rich text, token parsing,
path selection, or numeric parsing. Those remain distinct Components or
Patterns.

## Public inputs

The Field Shell inputs used by Text Field are:

- `id`: required stable identity in the current ReaImGui scope;
- `label`: required visible label;
- `description`: optional supporting text;
- `requirement`: omitted, `required`, or `optional`;
- `validation`: optional `{ state, message }` value;
- `reserve_message`: optional boolean, defaulting to true.

Validation state is `pending`, `valid`, or `invalid`. Invalid state requires a
recovery-oriented message. Pending and valid may omit a message when another
persistent cue already explains the state.

Text Field additionally accepts:

- `value`: current string, defaulting to empty;
- `placeholder`: optional example or format hint;
- `disabled`: optional boolean;
- `read_only`: optional boolean.

Disabled and read-only cannot both be true. Disabled means unavailable and does
not participate as a usable action. Read-only remains selectable and copyable
but cannot change. Placeholder text never replaces the visible label.

Product code supplies length, character, naming-token, path, and domain policy
through the `validation` value. The first Text Field contract does not silently
truncate or rewrite user input.

## Output and events

Each frame returns the current value plus zero or more semantic events:

```text
{
  value = <current string>,
  changed = <boolean>,
  committed = <boolean>,
  events = {
    { type = "field.changed", id = <id>, value = <string> },
    { type = "field.committed", id = <id>, value = <string> }
  }
}
```

`field.changed` reports an editable value change during input.
`field.committed` reports that an edited native input was deactivated after an
edit. A frame may emit both in that order. Disabled and read-only fields emit no
change or commit event.

The Product decides whether to store every change, wait for commit, validate
asynchronously, or reject a committed value.

## States

The initial states are:

- empty and populated;
- default, hovered, active or focused;
- disabled;
- read-only;
- validation pending;
- valid;
- invalid.

The active native input uses the shared focus treatment. Invalid state adds a
semantic invalid border and message without replacing focus. Disabled treatment
uses the host disabled behavior and does not need to meet the ordinary text
contrast minimum. Read-only retains ordinary readable text contrast.

## Layout and long values

Text Field fills the content width provided by Field Shell. Compact, Standard,
and Wide parent layouts change that available width; Text Field does not inspect
the global window range.

Long values use native horizontal text scrolling while editing. Read-only values
remain selectable so the full value can be inspected or copied. Labels,
descriptions, and validation messages wrap vertically rather than clipping.

The reserved validation line is a minimum. A longer recovery message may grow
the Field Shell vertically; it is not truncated merely to preserve height.

## Content guidance

- Labels name the value, not the instruction: `Naming pattern`, not `Enter a
  naming pattern here`.
- Descriptions explain format or consequence only when the label is
  insufficient.
- Placeholder text shows an example or expected shape and is never the only
  explanation.
- Invalid messages state the problem and recovery when possible.
- Required or optional indication is shown only when the distinction helps the
  current form; a form where every field is required need not repeat it.

## Tokens

Field Shell uses Component tokens for label, description, and validation-message
foregrounds. Text, Number, and Path fields share input-control Component tokens
for background states, foreground, and default or invalid borders. Shared
height and focus remain Semantic responsibilities.

Product code cannot pass visual colors, padding, control height, or border
values to either component.

## Validation

Automated checks cover required inputs, requirement and validation enums,
reserved message height, placeholder routing, change and commit event order,
disabled and read-only suppression, style-stack balance, token integrity, and
contrast.

Gallery fixtures cover empty, populated, placeholder, description, required,
optional, disabled, read-only, pending, valid, invalid, long value, and long
message cases using both ReaProjectLink and ReaAssetFlow content shapes. Manual
validation confirms native editing, selection, copying, horizontal scrolling,
focus visibility, and both themes before product use.

The current automated reference evidence is 123 ReaToolUI tests plus the
REAPER/ReaImGui smoke check, the complete 30-scenario Gallery matrix, and the
unchanged 40-scenario ReaProjectLink UI smoke matrix. This evidence validates
structure and host compatibility; it does not replace the remaining manual
interaction checks.
