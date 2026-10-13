# Hierarchy Preview Pattern

Status: Initial Milestone 3 contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual deep-tree,
long-label, disclosure, scaling, and large-data inspection remains open before
product migration.

Hierarchy Preview presents parent-child data with Disclosure nodes and wrapped
leaf content. It is a read-only structural preview, not a table, tree editor,
or product object browser. ReaAssetFlow structure data is the first fixture,
but Wwise object meaning remains outside the Pattern.

Callers supply stable globally unique node identifiers, labels, optional
descriptions, child arrays, and optional default-open hints. An optional
`render_detail(node, depth)` slot may add product-owned read-only detail. The
Pattern owns traversal, indentation through Disclosure, complete wrapped leaf
labels, lifecycle feedback, disabled disclosure state, and deterministic
shape metadata. It emits no product action.

States are ready, loading, empty, failed, stale, and partial. Loading and empty
contain no nodes. Failed, stale, and partial may retain known nodes so useful
previous or incomplete results are not erased. Every non-ready state shows a
textual Status cue. Cyclic tables, duplicate IDs, malformed children, and more
than 64 levels are rejected to keep rendering deterministic and safe.

Long content grows vertically; horizontal scrolling is not the primary reading
path. Product code owns hierarchy loading, caching, Wwise or REAPER semantics,
selection, edits, external calls, and recovery actions.
