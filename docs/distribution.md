# Distribution and update model

## Outcome

ReaTools will expose one ReaPack repository containing independently versioned
ReaProjectLink and ReaAssetFlow packages. ReaPack owns installation, update,
rollback, and Action List registration for shipped files. A tool release is
self-contained: it must not load Lua modules from the source monorepo or from
another separately installed ReaTools product.

The public repository URL and Git hosting owner remain deployment settings, not
source-level product decisions. They must be configured before the first public
index is generated.

## Package declarations

Each tool owns a `reatools-package.json` declaration. It records the product
identity, version, entry point, exact ReaToolUI contract, and explicit release
inventory. `packages/ReaToolUI/reatools-package.json` is the canonical shared
package identity.

`uiContract.usage` has three allowed states:

- `planned`: the tool is covered by design work but does not load ReaToolUI;
- `validation-only`: tests consume ReaToolUI, but the shipped product does not;
- `runtime`: the shipped product loads that exact contract and the release must
  vendor the corresponding `reaui` files.

The current declarations intentionally say `validation-only` for ReaProjectLink
and `planned` for ReaAssetFlow. They must change to `runtime` only with the
product migration that introduces the dependency.

## Deterministic release trees

Run `tooling/build_release.ps1` to build clean tool trees under `dist/`. The
builder copies only declared files and writes `package-inventory.json` with the
version, UI contract, byte size, and SHA-256 hash of every file. Run
`tooling/test_release.ps1` to rebuild and verify both inventories.

Generated `dist/` content is never canonical source and is not committed. The
future ReaPack publishing job will consume these verified trees, arrange them in
the ReaPack category layout, run `reapack-index --check`, and publish the index.

## ReaAssetFlow installation boundary

ReaPack can install and update ReaAssetFlow's Lua, Python, setup, and
documentation files, but it must not silently execute package-manager commands
on the user's machine. The supported experience is therefore:

1. install or update ReaAssetFlow through ReaPack;
2. launch it from the REAPER Action List;
3. run a visible prerequisite check for ReaImGui, Python, and `waapi-client`;
4. if Python dependencies are missing, offer the shipped setup entry with clear
   instructions and retry after it completes;
5. treat Ollama and its Python package as optional and request them only when an
   LLM feature is enabled.

Before public migration, runtime state and user presets must move out of the
installed package tree into a stable REAPER resource-data location. The upgrade
must import existing local state once, preserve it across ReaPack updates, and
document rollback. Batch setup remains a compatibility route until the in-tool
prerequisite flow is implemented and validated.

## ReaPack constraints

The release layout follows the official packaging model: package files live in
a category subdirectory, `@version` is mandatory, and `@provides` declares all
additional files and their target names. Package headers and index generation
will be added only after the public repository URL and final release layout are
configured, so generated download URLs cannot accidentally point at the legacy
repositories.
