# ReaTools Decision Log

This file records confirmed repository-wide and cross-tool decisions. Product
workflow and persisted-data decisions remain in the relevant tool's own
decision log.

## Confirmed decisions

### M001 — Use one canonical monorepo

Confirmed: 2026-10-13.

`C:\Users\shenxichen\repos\ReaTools` is the canonical source repository for the
ReaTools family. User-facing tools live under `tools/`; shared source packages
live under `packages/`; repository-wide automation lives under `tooling/`.

### M002 — Start with a copied source baseline

Confirmed: 2026-10-13.

The existing ReaProjectLink and ReaperToWwise Git histories are not imported.
Only their tracked source files are copied into the monorepo. The original
standalone repositories remain unchanged as recoverable references until the
copied tools pass their migration and release checks.

### M003 — Establish the initial product family names

Confirmed: 2026-10-13.

The initial family consists of:

- `ReaProjectLink`, retaining its existing product name;
- `ReaAssetFlow`, replacing the legacy `ReaperToWwise` name;
- `ReaToolUI`, the shared product-neutral UI system.

The intended code namespaces are `reaprojectlink`, `reaassetflow`, and `reaui`
respectively. A temporary compatibility name may exist only at a documented
migration boundary.

### M004 — Standardize installation and updates

Confirmed: 2026-10-13.

ReaAssetFlow will move from its legacy batch-file and manually registered
script installation toward the same ReaPack-oriented installation, update,
versioning, and release experience used by ReaProjectLink. Repository-wide
tooling should make the same path available to future tools.

### M005 — Keep releases self-contained

Confirmed: 2026-10-13.

Shared code has one canonical source location in the monorepo. Each released
tool remains self-contained for offline use and pins the ReaToolUI contract it
was validated against. Installing or updating one tool must not implicitly
replace the UI implementation used by another installed tool.

### M006 — Preserve behavior during structural migration

Confirmed: 2026-10-13.

Copying, renaming, extracting shared UI code, and standardizing distribution do
not authorize changes to product workflows, persisted data, Wwise or WAAPI
behavior, or ReaProjectLink delivery semantics. Such changes require their own
product decisions and tests.

### M007 — Declare and verify every release inventory

Confirmed: 2026-10-13.

Every tool has a machine-readable declaration containing its independent
version, entry point, exact ReaToolUI contract, and release file set. Release
trees contain only declared, Git-tracked source and include a SHA-256 inventory.
When a product changes its ReaToolUI usage to `runtime`, the builder vendors the
pinned shared package into that product's self-contained release.

### M008 — Separate ReaPack updates from Python environment setup

Confirmed: 2026-10-13.

ReaPack installs and updates ReaAssetFlow's shipped files and registers its main
ReaScript. It does not silently execute `pip` or install Ollama. Required Python
and WAAPI dependencies use an explicit, visible prerequisite flow; LLM support
remains optional. User state, presets, cache, and staging files live under the
REAPER resource-data tree rather than the managed package tree. Legacy data is
copied non-destructively on first run.

### M009 — Host source and distribution in one public GitHub repository

Confirmed: 2026-10-13.

`https://github.com/SounDoer/ReaTools` is the canonical public repository. The
`main` branch contains source and repository automation. The generated
`reapack` branch contains only the independently versioned, self-contained tool
packages and their ReaPack index. GitHub Actions rebuilds and publishes that
branch after validated changes reach `main`; generated distribution files do
not become canonical source.

### M010 — Vendor ReaToolUI with each runtime consumer

Confirmed: 2026-10-13.

ReaProjectLink may declare ReaToolUI as a runtime dependency after a product
surface adopts the shared contract. Development loads the canonical monorepo
package, while every ReaProjectLink release vendors its pinned ReaToolUI source
inside that release. No shared global installation or runtime network lookup is
introduced.
