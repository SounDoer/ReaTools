# Path Selection Pattern

Status: Initial Milestone 3 contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual picker handoff
and lifecycle-transition checks remain open before product migration.

Path Selection composes File or Folder Path Field with a stable validation and
picker-availability lifecycle. Its states are idle, checking, valid, invalid,
and unavailable. Every non-idle state requires readable explanatory or recovery
text; unavailable state also disables Browse.

The Pattern preserves Path Field edit, commit, and `path.browse_requested`
events. Product code still opens the picker, normalizes paths, checks existence,
permissions, roots, and containment, starts asynchronous validation, persists
the value, and supplies the next state. The Pattern never reads the filesystem
or assumes Windows, macOS, Linux, NAS, REAPER, or Wwise path semantics.

Callers provide state and message rather than a separate validation object so
the Pattern cannot present contradictory lifecycle cues. Automated checks cover
state mapping, required messages, unavailable Browse behavior, event forwarding,
and invalid combinations. Gallery fixtures cover both products and both themes.
Manual validation covers picker handoff and state transitions before product use.
