# ReaTools

ReaTools is the canonical monorepo for a family of REAPER workflow tools and
their shared user-interface system.

## Products and packages

| Path | Name | Purpose |
| --- | --- | --- |
| `tools/ReaProjectLink` | ReaProjectLink | Local delivery and dependency management for REAPER projects |
| `tools/ReaAssetFlow` | ReaAssetFlow | Naming, rendering, previewing, and transferring game-audio assets from REAPER to Wwise |
| `packages/ReaToolUI` | ReaToolUI | Product-neutral ReaImGui tokens, Components, Patterns, Gallery, and adapter code |

## Repository layout

```text
ReaTools/
├── tools/
│   ├── ReaProjectLink/
│   └── ReaAssetFlow/
├── packages/
│   └── ReaToolUI/
├── tooling/
└── docs/
```

The original standalone repositories remain unchanged while the copied tools
are validated. Git history from those repositories is intentionally not
imported; the first monorepo commit is the new baseline.

Shared source lives once under `packages/`. Release artifacts remain
self-contained so installing or updating one tool does not silently alter
another tool.

## Install with ReaPack

Import the following repository URL in **Extensions > ReaPack > Import
repositories...**:

```text
https://raw.githubusercontent.com/SounDoer/ReaTools/reapack/index.xml
```

ReaProjectLink and ReaAssetFlow appear as separate packages and can be updated
independently. The generated package repository is published from the
`reapack` branch; canonical source remains on `main`.

See `docs/decisions.md` for confirmed cross-tool decisions and
`docs/monorepo-migration.md` for the migration sequence. Distribution,
ReaPack, and Python-prerequisite boundaries are defined in
`docs/distribution.md`.
