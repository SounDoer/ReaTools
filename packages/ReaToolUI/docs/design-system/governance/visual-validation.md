# Visual Validation and Regression Strategy

Status: Confirmed by DS016 on 2026-10-12.

The first design-system version combines automated structural checks with a
recorded manual visual and interaction matrix in the DS015 Component Gallery.
Pixel-based screenshot comparison is not a release gate until a controlled
experiment demonstrates stable capture and acceptable maintenance cost.

This strategy treats automation and visual review as complementary. Structural
tests catch invalid contracts consistently; human inspection catches rendering,
hierarchy, wrapping, focus, and perceptual problems that the first automated
layer cannot judge reliably.

## First version release gate

A design-system implementation change is complete only when:

1. relevant automated structural and behavior checks pass;
2. affected Gallery fixtures and states are current;
3. the required manual matrix is completed for the affected scope;
4. failures and accepted limitations are recorded;
5. no unresolved release-blocking mismatch remains between specification,
   Gallery, and product integration.

Screenshot baselines are not required for this gate in the first version.

## Automated structural checks

Automated checks should cover deterministic rules that do not require judging
rendered pixels:

- canonical token ID syntax and layer ownership;
- missing references, invalid reference direction, and alias cycles;
- complete Light and Dark Semantic maps;
- DS003 contrast calculations for declared foreground and background pairings;
- use of approved DS006 scale and optical exception categories;
- component variant and state enumeration;
- required specification and Gallery fixture registration;
- semantic event outputs for deterministic component interactions;
- invalid property combinations and documented defaults;
- static detection of prohibited raw visual literals where practical;
- syntax loading and supported ReaImGui API compatibility;
- deterministic layout-range and state-selection helpers;
- product adapter tests that do not require external services.

Structural checks do not claim that a component looks correct. A passing token
map can still produce poor hierarchy, clipping, confusing focus, or awkward
wrapping.

## Behavior checks

Where component logic can be separated from rendering, automated behavior tests
cover:

- enabled, disabled, selected, read-only, loading, and invalid transitions;
- parsing and committing input values;
- stable selection across refresh, sorting, and deletion;
- prevention of duplicate activation;
- semantic event emission without product side effects;
- confirmation cancellation and execution state;
- responsive mode selection at documented logical boundaries;
- deterministic fixture generation.

Pointer coordinates, font rasterization, and full rendered interaction remain
in the Gallery validation layer unless a stable host-level harness is later
approved.

## Manual Gallery matrix

The manual matrix is fixed and recorded rather than an informal visual glance.
The complete initial matrix includes:

| Dimension | Required values |
| --- | --- |
| Theme | Light, Dark |
| Page layout | Compact, Standard, Wide |
| Local component width | Below, at, and above each transformation boundary |
| Content | Empty, short, typical, long, path, technical, enabled-language samples |
| Condition | Neutral, ready, warning, blocked, danger where applicable |
| Interaction | Default, hover, pressed, focused, selected, disabled, read-only |
| Async state | Loading, success, failure, cancelled, stale, partial where applicable |
| Display scale | 100%, 125%, 150%, 200% where the validation host supports them |
| Input method | Pointer and keyboard for applicable controls |
| Product fixture | ReaProjectLink and ReaAssetFlow representative compositions |

Not every Cartesian-product combination must be repeated when it cannot reveal
a distinct behavior. Each Component specification identifies its applicable
subset, but both themes, focus, long content, and relevant width boundaries are
never omitted.

## Manual inspection criteria

Reviewers check:

- visual hierarchy and one clear primary action;
- token-consistent color, typography, spacing, size, shape, and iconography;
- DS003 contrast and non-color meaning;
- clear hover, pressed, focus, selected, disabled, loading, validation, and
  danger distinctions;
- readable wrapping and complete-value access;
- no clipping, overlap, unstable reflow, or unreachable action;
- sensible Compact, Standard, and Wide composition;
- structured-data priority and column-to-stack behavior;
- dialog focus, cancellation, wording, and execution state;
- typography and icon clarity at available display scales;
- no product side effects from Gallery interaction.

Any mismatch is classified as specification, shared implementation, Gallery
fixture, product integration, host limitation, or accepted platform variation.

## Validation record

Each recorded run includes:

- date and reviewer;
- design-system contract version once the implementation publishes one under
  DS017;
- implementation revision or commit;
- product adapter revision when integration is in scope;
- operating system and version;
- REAPER and ReaImGui versions;
- font-family resolution when observable;
- display scale and monitor configuration;
- theme, width, component, and state scope;
- pass, fail, not applicable, or blocked result;
- issue link or concise note for every non-pass result.

The record lives with the development or release validation artifacts chosen by
the implementation workflow. It does not store user projects, credentials, or
machine-specific production data.

## Platform scope

Validation follows declared product support rather than assuming every product
supports the same operating systems.

- ReaAssetFlow currently requires Windows validation.
- ReaProjectLink and the shared implementation are validated on every platform
  they declare supported when that support is defined.
- A cross-platform Component change must not claim platform conformance from a
  Windows-only Gallery run.

Unavailable hardware or display scales are recorded rather than silently
reported as passing. Release policy later decides which unavailable matrix cells
block a release.

## Screenshot stability experiment

Screenshot comparison may be proposed after the Gallery implementation exists.
The experiment uses:

- one controlled host configuration at a time;
- pinned REAPER, ReaImGui, operating-system, font, theme, and GPU-rendering
  environment where practical;
- fixed DS002 logical viewport dimensions;
- deterministic DS015 fixtures and component states;
- no clocks, cursors, transient hover, animation, or external data;
- identical capture and image-processing steps.

For each candidate scene, capture at least five consecutive runs and repeat the
set after restarting REAPER. A scene is eligible only when identical inputs
produce either pixel-identical output or a small, localized, repeatable variance
that can be explained and bounded without masking component content.

Masks may exclude known diagnostic values such as an intentionally displayed
runtime version. They do not hide text, component boundaries, focus, icons,
status, or content that the regression is meant to protect.

The experiment records:

- changed-pixel count and percentage;
- maximum and aggregate channel difference;
- spatial distribution of differences;
- whether variation is deterministic across sessions;
- capture duration and storage cost;
- expected baseline-update frequency;
- false-positive examples and missed visual defects.

No universal tolerance is chosen before this evidence exists.

## Conditions for adopting screenshot comparison

Screenshot comparison becomes a release supplement only after review confirms:

- the capture process is reproducible on its declared host scope;
- tolerances distinguish real regressions from normal raster variation;
- baselines identify their platform, font, DPI, theme, and version context;
- baseline changes receive explicit visual review rather than automatic update;
- required tooling is maintainable and any new dependency has prior approval;
- failures link back to a deterministic Gallery scene;
- the benefit exceeds storage, CI, and review cost.

Adoption may begin with a small high-value subset such as Button, Field Shell,
focus treatment, Confirmation Dialog, and representative structured rows. It
does not need to capture every permutation immediately.

Screenshot comparison supplements rather than replaces token, behavior,
contrast, keyboard, and manual review. Pixel stability cannot prove semantic
correctness.

## Baseline governance

If screenshot comparison is adopted later:

- each baseline records the exact environment and Gallery scene ID;
- expected visual changes update specifications or decisions first when meaning
  changes;
- baseline updates appear as reviewable artifacts;
- one platform baseline does not silently approve another platform;
- obsolete baselines are removed through the same versioned change;
- product-specific scenes remain distinct from shared component baselines.

## Failure handling

A failed structural test blocks completion until fixed or the governing
contract is explicitly changed. A failed manual cell is recorded with enough
environment detail to reproduce it.

Host-specific rendering variation may be accepted only when it preserves the
component contract and is documented. The label `flaky` is not a substitute for
investigating a repeated visual or interaction mismatch.

No test dependency, screenshot harness, or production behavior is added by
DS016 itself.
