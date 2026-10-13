# ReaProjectLink Design System Open Questions

Status: Q1-Q17 were resolved on 2026-10-12. Q18 was resolved on 2026-10-13 by
the ReaTools monorepo decisions. There are no current open design-system
questions.

New questions are added here only when implementation evidence, a new product
workflow, or a platform constraint cannot be resolved by the confirmed
contract. A question remains open until reviewed and confirmed; a resolution
that changes product behavior must also be recorded in that product's decision
log.

## Resolved Q18: Shared package identity and distribution mechanism

Background: the automated reference implementation now covers the supported
Foundations, Components, Patterns, Gallery matrix, conformance checks, and both
products' representative content. ReaAssetFlow remains read-only, and no
product surface has migrated.

Confirmed answer:

- canonical repository: the `ReaTools` monorepo;
- shared package name: `ReaToolUI` under `packages/ReaToolUI`;
- Lua namespace: `reaui`;
- distribution: one shared source package with independently versioned,
  self-contained release artifacts for each tool.

`distribution-options.md` records why the earlier multi-repository alternatives
were superseded. Repository-level decisions M001 through M005 define ownership,
naming, installation direction, and release isolation. The prototype namespace
`reaprojectlink.ui` remains temporary until extraction to `reaui` is verified.

Status: Resolved. This decision does not waive the separate DS016 native manual
validation gate.
