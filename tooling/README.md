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

## Commands

- `run_all_tests.ps1` validates ReaToolUI, ReaProjectLink, and ReaAssetFlow.
- `build_release.ps1` creates deterministic release trees from each tool's
  declaration.
- `test_release.ps1` rebuilds both trees and verifies their SHA-256 inventories.
