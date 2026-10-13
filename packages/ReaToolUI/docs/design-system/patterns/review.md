# Review Pattern Family

Status: Initial Milestone 3 contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual scrolling,
fixed-footer, focus, stale replacement, narrow-layout, and long-content
inspection remains open before product migration.

The Review family contains Review Header, Review Footer, Stale Review, and
Review Shell. Together they provide a reusable preparation-and-decision frame
without knowing product nouns or executing product effects.

Review Header places Back first in reading and submission order, followed by a
verb-first title and optional summary. It emits `review.back_requested`. Review
Footer keeps a textual outcome or blocker summary next to the one completion
action, stacks at narrow widths, prevents duplicate activation while running,
and emits `review.complete_requested` only when enabled.

Stale Review replaces the whole decision body with a warning, explanation, and
one Refresh action. It emits `review.refresh_requested`. Stale decisions are
never rendered or actionable, and Review Shell forcibly disables completion
while stale even if a caller supplied an enabled Footer.

Review Shell constrains content to a readable maximum width, gives the Header
and body a vertically scrolling child, and keeps the Footer in a separate
non-scrolling child. Its order is Header, current body or Stale Review, then
Footer. Product body events are forwarded between Header and Footer events.

The product supplies issue Notices, decisions, detail Disclosures, labels,
summaries, current/stale state, enablement, operation state, and every domain
effect. The Pattern never counts domain issues, refreshes data, mutates a
decision, publishes, imports, synchronizes, or transfers.
