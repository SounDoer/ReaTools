# Design Token Architecture and Naming

Status: The architecture and naming rules are confirmed by DS001. DS019 adopts
Radix Themes Slate and Teal as the visual value baseline; semantic mappings
remain governed by ReaToolUI contrast and host-adapter requirements.

Design tokens give reusable names to visual decisions. They allow product views
to request a purpose such as primary text or a primary action without knowing a
literal color, pixel value, or theme-specific implementation detail.

## The three layers

### Primitive tokens

Primitive tokens are the raw material scale. They contain literal values and do
not describe where those values should appear.

Size-bearing literals use the logical-unit model defined in
`display-scaling.md`; they are not physical pixel counts.

Examples:

```text
primitive.color.teal_light.9 = #12a594
primitive.color.slate_dark.12 = #edeef0
primitive.space.3 = 12
primitive.radius.2 = 8
```

Primitive token names describe the material, not a product meaning. A blue
value does not become `publish_blue`, and a spacing value does not become
`delivery_card_gap`.

Product views and ordinary component implementations must not reference
Primitive tokens directly. They reference the meaning assigned by the Semantic
or Component layer.

### Semantic tokens

Semantic tokens name an interface purpose. Their value normally aliases a
Primitive token and may resolve to a different Primitive token in Light and
Dark themes.

Examples:

```text
semantic.color.text.primary
semantic.color.text.secondary
semantic.color.surface.canvas
semantic.color.border.default
semantic.color.action.primary.default
semantic.color.selection.active.background.default
semantic.color.status.warning
semantic.space.container.padding
semantic.size.control.medium
```

A component asks for `semantic.color.text.primary`, not a particular gray. The
theme controls which raw gray fulfills that role.

Semantic tokens are the default interface between foundations and components.
They are also the lowest layer that a product view may consume.

### Component tokens

Component tokens name stable decisions inside a reusable component. They
normally alias Semantic tokens and are introduced only when they improve the
component contract or allow coordinated component evolution.

Examples:

```text
component.button.primary.background.default
component.button.primary.background.hover
component.button.primary.foreground.default
component.card.background
component.card.border.emphasized
component.notice.warning.foreground
```

Component tokens do not contain product or workflow terminology. For example,
`component.publish_button.background` and
`component.delivery_review.footer_height` are invalid shared-system names.

Not every component property needs a Component token. A simple component may
use Semantic tokens directly. A Component token is justified when at least one
of the following is true:

- the decision is part of the component's stable public appearance;
- multiple component states must change together;
- the component needs a deliberate exception from the general Semantic role;
- more than one product needs to tune the component without redefining its
  meaning.

## Canonical token ID

Every token has one canonical dot-separated ID:

```text
<layer>.<category>.<role...>
```

The first segment is exactly one of:

```text
primitive
semantic
component
```

The second segment describes the token category for Primitive and Semantic
tokens. A Component token uses the component name in the second segment and
then describes variant, property, and state as needed.

Examples:

```text
primitive.color.blue.500
semantic.color.action.primary.default
component.button.primary.background.hover
```

## Segment rules

Token ID segments follow these rules:

- use lowercase ASCII;
- use `snake_case` inside a multiword segment;
- use dots only to express hierarchy;
- use singular nouns unless the concept itself is plural;
- use a numeric segment only for an ordered scale step;
- prefer purpose over appearance above the Primitive layer;
- place interaction state last when the token varies by state;
- do not include product names, screen names, implementation APIs, or theme
  names in a shared Semantic or Component token;
- do not encode the current value in a Semantic or Component token name.

Valid examples:

```text
semantic.color.text.on_accent
semantic.layout.content.max_width
component.icon_button.default.foreground.disabled
```

Invalid examples:

```text
semantic.color.dark_theme_text
semantic.color.blue_button
component.source_reference_card.border
component.imgui_button.frame_bg
semantic.space.12_px
```

## Category vocabulary

The initial classification tree reserves the following categories. Reserving a
category does not approve every token beneath it.

```text
primitive
  color
  font_family
  font_size
  font_weight
  line_height
  space
  size
  radius
  border_width
  stroke_width
  optical_offset
  opacity
  duration

semantic
  color
    text
    icon
    surface
    border
    action
    status
    focus
    selection
    overlay
  typography
  space
  size
  radius
  border
  opacity
  motion
  layout

component
  <component_name>
    <variant>
    <property>
    <state>
```

This vocabulary will be refined while the foundation specifications are
written. New categories require a distinct value type or responsibility; they
are not created merely to shorten a token ID.

## Interaction-state vocabulary

When a token varies by interaction state, the state is the final segment and
uses this vocabulary where applicable:

```text
default
hover
pressed
focused
selected
disabled
loading
```

`pressed` describes pointer or keyboard activation. The name `active` is
avoided because it can mean pressed, selected, current, or enabled in different
UI systems.

Condition terms such as `warning` and `blocked`, and the `danger` action intent,
are semantic roles rather than interaction states. Their separate taxonomy is
defined by DS005 and `status-and-danger.md`.

## References and literals

References flow downward from specific meaning to raw material:

```text
Component -> Semantic -> Primitive -> literal value
```

Allowed references:

- Primitive tokens contain literals.
- Semantic tokens normally reference Primitive tokens.
- Component tokens normally reference Semantic tokens.
- A Semantic token may reference another Semantic token only when the alias
  has exactly the same meaning and does not create a cycle.
- A Component token may reference another Component token within the same
  component when the relationship is explicit and acyclic.

Disallowed references:

- Primitive tokens do not reference Semantic or Component tokens.
- Semantic tokens do not reference Component tokens.
- shared tokens do not reference product-local names;
- aliases must not form cycles;
- a Component token does not bypass the Semantic layer merely to capture a
  convenient literal.

## Themes

Primitive palettes are named collections of available materials. Semantic
theme maps choose which materials fulfill each purpose in Light and Dark modes.
Component definitions normally remain theme-independent.

For example:

```text
Light
semantic.color.text.primary -> primitive.color.gray.900

Dark
semantic.color.text.primary -> primitive.color.gray.050

Both themes
component.button.primary.foreground.default
  -> semantic.color.text.on_accent
```

Theme names therefore belong to theme-map data, not inside canonical Semantic
or Component token IDs.

Auto is a theme-selection policy rather than a third value set. It resolves to
Light or Dark and then uses that theme's complete Semantic map.

## ReaImGui representation

The ReaImGui adapter preserves the canonical hierarchy in nested Lua tables.
The intended mechanical mapping is:

```text
semantic.color.action.primary.default
```

to:

```lua
tokens.semantic.color.action.primary.default
```

A numeric scale segment maps to a numeric table key:

```text
primitive.color.blue.500
```

to:

```lua
tokens.primitive.color.blue[500]
```

The implementation may generate or validate these tables, but it must retain a
traceable relationship to the canonical IDs. Short compatibility names such as
the current `accent` or `muted` may exist temporarily during migration; they are
not new canonical tokens.

## Product usage

Product views choose a component and variant first:

```text
Button
  variant = primary
  label = Publish
```

The Button component resolves its own Component or Semantic tokens. A product
view must not restyle that instance by selecting a Primitive color or inserting
an unexplained size.

A product-local visual exception should first be expressed through composition,
content, or an existing variant. If no shared solution is appropriate, the
exception stays local and documented until repeated evidence justifies a shared
token or variant.

## Change rules

- Adding a token requires a named reusable purpose and an owner layer.
- Two tokens with the same meaning are aliases or one is removed; they do not
  remain independent synonyms.
- Renaming or removing a canonical token is a breaking design-system change and
  requires a migration note.
- Changing a Primitive value is not automatically breaking, but its effect on
  every Semantic reference must be reviewed.
- Changing a Semantic token's meaning is breaking even if its literal value is
  unchanged.
- Component-token changes list the affected variants and states.
- Product behavior is never changed solely to simplify a token map.

## Initial migration boundary

The current `ui/theme.lua` palette is audit input, not the target palette or a
visual-compatibility constraint. The rebuilt Light and Dark themes may replace
its color values as required by DS003. Migration will:

1. classify existing usage by Primitive, Semantic, and Component responsibility;
2. design new theme values against confirmed semantic roles and contrast rules;
3. identify measurements that need a new approved token or should reuse an
   existing one;
4. move product views away from raw visual literals;
5. remove temporary compatibility names only through an explicit migration.

No production token implementation changes are part of DS001 or DS003 itself.
