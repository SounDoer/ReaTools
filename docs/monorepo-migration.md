# ReaTools Monorepo Migration

## Objective

Create one maintainable source repository for ReaProjectLink, ReaAssetFlow,
ReaToolUI, and future REAPER tools while preserving current product behavior and
giving every tool a consistent installation, update, validation, and release
path.

## Current baseline

- The tracked files from ReaProjectLink are copied to
  `tools/ReaProjectLink`.
- The tracked files from legacy ReaperToWwise are copied to
  `tools/ReaAssetFlow`.
- The original standalone repositories remain unchanged.
- `packages/ReaToolUI` contains the canonical design-system implementation
  under the `reaui` namespace.
- ReaToolUI owns its design-system documentation, automated tests, and Gallery;
  the duplicate Product-local implementation has been removed.
- No product workflow or persisted data has changed.

## Migration sequence

### Phase 1 — Establish the monorepo baseline

1. Record repository-wide decisions and boundaries.
2. Rename legacy product-facing identifiers to ReaAssetFlow.
3. Make both copied tools pass their existing tests from their new paths.
4. Add one repository-level validation command without adding runtime
   dependencies.

### Phase 2 — Extract ReaToolUI

Completed structural extraction:

1. copied the validated design-system implementation into
   `packages/ReaToolUI`;
2. renamed its public Lua namespace from the prototype `reaprojectlink.ui`
   boundary to `reaui`;
3. retained Product effects and workflow code inside each tool;
4. moved the Gallery, specifications, and conformance checks under the shared
   package;
5. proved ReaProjectLink against the shared source and removed its duplicate
   `design_*` implementation.

Remaining package work adds explicit consumer declarations and packaging
metadata.

The DS016 native visual and interaction matrix remains a gate for product UI
migration. Structural extraction alone does not waive it.

### Phase 3 — ReaProjectLink integration

1. declare the exact ReaToolUI contract used by ReaProjectLink;
2. migrate Settings and the representative Review pilot after their DS016 cells
   pass;
3. migrate remaining presentation surfaces;
4. retire the temporary compatibility boundary;
5. reproduce the existing ReaPack package and release checks from the monorepo.

### Phase 4 — ReaAssetFlow product migration

1. replace legacy ReaperToWwise names and paths without changing behavior;
2. separate the current panel, product services, and Python worker boundaries;
3. adopt ReaToolUI in the agreed component and Pattern order;
4. retain Wwise, WAAPI, naming grammar, presets, transfer, Perforce, and optional
   LLM behavior inside ReaAssetFlow;
5. replace batch-file installation and manual script registration with the
   unified ReaPack-oriented release flow;
6. provide upgrade guidance for legacy users and local state.

### Phase 5 — Shared release tooling

1. validate all affected Lua and Python suites from the repository root;
2. build self-contained, deterministic artifacts for each tool;
3. generate ReaPack metadata and verify packaged file inventories;
4. keep tool versions independent while recording their ReaToolUI contract;
5. add a reusable template for future tools.

## Safety and rollback

- Do not delete or modify the original standalone repositories during the
  migration.
- Keep structural changes separate from product behavior changes.
- A copied tool must pass its original checks before its old location can be
  considered obsolete.
- A release migration must document its legacy install path, new install path,
  retained state, and rollback procedure.
