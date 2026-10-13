# ReaToolUI

ReaToolUI is the product-neutral ReaImGui design-system package for ReaTools.
It will own the validated tokens, adapter, Components, Patterns, Gallery,
contract metadata, and conformance checks currently prototyped inside
ReaProjectLink.

The extraction is intentionally staged. Until the shared namespace and copied
consumers pass their checks, the working implementation remains in
`tools/ReaProjectLink` and this directory records the target ownership boundary.

Product workflows, persistence, REAPER operations, Wwise or WAAPI operations,
and product-specific composition do not belong in this package.
