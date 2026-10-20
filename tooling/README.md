# Repository Tooling

`run_all_tests.ps1` is the repository-level validation entry point. It runs the
ReaToolUI package and Gallery matrices, the ReaProjectLink core and product UI
matrices, the ReaAssetFlow Python suite and syntax checks, and both deterministic
release-inventory checks.

```powershell
./tooling/run_all_tests.ps1
```

The command adds no runtime dependency. It expects the same local REAPER,
ReaImGui, Python, and test environment already required by the copied tools.

Repository CI runs the portable Python, release-inventory, scaffold, UI layout
scan self-test, and full official ReaPack index checks on Linux with Pandoc.
Native REAPER, ReaImGui,
Gallery, and product UI smoke checks remain in the Windows local command above.

## Commands

- `run_all_tests.ps1` validates ReaToolUI, ReaProjectLink, and ReaAssetFlow.
- `build_release.ps1` creates deterministic release trees from each tool's
  declaration.
- `test_release.ps1` rebuilds both trees and verifies their SHA-256 inventories.
- `build_reapack_repository.ps1` arranges both verified packages into the final
  ReaPack category layout.
- `test_reapack_repository.ps1` validates package headers, layout, and excluded
  state; it also runs `reapack-index --check` when that optional release tool is
  installed.
- `new_tool.ps1` creates a future ReaTools product from the repository template.
- `test_new_tool.ps1` expands the template in an isolated generated sandbox and
  rejects missing files or unreplaced placeholders.
- `check_ui_layout.ps1 -Path <dir> [-Report]` lists raw ImGui layout calls
  (`raw-layout`) and numeric layout literals other than 0 and 1 in `c.*` or
  `ImGui.*` calls (`layout-literal`) in the Lua files directly under `<dir>`.
  It exits 1 on any finding unless `-Report` is set. `run_all_tests.ps1`
  reports the ReaProjectLink views without failing until their migration is
  complete.
- `test_check_ui_layout.ps1` runs the scan against clean and dirty fixtures.

On validated pushes to `main`, `.github/workflows/deploy-reapack.yml` publishes
the output of `build_reapack_repository.ps1` to the generated `reapack` branch
and updates its `index.xml`. Do not edit that branch by hand.
