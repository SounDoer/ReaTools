# Contract Versioning and Compatibility

Status: Confirmed by DS017 on 2026-10-12.

The shared design-system contract has its own semantic version, independent of
ReaProjectLink, ReaAssetFlow, and future product releases. Products declare the
contract they implement so token, component, pattern, and adapter compatibility
can be reviewed explicitly.

Distribution architecture remains a separate implementation decision. The same
contract policy applies whether products later consume a shared module, vendor a
versioned copy, or use another approved delivery method.

## Versioned contract

The design-system contract includes:

- canonical token IDs, value types, reference rules, and semantic meanings;
- theme-map requirements;
- Component and Pattern names, variants, properties, states, defaults, and
  semantic events;
- platform-adapter behavior required for conformance;
- Gallery fixtures and reference behavior tied to supported contracts;
- validation requirements and migration rules.

Product workflow, domain data, and product release versions are not part of the
design-system contract merely because they consume it.

## Version format

Versions use:

```text
MAJOR.MINOR.PATCH
```

After `1.0.0`:

- **MAJOR** changes when a supported consumer must migrate because an existing
  contract was removed, renamed, retyped, or changed in meaning;
- **MINOR** changes for backward-compatible additions and new optional
  capabilities;
- **PATCH** changes for compatible corrections that preserve contract meaning.

The first usable shared implementation and contract may begin at `0.1.0`.
Before `1.0.0`, a breaking contract change increments MINOR and resets PATCH.
Compatible fixes increment PATCH. Pre-1.0 status permits faster evolution but
does not permit silent breaking changes.

The version is assigned when an implementation becomes consumable. DS017
defines policy and does not by itself publish `0.1.0`.

## Breaking changes

A change is breaking when an existing conforming consumer can no longer retain
the same meaning or behavior without migration. Examples include:

- renaming or removing a canonical token;
- changing a token's value type, reference direction, or semantic meaning;
- requiring consumers to supply a new theme value without a compatible shared
  default;
- renaming or removing a Component, Pattern, variant, property, state, or event;
- changing a property from optional to required;
- changing an event payload or activation meaning;
- changing a default in a way that alters established product behavior;
- merging two roles whose distinction consumers currently rely on;
- splitting one role without a compatibility mapping;
- removing a supported ReaImGui adapter behavior or host range;
- changing focus, validation, selection, or destructive behavior in a way that
  requires product workflow changes.

A visual change is not automatically breaking. A color, spacing, font, or shape
correction may be compatible when the same semantic role and component contract
remain intact. It still receives a changelog entry, DS016 validation, and review
of every affected Semantic reference.

If a visual change materially reverses hierarchy, action emphasis, status
meaning, or layout behavior that consumers depend on, it is treated as a
contract change rather than a cosmetic patch.

## Compatible changes

Typical backward-compatible MINOR changes include:

- a new optional Component or Pattern;
- a new optional property with a compatible default;
- a new state that existing consumers are not required to produce;
- a new token whose shared default keeps existing consumers conforming;
- a new Gallery scenario or validation capability;
- support for an additional platform without removing existing behavior.

Typical PATCH changes include:

- correcting an implementation defect to match the existing specification;
- fixing a contrast, focus, or layout defect without changing semantic meaning;
- correcting documentation ambiguity without changing the contract;
- improving tests or fixtures without changing supported behavior.

The smallest version category that accurately communicates consumer impact is
used. A large code change can still be PATCH when it only restores the existing
contract; a one-line token rename is breaking.

## Consumer declaration

Each product records:

- the design-system contract version it targets;
- the shared implementation or vendored revision it uses;
- the adapter and ReaImGui compatibility target;
- any documented temporary Product exceptions;
- the latest completed migration note when applicable.

The declaration lives in a normal machine-readable product metadata location
chosen during integration and is also visible in development diagnostics or the
DS015 Gallery where practical.

An exact contract version is the default during pre-1.0 development. A
compatible version range may be introduced only when automated conformance tests
demonstrate that the product can safely accept it.

No product infers compatibility solely from matching function names or copied
files.

## Deprecation lifecycle

A deprecated contract remains functional temporarily while consumers migrate.
Deprecation requires:

- the deprecated name or behavior;
- the replacement and migration instruction;
- the first version carrying the deprecation;
- the earliest version in which removal is permitted;
- the known first-party consumers still using it;
- structural validation that prevents new first-party use where practical.

After `1.0.0`, removal occurs only in a MAJOR release. A deprecation remains for
at least one published MINOR release and is not removed until ReaProjectLink and
ReaAssetFlow have migrated when both are consumers of that contract.

Before `1.0.0`, removal may occur in the next MINOR release after documented
deprecation, but only after every known first-party consumer has migrated or an
explicit coordinated migration plan approves the break.

Time alone does not remove a deprecation. Conversely, an alias does not remain
forever merely because an unknown external consumer might exist.

## Compatibility aliases

Temporary aliases exist only at a defined compatibility boundary, normally the
platform adapter or migration facade. They:

- map one deprecated contract to one replacement;
- preserve meaning rather than merely approximate appearance;
- are forbidden in new product code;
- are covered by migration tests;
- have a documented removal version;
- do not create alias chains or cycles.

Canonical token tables and new Component APIs expose only current names. An old
short theme name such as `accent` may temporarily map to a canonical semantic
role during migration, but it does not become a permanent synonym.

## Changelog

Every published contract version includes concise sections as applicable:

```text
Added
Changed
Deprecated
Removed
Fixed
Migration
```

Entries identify affected token IDs, Components, Patterns, states, events,
adapters, Gallery scenes, and consumer actions. A visual correction names the
semantic roles and states affected rather than saying only `updated styling`.

The Migration section is mandatory for every breaking release and every release
introducing a deprecation.

## Migration note

A migration note contains:

- source and target contract versions;
- reason and intended semantic outcome;
- exact old-to-new token and API mappings;
- changed defaults or state behavior;
- required product-code and fixture updates;
- compatibility aliases and their removal version;
- automated checks and Gallery matrix cells to run;
- ReaProjectLink and ReaAssetFlow migration status when affected;
- rollback or recovery guidance when the integration change is not atomic.

A migration note does not combine unrelated product behavior changes merely to
make the design-system upgrade convenient.

## Cross-product upgrade process

For a compatible upgrade:

1. update the contract and shared implementation;
2. update Gallery fixtures and structural tests;
3. verify existing consumer declarations remain compatible;
4. run affected DS016 validation;
5. update each product at its own release cadence;
6. record product exceptions and remaining deprecated use.

For a breaking upgrade:

1. publish the migration note before consumer changes;
2. provide the temporary compatibility boundary when approved;
3. migrate and validate ReaProjectLink;
4. migrate and validate ReaAssetFlow;
5. confirm no first-party use remains;
6. remove compatibility only in the version permitted by the lifecycle.

Products do not need matching product versions or simultaneous releases. They
do need an explicit supported contract while their migrations overlap.

## Contract conformance

A product conforms to a declared version when:

- it consumes only supported tokens, Components, Patterns, and events;
- its adapter meets the declared host behavior;
- known Product exceptions are recorded and do not masquerade as shared
  variants;
- relevant structural, Gallery, and product integration checks pass;
- it does not depend on deprecated contracts scheduled for removal before its
  claimed compatible range ends.

Copying the visual appearance without the semantic or interaction contract is
not conformance.

## Distribution boundary

DS017 does not choose between a shared repository, package, submodule, vendor
copy, generated artifact, or another distribution method. That decision is made
when implementation and release constraints are known.

Any chosen method must preserve:

- one identifiable contract version;
- traceable source and implementation revision;
- deterministic upgrades;
- product declarations;
- migration notes and changelog;
- the ability to test both first-party consumers before compatibility removal.

No version is published and no production metadata is changed by DS017 itself.
