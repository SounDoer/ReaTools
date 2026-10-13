# External Operation Status Pattern

Status: Initial Milestone 3 contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual long-message,
progress, action, scaling, and lifecycle-transition inspection remains open
before product migration.

External Operation Status gives persistent, non-modal feedback for work owned by
REAPER, Wwise, WAAPI, a network service, a child process, or another external
system. It composes Notice with a stable state vocabulary and optional Cancel,
Retry, and Dismiss actions.

States are idle, running, succeeded, failed, cancelled, and partial. Every state
has a visible text label independent of color or motion. Running and partial may
show numeric progress from 0 through 100; indeterminate work remains explicit
through its running label and message. Detail text may explain recovery or what
was retained.

Cancel is valid only while running. Retry is valid after failure, cancellation,
or partial completion. Dismiss is valid only after an outcome. Actions emit
`operation.cancel_requested`, `operation.retry_requested`, or
`operation.dismiss_requested`; the Pattern never starts, monitors, cancels, or
retries external work itself.

Product code owns job identity, process handles, polling, logs, timeout policy,
partial-result semantics, cleanup, persistence, and transition timing. It must
ignore stale events from superseded jobs and must not infer success from the
absence of an error message.
