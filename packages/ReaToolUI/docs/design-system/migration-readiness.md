# Product Migration Readiness

Status: the complete ReaProjectLink presentation migration is implemented on
2026-10-13 under explicit Product-owner authorization. Automated product,
UI-frame, and self-contained release checks pass. Native pointer, keyboard,
focus, and display-scale validation remains open and is not inferred from
automation.

This record separates verified implementation readiness from the visual and
interaction evidence that still requires a real REAPER window. Passing the
automated column does not waive a manual gate.

## Shared boundary

`packages/ReaToolUI/lib/reaui.lua` is the public construction entry point for a
ReaImGui consumer. It returns one adapter plus named Component and Pattern
families. Product views consume those semantic APIs rather than requiring
individual implementation modules or Primitive tokens.

`packages/ReaToolUI/lib/reaui/design_contract.lua` is the machine-readable
development contract record.
It lists the supported catalog, ReaImGui API target, theme names, and consumer
declaration validation. The contract remains `development` with no semantic
version; this is not a premature `0.1.0` release.

Each catalog entry also records its canonical ID, implementation module,
factory key, specification path, and permanent Gallery fixture marker.
Conformance checks fail when an entry loses any of those links, consumes a
Primitive token directly, or embeds a raw color literal outside the token
registry.

A consumer declaration will require:

- schema version and exact contract status or published version;
- traceable shared implementation revision;
- adapter name and ReaImGui API target;
- an explicit Product-exception list, including an empty list;
- the latest migration note when one exists.

## Settings pilot mapping

| Existing Settings responsibility | Shared target | Product responsibility retained | Automated readiness |
| --- | --- | --- | --- |
| Back header | Review Header | navigation effect | Ready |
| Project and diagnostic values | product composition; candidate Key Value Row remains deferred | value lookup and copy behavior | Compatibility boundary required |
| Reference path and Choose/Change | Path Selection | picker, validation, subscription effect | Ready |
| Mirror Master Timeline | Checkbox in Field Shell | project value and alignment service call | Ready |
| Theme preference | Segmented Control | preference persistence; rebuilt theme values | Ready |
| Reset explanation and trigger | Button plus Confirmation Dialog | reset service, exact consequence, outcome | Ready |
| Page width and sections | internal layout composition | section labels and ordering | Ready |

The existing copy-value rows remain behind the named Product compatibility boundary
because Key Value Row has not met the DS011 promotion gate. The Settings pilot
must not silently promote it or replace copying with a less capable text label.

The migrated page consumes the listed shared targets. Product composition was
designed at the Settings call site; the provisional Cross-product Gallery
fixture was not copied into the product.

## Representative Review pilot mapping

Delivery Publish Review is the representative Review composition because it exercises
blockers, warnings, decisions, stale state, details, primary completion, long
content, and confirmation while retaining existing service and workflow tests.

| Existing responsibility | Shared target | Product responsibility retained | Automated readiness |
| --- | --- | --- | --- |
| Back, title, summary | Review Header | revision and count text | Ready |
| Stale replacement | Stale Review through Review Shell | change-count detection and rebuild | Ready |
| Blockers and warnings | Notice | issue generation, selection, acknowledgment | Ready |
| Reference declaration | Segmented Control | declaration options and stored decision | Ready |
| Lane details | Disclosure | lane, clip, FX, and issue data | Ready |
| Footer summary and Publish | Review Footer | blocker count and publish effect | Ready |
| Removed/unprocessed confirmation | Confirmation Dialog or already-complete Inline Review | consequence and continuation policy | Ready |

The pilot must preserve the existing priority order: Back, stale refresh,
decision-triggered rebuild, then Publish. Semantic events are translated at the
Product boundary; the shared Pattern does not call workflow or services.

## Complete product mapping

Setup, Source, Master, all Review variants, Settings, notices, menus, statuses,
Toast, and confirmation flows now run under one ReaToolUI base style. Shared
controls and Patterns are called directly through the design-system family.
Grouped Lane mapping, virtualized domain lists, key/value rows, and card
composition remain named Product helpers because no promoted shared contract
matches their complete behavior. Those helpers resolve ReaToolUI tokens and do
not own palettes, fonts, or a parallel style stack.

## Automated evidence

- canonical token validation, theme parity, contrast, adapter stack balance,
  and public module loading pass;
- Component and Pattern state, invalid-combination, responsive, and semantic
  event checks pass;
- deterministic Gallery smoke frames pass in Light and Dark for Foundations,
  Components, Patterns, Cross-product Scenarios, and Diagnostics where
  applicable;
- all 40 ReaProjectLink product UI smoke scenarios pass, covering Setup,
  Source, Master, Settings, and every Review at 320 px and 1040 px;
- focused Settings routing tests preserve picker subscription, alignment mode,
  theme persistence, Back, destructive confirmation, reset, and recheck effects;
- the ReaProjectLink release inventory contains the vendored ReaToolUI entry and
  the product entry resolves that self-contained runtime path;
- ReaAssetFlow product presentation remains unchanged. Its monorepo package,
  setup diagnostics, stable user-data boundary, and UI smoke are now validated
  independently of the design-system adoption gate.

## Remaining native validation

Record the applicable DS016 manual cells for Button, Icon Button, Field Shell,
Checkbox, Segmented Control, Path Selection, Confirmation Dialog, Notice,
Disclosure, Review Shell, Stale Review, Footer, and long-content behavior in a
visible REAPER session.

The focused Settings checklist is
[`validation/2026-10-13-reaprojectlink-settings-pilot.md`](validation/2026-10-13-reaprojectlink-settings-pilot.md).
The earlier complete-page candidate remains only a provisional integration
fixture. It is not the migrated product composition and does not provide native
acceptance evidence.

Required checks include both rebuilt themes; compact, standard, and wide
widths; focus and disabled presentation; pointer and ordinary native keyboard
behavior; long text and paths; modal Cancel, Escape, close, and safe default
focus; fixed-footer scrolling; and supported display scales. Unavailable scales
are recorded as blocked, not passed.
