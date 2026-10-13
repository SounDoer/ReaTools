# Repository Tooling

`run_all_tests.ps1` is the initial repository-level validation entry point. It
runs the complete ReaProjectLink design-system and UI matrix followed by the
ReaAssetFlow Python suite and syntax checks.

```powershell
./tooling/run_all_tests.ps1
```

The command adds no runtime dependency. It expects the same local REAPER,
ReaImGui, Python, and test environment already required by the copied tools.

Build, ReaPack metadata, artifact inventory, and release automation will be
added here after the copied baselines pass from their monorepo paths.
