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

## Direction C layout (DS022)

Revised on 2026-10-20. Automated checks pass; visual review happens in round 2
of the visual language plan.

- **Header.** Review Header renders through Page Header: the Back icon button,
  the title in the `title` role, and the optional summary under the title in
  the `label` role with the secondary text color. `disabled` disables Back.
  Page Header adds the header gap below; there is no separator.
- **Scope summary.** An optional Stat Group directly under the header
  summarizes the scope (for example tracks, markers, regions).
- **Sections.** `review_shell.section({ id, title }, render)` draws a Section
  Heading and then the body, and returns `render()`'s result. A section gets
  `semantic.space.section.loose` above it whenever content was drawn between
  the header and the section, such as the Stat Group or an earlier section; a
  section directly under the header relies on the header gap. Sections are
  meant to be drawn from `render_body`. Typical sections are Issues,
  Decisions, and Details.
- **Issues.** Each problem is an Issue Item (warning or blocked) with its fix
  actions; several are drawn with `issue_item.draw_list`.
- **Details.** Detail groups use the inset Disclosure variant. A group whose
  `role` is `warning` or `blocked` opens by default.
- **Footer.** Review Footer draws the only separator, then
  `semantic.space.footer.padding_y`, then the summary as an inline Status and
  the completion button right-aligned through the shared trailing layout.
  Horizontal footer padding comes from the containing child window. Below
  `semantic.size.field.inline_wide` the button stretches on its own line.

The product supplies issue Notices, decisions, detail Disclosures, labels,
summaries, current/stale state, enablement, operation state, and every domain
effect. The Pattern never counts domain issues, refreshes data, mutates a
decision, publishes, imports, synchronizes, or transfers.
