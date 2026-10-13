# Interface Density

Status: Confirmed by DS007 on 2026-10-12.

The first design-system version provides one compact-but-readable density for
desktop production work. It avoids both data-grid compression and oversized
touch-oriented spacing. Users do not choose between density modes in this
version.

The token architecture can support another density later without changing
component APIs. A second mode requires demonstrated workflow value and its own
validation; it is not created speculatively.

## Meaning of density

Density controls how much interface content fits into an area through choices
such as:

- control height and internal padding;
- gaps between related controls;
- spacing between sections;
- row height and vertical rhythm;
- icon box and hit-area size;
- container and card padding.

Density does not change the meaning of a component, the order of content, or
the user's display scaling. It is separate from host DPI under DS002 and from
any future user zoom feature.

## Initial density objective

The initial density is designed for mouse-and-keyboard desktop use alongside
REAPER. It should:

- keep project, dependency, path, and Review information scannable;
- fit useful working context without requiring avoidable scrolling;
- keep labels and actions visually distinct rather than crowded;
- preserve clear click targets for frequent actions;
- maintain readable status, warning, and validation content;
- remain coherent from narrow utility windows to wider review layouts.

Compact does not mean smallest possible. A measurement is reduced only when the
component remains easy to identify, point at, read, and distinguish from nearby
controls.

## Token model

Components consume purpose-based Semantic tokens such as:

```text
semantic.space.inline.tight
semantic.space.inline.default
semantic.space.stack.tight
semantic.space.stack.default
semantic.space.section.default
semantic.space.container.padding
semantic.size.control.small
semantic.size.control.medium
semantic.size.icon.small
semantic.size.icon.medium
```

The canonical IDs do not include `compact`. With one active density, a suffix
would describe configuration rather than purpose and would leak mode selection
into component APIs.

A future density system would resolve the same semantic IDs through a different
density map:

```text
component -> semantic role -> active density map -> primitive value
```

Product views and component APIs remain unchanged when the active map changes.
They do not branch on `compact` or `comfortable` themselves.

## Assignment sequence

DS007 confirms the number and character of the initial density. It does not
approve every final measurement independently of typography.

Exact aliases are assigned in this order:

1. DS009 establishes font roles, weights, and glyph requirements; rendered
   prototypes finalize its numeric sizes.
2. Control heights and vertical padding are fitted to those text metrics using
   the DS006 grid.
3. Inline, stack, section, and container spacing are assigned from the DS006
   scale.
4. Representative controls and Reviews are checked at DS008 layout ranges.
5. The complete Light and Dark component states receive visual and interaction
   validation.

This prevents control height, line height, and padding from being selected as
unrelated numbers.

## No public density preference

The first version does not expose a Compact or Comfortable setting. It also
does not maintain unused parallel token tables merely to suggest future
support.

Density capability means that semantic responsibilities are centralized and
components do not embed local measurements. It does not require implementing a
second value set before one is needed.

A future density preference requires:

- a confirmed user or workflow need;
- a complete semantic value map rather than a global scale factor;
- component-state and responsive validation;
- a migration and persistence decision;
- testing at supported display scales.

Density is changed through discrete reviewed values. Multiplying every
measurement by one global factor is not an acceptable density mode because text,
borders, icons, controls, and layout do not scale well at the same rate.

## Component rules

- Shared components own internal padding and minimum size through Semantic or
  Component tokens.
- Product views control composition and available width, not local component
  density.
- Dense data presentation may use an approved small control or row role; it does
  not invent a separate page-level density.
- A small variant must remain readable and operable and must have a repeatable
  purpose across products.
- Status and validation content may wrap or grow vertically rather than being
  clipped to preserve compactness.
- Responsive wrapping under DS008 does not switch density automatically.

## Validation

The density is validated through representative workflows rather than isolated
swatches. Checks include:

- primary and secondary button targeting;
- icon-button identification and targeting;
- text input, combo, checkbox, and segmented-control clarity;
- repeated rows and key-value scanning;
- warning and blocked messages with wrapped text;
- card and section grouping;
- narrow-window wrapping and wide-window information density;
- 100%, 125%, 150%, and 200% host display scaling under DS002.

If a component appears crowded, the first response is to correct that component
or semantic assignment. It does not automatically justify a user-facing global
density switch.

No production measurement or preference is changed by DS007 itself.
