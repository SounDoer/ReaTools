# Development

## Runtime

- REAPER 7.74 or newer with embedded Lua 5.4;
- ReaImGui 0.9-compatible API or newer, installed through ReaPack.

REAPER 7.74 is the minimum because Reference synchronization uses the
ProjectMarker APIs introduced in REAPER 7.62 and `set_config_var_string`, added
in REAPER 7.74, to mirror project timecode and frame-rate state. The main script
checks the REAPER version and required APIs before opening the UI; loading
ReaImGui through its `0.9` compatibility API provides the corresponding UI
version check.

No standalone Lua or Python runtime is required by the REAPER scripts.

## Repository layout

```text
tools/ReaProjectLink/
  ReaProjectLink/               shipped product source
    ReaProjectLink.lua          REAPER action entry point and package metadata
    lib/reaprojectlink/         Lua modules
  tests/                        dependency-free Lua tests run inside REAPER
  docs/                         product and architecture documentation
  reatools-package.json         release inventory and UI contract declaration
packages/ReaToolUI/             shared UI source and development Gallery
tooling/                        repository validation and release automation
```

The release tree contains only the Git-tracked files declared by
`reatools-package.json`. ReaProjectLink is staged as the
`ReaTools/ReaProjectLink` ReaPack category and remains self-contained.
Its complete UI loads the canonical `packages/ReaToolUI/lib` source during
development. The release builder vendors that same pinned package under
`vendor/ReaToolUI/lib`; the installed tool never depends on another tool's UI
copy or a network lookup.

## Development actions

Load these files from REAPER's Action List:

- `ReaProjectLink_Dev.lua` is the distinct development Action and opens a
  window labeled `ReaProjectLink [Dev]`;
- `tests/ReaProjectLink_RunTests.lua` runs the Lua unit tests and reports the
  result in both the REAPER console and a message box;
- `../../packages/ReaToolUI/gallery/ReaToolUI_DesignSystemGallery.lua` opens the
  development-only shared Gallery. It uses deterministic local fixtures and
  does not connect to product services or mutate REAPER project data.

The test action creates and closes an isolated temporary Project Tab. It does not
run adapter mutation tests against the user's active project.

Register `ReaProjectLink_Dev.lua` once with **Actions > Show action list >
New action > Load ReaScript**. The launcher resolves and runs the product entry
from this checkout, so code changes are available the next time the development
Action starts without copying or synchronizing files. It is outside the release
inventory and cannot be installed or overwritten by ReaPack.

The ReaPack-installed Action remains `ReaProjectLink`; its files and vendored
ReaToolUI runtime remain under REAPER's resource path. Keep both Actions
registered, but do not leave both UI instances running at the same time.

## Release

ReaProjectLink is published through ReaPack. Users add this repository once:

```text
https://raw.githubusercontent.com/SounDoer/ReaTools/reapack/index.xml
```

To release:

1. Run `tooling/run_all_tests.ps1` from the monorepo root.
2. In `ReaProjectLink/ReaProjectLink.lua`, bump `@version` and replace
   `@changelog` with this version's notes. Update the matching `version` in
   `reatools-package.json`.
3. Commit and push the validated change to `main`.
4. The deployment workflow builds the declared release tree, validates it,
   publishes the generated `reapack` branch, and regenerates its `index.xml`.

Source and generated distribution therefore stay separate: do not edit the
`reapack` branch or a checked-in legacy `index.xml` by hand. The repository CI
runs the full official `reapack-index --check` with Pandoc; the local validation
runs the same check when both optional tools are installed.

Modules in `lib/reaprojectlink/`, `lib/reaprojectlink/ui/`, and
`lib/reaprojectlink/ui/views/` are covered by the `@provides` globs; a new
subdirectory needs its own `@provides` line. Any other new shipped file must
be added to `@provides`.

The vendored ReaToolUI entry and modules are also declared by `@provides`.
`tooling/test_release.ps1` verifies the runtime entry and vendored load path in
the self-contained release inventory.

## Verification

The automated suite exercises pure domain behavior, in-memory transaction
failures, the real Windows filesystem, real REAPER Track/Item/Take APIs, and a
ReaImGui frame. It also injects failures after partial Import, Update, and Reference
synchronization mutations and verifies that REAPER Undo restores Tracks, Items,
Takes, fields, timeline state, and project extension state. Run
`tests/ReaProjectLink_RunTests.lua` from the Action List after changing workflow,
manifest, filesystem, or adapter behavior.

`tests/specs.lua` lists the spec files that every runner executes; add new spec
files there.

`tests/run_in_reaper.lua` runs the same suite without interaction: start REAPER
with it as the script argument, and it writes `tests/.last-result` and quits.
CI cannot run REAPER, so the GitHub workflows validate packaging only; the
release skill requires a local passing run before each release.

`tests/run_ui_smoke.lua` renders one frame for every scenario in
`tests/ui_smoke_scenarios.lua` (each view and Review, both themes, 320 px and
1040 px wide) and writes the result to the file named by
`REAPROJECTLINK_UI_SMOKE_RESULT`.
