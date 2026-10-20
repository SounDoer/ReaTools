# Component and Pattern Architecture

Status: Confirmed by DS011 on 2026-10-12.

The shared UI system has four responsibility layers: Foundations, Components,
Patterns, and Product. Each layer may depend only on the layers below it.

```text
Product -> Patterns -> Components -> Foundations
```

This boundary keeps reusable controls free of ReaProjectLink workflow logic
while allowing recurring Review and feedback structures to be shared without
pretending they are low-level controls.

## Foundations

Foundations provide the design values and platform rules consumed by every
higher layer:

- design tokens and themes;
- color, typography, spacing, sizing, and shape;
- display scaling, density, responsive ranges, focus, and motion policy;
- the ReaImGui adapter that resolves semantic values to host APIs.

Foundations do not render product concepts or expose workflow callbacks. Text
style helpers and raw layout calculations may live in this implementation layer
without being presented as user-facing components.

## Components

A Component is a reusable, independently specifiable interface building block.
It owns its anatomy, variants, states, interaction, accessibility, internal
layout, token use, and emitted UI events.

The initial confirmed shared component families are:

- Button and Icon Button;
- Card;
- Status;
- Notice;
- Dropdown;
- Segmented Control;
- Menu;
- Disclosure.

Existing helpers also provide evidence for future Badge, Key Value Row, Toast,
and layout primitives, but DS011 does not approve their final contracts or
require their implementation. DS012 defines the separate initial input
inventory.

A Component:

- uses generic interface language rather than product nouns;
- accepts content, semantic state, and event handlers or returns UI events;
- never publishes, imports, synchronizes, mutates REAPER, or accesses storage;
- consumes Semantic or Component tokens rather than raw visual values;
- works wherever its documented minimum layout and host requirements are met;
- can be demonstrated and validated independently of a product workflow.

Examples of valid Component APIs are conceptual rather than language-specific:

```text
Button(label, variant, disabled) -> activated
Status(label, condition)
Notice(condition, message, actions) -> chosen_action
Dropdown(label, value, options) -> changed_value
```

An API does not accept `publish_blue`, `delivery_spacing`, or a callback named
after a ReaProjectLink domain operation.

## Patterns

A Pattern composes Components to solve a repeatable interaction or content
structure. It may define slots, ordering, action hierarchy, and state
relationships, but it does not own product data or execute domain behavior.

The initial shared Pattern candidates confirmed by DS011 are:

- Review Shell;
- Review Header;
- Review Footer;
- Stale Review;
- feedback placement and lifetime composition where later specified.

A Review Pattern may require a title, condition summary, issue content,
decisions, detail regions, a completion action, and cancellation behavior. It
does not know what Publish, Delivery, Reference, revision, Track, Marker, Region,
or Item means.

A Pattern is appropriate when the value lies in how components work together.
Turning every internal Button or Notice token into a Review-specific low-level
component would erase that distinction.

## Product

Product views and workflows supply domain content, state, permissions, and
effects. ReaProjectLink Product responsibilities include:

- Source Project and Master Project card contents;
- Reference and Delivery condition priority;
- Lane Mapping options and defaults;
- revision comparison and declaration behavior;
- Publish, Import, Sync, and Synchronize actions;
- REAPER Track, Marker, Region, and Item behavior;
- the decision that the current main panel has two domain cards.

ReaAssetFlow Product responsibilities include naming-token behavior, Wwise
object types and path syntax, WAAPI operations, WorkUnit and target loading,
import conflict semantics, structure defaults, transfer execution, LLM prompts,
and preset storage.

Product code composes Patterns and Components and responds to their UI events.
It does not add local visual variants merely to reproduce one screen.

## Internal utilities

Not every reusable function is a public Component. The following are
implementation utilities or layout infrastructure unless a later specification
promotes them:

- text and button measurement;
- right alignment and available-width calculations;
- list clipping;
- DrawList icon geometry;
- page centering and maximum-width calculations;
- internal stack, inline, and spacing helpers;
- push and pop wrappers for ReaImGui styles.

These helpers still follow foundation tokens and DS002 logical units. Calling a
function reusable does not make its API part of the design-system contract.

## Helper classification (historical)

This table classified ReaProjectLink's `ui/components.lua` as migration input.
The Direction C migration (ReaProjectLink D093) retired most of these helpers;
the file now keeps only Toast, grouped Lane mapping rows, clipped lists, the
page container, and confirmation plumbing. Its capabilities classified as
follows:

| Current capability | Target responsibility |
| --- | --- |
| `title`, `heading`, `muted`, `small` | Foundation typography adapter |
| `button`, `disabled_button` | Button Component |
| `icon_button` | Icon Button Component |
| `begin_card`, `end_card`, `card_header` | Card Component |
| `status`, `inline_status` | Status Component variants |
| `notice` | Notice Component |
| `dropdown` | Dropdown Component |
| `segmented` | Segmented Control Component |
| `menu` | Menu Component composition |
| `begin_group`, `end_group` | Disclosure Component |
| `badge` | Candidate Badge Component |
| `key_value`, `value_row`, `copy_value` | Candidate Key Value Row family |
| `toast_overlay` | Candidate Toast plus feedback Pattern |
| page, width, alignment, measurement, clipping helpers | Internal layout utilities |
| Review header, footer, and stale composition | Review Patterns |

This table determines specification ownership, not an immediate file move or
API rename.

## Promotion criteria

A helper or product composition enters the shared system only when all of these
conditions hold:

1. it represents a repeatable interface responsibility rather than one screen;
2. its purpose can be named without a ReaProjectLink domain term, unless it is
   an explicitly approved shared Pattern such as Review;
3. it has a stable semantic input and event boundary;
4. it can follow shared tokens without product-local visual overrides;
5. its states, accessibility, responsive behavior, and validation can be
   specified independently;
6. at least one confirmed workflow needs it now, or repeated cross-tool use
   provides strong evidence for it.

Code reuse alone is insufficient. Two similar-looking product sections may
remain compositions when they do not share the same meaning and behavior.

## Required component specification

Before a Component becomes a supported contract, its specification records:

- purpose and non-goals;
- anatomy and content slots;
- variants and semantic meaning;
- default, hover, pressed, focused, selected, disabled, loading, and validation
  states where applicable;
- keyboard and pointer behavior under DS004;
- status, danger, and color behavior under DS003 and DS005;
- typography, spacing, sizing, density, and responsive behavior;
- Semantic and Component tokens;
- API inputs, outputs, defaults, and invalid combinations;
- manual and automated validation cases.

A Pattern specification additionally records component composition, reading and
focus order, action hierarchy, state ownership, and the boundary where product
data and effects are supplied.

## API rules

- Public inputs express semantic intent, not ReaImGui color or style flags.
- Variants have documented meaning; they are not arbitrary appearance presets.
- Disabled, loading, selected, condition, and danger are separate properties
  when their meanings differ.
- Components emit interaction results and do not execute domain effects.
- Patterns may coordinate local presentation state but do not mutate product
  data or storage.
- Escape hatches remain internal until a repeated supported need justifies a
  contract.
- A product-specific exception stays in Product and is documented rather than
  widening a shared API prematurely.
- A component that may end with a child window, or with a cursor move before
  one, ends with the internal `layout.settle()`. At startup ReaImGui runs two
  defer cycles in one frame; a child begun twice in a frame submits no item to
  its parent, and ImGui then rejects the parent's trailing cursor move.

## Migration approach

Migration follows contracts rather than a file-first rewrite:

1. specify the confirmed Components used by current workflows;
2. identify the internal utilities each implementation needs;
3. specify Review Patterns over those Component contracts;
4. adapt product views to semantic APIs;
5. separate modules when the responsibility boundary is stable;
6. remove temporary compatibility helpers through an explicit migration.

No production helper, module, or API is moved or renamed by DS011 itself.
