# First Contract Release Readiness

Status: Not releasable. This checklist prevents an implementation milestone
from being mistaken for contract `0.1.0`.

| Release condition | State | Evidence or blocker |
| --- | --- | --- |
| Supported tokens documented and validated | Automated-ready | Token registry, contracts, parity, reference, and contrast tests |
| Supported Components documented and validated | Automated-ready | Component contracts, Gallery fixtures, and structural tests |
| Supported Patterns documented and validated | Automated-ready | Milestone 3 catalog, Gallery fixtures, and semantic event tests |
| Adapter behavior documented and validated | Automated-ready | ReaImGui 0.9 adapter and stack-balance tests |
| Complete native DS016 matrix | In progress, blocking | Manual Windows review is available; Foundation and Component calibration is active and other scales remain unavailable |
| ReaProjectLink Settings pilot | Implemented; native validation pending | Settings consumes the confirmed shared Components and Patterns; automated product and release checks pass |
| ReaProjectLink Review pilot | Implemented; native validation pending | Every Review consumes shared Review, Notice, input, Disclosure, Footer, and confirmation primitives where applicable |
| Remaining ReaProjectLink migration | Implemented; native validation pending | Setup, headers, cards, menus, statuses, Toast, and destructive flows use one token-driven Product composition boundary |
| Distribution mechanism approved | Confirmed and exercised | ReaTools monorepo with a self-contained vendored ReaToolUI runtime in the ReaProjectLink release; see M005, M007, and M010 |
| Product-neutral package name and namespace | Complete | `ReaToolUI` and `reaui` are extracted under `packages/ReaToolUI` |
| ReaAssetFlow declaration and adoption | Declaration complete; adoption gated | Package declaration, release boundary, UI smoke, setup diagnostics, and user-data migration pass; ReaToolUI presentation adoption awaits DS016 |
| Both consumers pass one exact contract version | Not started | Depends on adoption |
| Changelog and migration note | Deferred correctly | Written for the approved extraction and first release |
| Rollback guidance | Prepared | Exact legacy and stable user-data paths plus non-destructive copy behavior are documented |
| Contract version assigned | Correctly absent | ReaToolUI `VERSION` remains `nil` and `STATUS` remains `development`; tool package version `0.1.0` is not a released UI contract |

The first release becomes eligible only when every row is pass, complete, or a
documented non-blocking not-applicable result. Automated smoke success alone is
not a release.
