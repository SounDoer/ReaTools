# Confirmation Dialog and Inline Review

Status: Initial Milestone 3 contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual modal focus,
Escape, close, focus restoration, long-content, action-running, and narrow
Inline Review inspection remains open before product migration.

Confirmation Dialog handles one isolated material consequence that fits in a
short message. It requires a consequence-oriented title, target-and-result
message, specific confirming verb, and Cancel. Generic `Warning`, `Are you
sure?`, `Yes`, `OK`, and `Continue` wording is rejected. Optional detail may
explain recovery, and one safe alternative may be offered when directly useful.

Cancel is submitted before other actions and receives default focus. Confirm
uses danger intent only when its consequence is destructive. While an action is
running, repeat confirmation and cancellation are suppressed. The Dialog emits
`dialog.confirmed`, `dialog.cancelled`, or `dialog.alternative_selected`; it
never executes the consequence.

Inline Review handles multiple targets, risks, choices, or previewable effects.
It presents a non-color state summary, a product-owned review-content slot,
Back to editing, and one explicit completion action. Any blocker disables
completion; warnings remain visible but do not automatically block. Actions
stack at narrow widths and emit `inline_review.cancelled` or
`inline_review.confirmed` after product content events.

A complete Inline Review is not followed by another dialog for consequences it
already explained. Product code owns safeguard selection, target and scope,
issue counts, decisions, freshness, effect execution, outcome reporting, and
whether a retry still has valid confirmation.
