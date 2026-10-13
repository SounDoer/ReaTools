# Shared Design-System Distribution

Status: Confirmed on 2026-10-13 by ReaTools decisions M001 through M005.

## Selected architecture

ReaProjectLink, ReaAssetFlow, ReaToolUI, and future tools share one canonical
source repository: the ReaTools monorepo.

```text
ReaTools/
├── tools/
│   ├── ReaProjectLink/
│   └── ReaAssetFlow/
└── packages/
    └── ReaToolUI/
```

`packages/ReaToolUI` owns the product-neutral contract metadata, tokens,
Components, Patterns, ReaImGui adapter, Gallery fixtures, conformance tests,
changelog, and migration notes. Its public Lua namespace is `reaui`.

Product code owns workflows, persistence, REAPER effects, Wwise and WAAPI
behavior, release composition, and product-specific UI composition.

## Release boundary

The monorepo has one shared source package but does not create one mutable
runtime installation shared by every tool. Each tool release is:

- independently versioned;
- self-contained for offline use;
- built from a recorded ReaToolUI contract and source revision;
- verified against a deterministic packaged-file inventory;
- installable and updatable without silently changing another tool.

The final ReaPack packaging shape is implemented in repository-wide release
tooling. It must preserve these properties whether shared files are copied into
an artifact or emitted as an explicitly pinned package dependency.

## Evaluated alternatives

| Option | Assessment | Reason |
| --- | --- | --- |
| Keep shared source inside ReaProjectLink | Rejected | Couples every future tool to one product namespace and repository layout |
| Copy files manually between independent repositories | Rejected | Drifts and cannot prove deterministic upgrades |
| Git submodules | Superseded | Adds nested-repository and installation friction without value inside the monorepo |
| Separate ReaToolUI repository with vendor snapshots | Superseded | Was the preferred multi-repository option, but the confirmed monorepo makes a second canonical repository unnecessary |
| ReaTools monorepo plus self-contained releases | Selected | One source of truth, direct cross-tool validation, independent tool releases, and a simple future-tool template |

## Migration sequence

1. establish copied ReaProjectLink and ReaAssetFlow baselines in ReaTools;
2. extract the design-system source to `packages/ReaToolUI` and rename its public
   namespace to `reaui`;
3. verify ReaProjectLink against the extracted package without changing product
   behavior;
4. complete the applicable DS016 native manual cells;
5. migrate ReaProjectLink Settings and the representative Review pilot;
6. declare and migrate ReaAssetFlow in the specified component order;
7. build independently versioned, self-contained ReaPack artifacts;
8. publish contract `0.1.0` only after both consumers conform.

## Rollback

Source extraction and each consumer migration remain separate reviewable
commits. A tool release records its ReaToolUI contract and packaged inventory,
so rollback restores that tool's previous artifact without downgrading another
installed tool. Product data and workflows do not change merely because the
shared presentation package changes.
