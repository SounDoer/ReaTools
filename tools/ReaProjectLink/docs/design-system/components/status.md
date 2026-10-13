# Status Contract

Status: Initial Slice 2D contract and reference implementation completed on
2026-10-12. Automated Light and Dark Gallery frames pass. Manual scanability,
wrapping, and non-color comprehension checks remain open before product
migration.

Status presents a compact current condition using exactly one confirmed role:
`neutral`, `ready`, `warning`, or `blocked`. It is not an action, notification,
validation message, or destructive `danger` role.

The component requires `role` and readable `text`. It prefixes the message with
a persistent role label—Info, Ready, Attention, or Blocked—so meaning never
depends on color alone. Products may supply an equivalent localized role label
but cannot remove it. Text wraps within the parent width.

Product code classifies the condition and supplies the message. Status owns only
the shared semantic foreground and readable role cue; it emits no event and
does not execute recovery. Longer messages with actions belong in Notice.

Automated checks cover roles, default and custom labels, wrapping, token use,
contrast, stack balance, and invalid inputs. Gallery fixtures cover product-
shaped conditions in both themes. Manual validation covers scanability, wrapping,
and non-color comprehension before product use.
