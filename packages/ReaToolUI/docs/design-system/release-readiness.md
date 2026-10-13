# First Contract Release Readiness

Status: Not releasable. This checklist prevents an implementation milestone
from being mistaken for contract `0.1.0`.

| Release condition | State | Evidence or blocker |
| --- | --- | --- |
| Supported tokens documented and validated | Automated-ready | Token registry, contracts, parity, reference, and contrast tests |
| Supported Components documented and validated | Automated-ready | Component contracts, Gallery fixtures, and structural tests |
| Supported Patterns documented and validated | Automated-ready | Milestone 3 catalog, Gallery fixtures, and semantic event tests |
| Adapter behavior documented and validated | Automated-ready | ReaImGui 0.9 adapter and stack-balance tests |
| Complete native DS016 matrix | Blocked | Native Windows UI control is unavailable; see validation record |
| ReaProjectLink Settings pilot | Not started by gate | Requires applicable manual Component and Pattern cells |
| ReaProjectLink Review pilot | Not started by gate | Requires Settings pilot and Review native cells |
| Remaining ReaProjectLink migration | Not started | Requires both pilots |
| Distribution mechanism approved | Confirmed | ReaTools monorepo with self-contained tool releases; see repository decision M005 |
| Product-neutral package name and namespace | Confirmed | `ReaToolUI` and `reaui`; prototype namespace still awaits extraction |
| ReaAssetFlow declaration and adoption | Not started | Copied baseline passes; shared-package adoption follows extraction and DS016 gates |
| Both consumers pass one exact contract version | Not started | Depends on adoption |
| Changelog and migration note | Deferred correctly | Written for the approved extraction and first release |
| Rollback guidance | Prepared at strategy level | Exact paths and versions depend on distribution decision |
| Contract version assigned | Correctly absent | `VERSION` remains `nil`; `STATUS` remains `development` |

The first release becomes eligible only when every row is pass, complete, or a
documented non-blocking not-applicable result. Automated smoke success alone is
not a release.
