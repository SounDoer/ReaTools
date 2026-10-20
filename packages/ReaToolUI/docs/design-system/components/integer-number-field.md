# Integer Number Field Contract

Status: Initial Slice 2B contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual native editing,
focus, selection, copying, and step activation remain open before product
migration.

Integer Number Field accepts manual whole-number entry while preserving the
exact editable text buffer. Its first confirmed use is the ReaProjectLink target
revision. Product code owns what the number means and which range is allowed.

## Responsibility

The component owns integer syntax parsing, optional minimum and maximum checks,
generic parse state, optional step controls, and Field Shell composition. It
does not load revisions, select a default revision, silently replace invalid
text, or execute a product action.

Floating-point values, units, expressions, sliders, and locale-specific numeric
formats are outside this contract.

## Inputs

The component accepts the common Field Shell inputs plus:

- `buffer`: the current editable string; or
- `value`: an integer used to initialize a valid buffer;
- `minimum` and `maximum`: optional inclusive integer limits;
- `step`: an optional positive integer enabling decrement and increment actions;
- `action`: an optional `{ id, label }` secondary button that acts on the
  value, such as `Load`; it cannot be combined with `step`;
- `disabled` or `read_only`, which cannot both be true;
- `show_parse_message`: whether the component presents its generic parse error;
- optional product wording overrides for incomplete, invalid, and out-of-range
  messages.

`buffer` and `value` cannot be supplied together. A caller that needs invalid or
incomplete text to survive subsequent frames stores the returned `buffer`.

## Parsing and validation

The parse states are:

- `valid`: the buffer contains a whole number within the supplied range;
- `incomplete`: the buffer is empty, `+`, or `-` and could still become valid;
- `invalid`: the buffer is not integer syntax or cannot become a finite integer;
- `out_of_range`: syntax is valid but the parsed value violates a limit.

Leading plus signs and leading zeros are accepted as editable integer syntax.
Products may apply stricter domain rules through the ordinary Field Shell
validation input.

Generic parse messages are opt-in. This prevents a pristine empty field from
showing an error before the Product's chosen validation moment. Invalid input
is allowed to lose focus; a commit event reports its state and the Product
decides whether the workflow may continue.

## Output and events

Each frame returns `buffer`, parsed `value` or `nil`, `parse_state`, `changed`,
`committed`, `action` (the action id on the frame it is pressed), and ordered
semantic events. Change and commit events include the
same buffer, parsed value, parse state, and a source of `input` or `step`.

A manual input may emit `field.changed`, `field.committed`, or both in that
order. A step action is discrete and emits both events immediately. Step
controls are unavailable while the buffer is not valid, at the corresponding
inclusive boundary, or while the field is disabled or read-only. A final step
that would cross a limit lands on that limit.

## Layout and content

The native text input uses the full Field Shell width when no step is supplied.
With step controls, a sufficiently wide parent places the input and two icon
actions inline. A narrow parent keeps the full-width input and moves the step
actions below it. The threshold is a Component token, not a global window
breakpoint. An `action` button follows the same rule: inline after the input
when it fits, otherwise a full-width button below it.

Labels name the value, such as `Target revision`. Descriptions and validation
messages explain product meaning and recovery; the control does not add a unit
or domain noun inside the editable value.

## Validation

Automated checks cover parsing, incomplete and invalid preservation, inclusive
ranges, option validation, event payloads and order, step clamping and blocking,
responsive layout selection, token integrity, and style-stack balance. Gallery
fixtures cover manual entry, incomplete, invalid, out-of-range, bounded step,
disabled, and read-only states in both themes. Manual validation covers native
editing, focus, selection, copying, and step activation before product use.
