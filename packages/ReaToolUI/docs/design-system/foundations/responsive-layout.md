# Responsive Layout Model

Status: Confirmed by DS008 on 2026-10-12. Range names and behavior are
confirmed; numeric thresholds remain to be validated with representative
components and views.

ReaProjectLink adapts to the available logical width of its host window through
three behavior ranges: `compact`, `standard`, and `wide`. These ranges describe
layout behavior, not devices, display DPI, user density, or feature levels.

Containers choose page-level composition. Components respond to the width they
actually receive. Reflow changes presentation without hiding capabilities or
changing product meaning.

## Layout ranges

### Compact

Compact supports narrow utility windows:

- major regions and peer cards use one column;
- related actions wrap or stack without changing priority;
- label-value rows may stack when an inline value would become unreadable;
- status and validation messages grow vertically instead of clipping;
- primary actions remain visible and identifiable;
- secondary detail may move below primary content but is not silently removed.

### Standard

Standard is the normal working range:

- primary content usually remains one readable column;
- related labels, values, and actions may share a row;
- short peer cards may form columns when their content remains readable;
- Review decisions and validation context stay close to the affected content;
- text width remains bounded for scanning rather than filling all available
  space.

### Wide

Wide uses additional space to improve scanning:

- independent peer regions may use multiple columns;
- overview and detail content may appear side by side when their reading order
  remains clear;
- repeated records may expose more secondary fields;
- action placement stays associated with its content rather than drifting to a
  distant window edge;
- text and forms retain appropriate maximum widths.

Wide does not mean that every component stretches or that additional product
capabilities appear.

## Range tokens

The layout system uses entry thresholds rather than device categories:

```text
semantic.layout.breakpoint.standard
semantic.layout.breakpoint.wide
semantic.layout.content.max_width
```

Below the Standard threshold, the page uses Compact behavior. At or above the
Standard threshold it uses Standard behavior, and at or above the Wide
threshold it uses Wide behavior.

The numeric thresholds use DS002 logical units and align with the DS006 grid.
They are not copied from common web-device breakpoints. Values are assigned only
after representative ReaProjectLink content is tested immediately below, at,
and above each candidate threshold.

The old local `560` stacking threshold is audit input, not a compatibility
requirement or an automatically approved breakpoint.

## Container responsibility

A page or layout container owns decisions that coordinate multiple children:

- number of columns;
- column proportions and gaps;
- maximum content width and centering;
- ordering of peer regions;
- placement of persistent page actions;
- whether a summary and detail region can coexist horizontally.

The container passes available width through normal ReaImGui layout. It does not
tell every child which global range is active when local width is sufficient.

A Card, Button, Notice, or other leaf component owns only its internal response:

- wrapping its label or supporting text;
- stacking its own internal actions;
- choosing an approved compact internal arrangement;
- preserving minimum readable or operable dimensions.

This prevents a component placed in a narrow column of a Wide page from
incorrectly assuming that it has wide space.

## Width measurement

Responsive decisions use ReaImGui's returned available content width after the
relevant container padding. Values remain in logical units under DS002; product
code does not multiply them by display DPI.

Window dimensions, framebuffer pixels, monitor resolution, operating-system
device class, and user display scale are not layout-range inputs.

Each decision uses one stable measurement point for the frame. A component does
not alternate between ranges because its own chosen layout changes the width it
then measures.

## Reflow principles

When space becomes constrained, use this order of preference:

1. allow flexible regions to shrink within their readable minimum;
2. wrap labels, values, messages, or action groups;
3. stack peer elements while retaining reading order;
4. collapse secondary fields into visible row details when the component
   contract supports it;
5. use clipping or horizontal scrolling only when the data itself cannot be
   represented meaningfully through reflow.

Core decisions, validation state, and primary actions are not hidden solely to
fit a range. DS014 defines the detailed policy for structured and long data.

Responsive reflow does not change the DS007 density automatically. Compact
layout range and compact interface density are different concepts.

## Order and focus

Visual order, reading order, and ReaImGui submission order remain consistent
across ranges. Moving from columns to a stack must not produce a surprising
keyboard sequence under DS004.

If two regions are independent peers, the stacked order follows their product
priority. If one region explains or controls another, the explanatory or
controlling relationship determines the order rather than whichever column was
visually leftmost.

## Component contract

Every layout-capable component records:

- the minimum width at which its default arrangement remains usable;
- what wraps or stacks below that width;
- which content may truncate and how the complete value remains available;
- whether it owns local layout behavior or relies on its parent container;
- whether any maximum width is required for readability;
- whether reflow affects focus or reading order.

Product views compose these contracts and do not override them with one-screen
breakpoint literals.

## Threshold validation

Candidate thresholds are tested with representative real content rather than
empty component shells:

- shortest and longest expected English labels;
- paths and project names with limited natural break opportunities;
- ready, warning, and blocked content;
- primary and secondary action groups;
- repeated rows and key-value content;
- both Light and Dark themes;
- widths immediately below, at, and above each threshold;
- DS002 display scales to verify that logical behavior remains stable.

The chosen value is the first DS006-aligned width at which the intended
arrangement remains consistently readable. Thresholds may change during the
pre-release component-validation phase without preserving the old `560` value.

No production breakpoint or layout is changed by DS008 itself.
