# Typography and Glyph Coverage

Status: Confirmed by DS009 on 2026-10-12. Font-family policy and semantic roles
are confirmed. Provisional first-implementation sizes and weights are assigned;
final calibration remains part of the DS016 native Gallery matrix.

ReaProjectLink uses operating-system font matching rather than shipping a font
file. The primary interface family is the generic `sans-serif` family. A generic
system monospace family may support machine-oriented values when fixed character
width materially improves scanning.

Every enabled language must have verified glyph coverage on its supported host
platforms. A locale is not enabled first and repaired later when missing-glyph
boxes appear.

## Meaning of system sans serif

A sans-serif font has letterforms without the small finishing strokes commonly
called serifs. Familiar comparisons include Segoe UI or Arial versus Times New
Roman for Latin text, and Microsoft YaHei versus SimSun as a rough Chinese
interface comparison.

System means the plugin does not bundle and select its own `.ttf` or `.otf`
file. It requests the generic family name `sans-serif`, and the host font system
and ReaImGui select an installed matching font.

This provides:

- no bundled font binary or font-license obligation;
- smaller package size;
- an appearance familiar to the host platform;
- access to fonts already installed and maintained by the operating system.

It also means:

- the exact typeface may differ across Windows, macOS, and Linux;
- character widths and line metrics may vary slightly;
- the presence of one language's glyphs cannot be assumed from the generic
  family name alone;
- layouts must tolerate normal font-metric differences rather than depending on
  pixel-identical text width.

`sans-serif` does not mean the REAPER theme font, a guaranteed font name, or the
same visual result on every computer. It is a portable request for a category of
installed font.

The existing implementation already calls ReaImGui with the generic
`sans-serif` family. DS009 keeps the family strategy but does not preserve its
existing sizes as final design-system values.

## Family policy

The primary interface family is:

```text
primitive.font_family.sans = system sans-serif
```

Machine-oriented content may use:

```text
primitive.font_family.mono = system monospace
```

Monospace is reserved for content that benefits from fixed character width,
such as identifiers, hashes, aligned technical values, or code-like excerpts.
It is not automatically applied to every file path, timestamp, or numeric
value.

The first version does not bundle a font. Adding one later requires a confirmed
coverage or branding need, license review, package-size review, fallback rules,
and supported-platform rendering validation.

## Semantic text roles

Typography is selected by purpose rather than by requesting a raw font size.
The initial roles are:

| Role | Purpose |
| --- | --- |
| `title` | Primary title of a tool or major Review |
| `heading` | Section, card, or grouped-content heading |
| `body` | Default explanatory and value text |
| `label` | Control, field, and concise action labeling |
| `metadata` | Secondary supporting information |
| `code` | Machine-oriented content that benefits from monospace |

Representative canonical IDs are:

```text
semantic.typography.title
semantic.typography.heading
semantic.typography.body
semantic.typography.label
semantic.typography.metadata
semantic.typography.code
```

Each role resolves a reviewed family, size, weight, and line-height intent. A
Component token is added only when a reusable component needs a stable exception
that a semantic role cannot express accurately.

Product views do not choose raw font sizes, make text bold for visual emphasis
alone, or create one-screen text roles.

## Weight policy

The initial system uses regular and bold weights. Regular supports body,
metadata, and ordinary labels. Bold supports titles, headings, or emphasis with
a clear structural purpose.

Additional named weights are not assumed to exist consistently across every
matched system family. A medium or semibold role requires cross-platform font
matching and rendering evidence before it is added.

Weight does not replace hierarchy, spacing, content, or status semantics. A
warning is not made understandable merely by using bold text.

## Numeric type scale

The pre-design-system sizes `12`, `13`, `14`, and `16` are audit input, not
compatibility requirements. Final sizes are selected by rendering the semantic
roles with representative content and then fitting DS007 control heights and
spacing to those metrics.

The provisional first-implementation mapping is:

| Role | Family | Size | Weight |
| --- | --- | ---: | --- |
| `title` | system sans-serif | 16 | bold |
| `heading` | system sans-serif | 14 | bold |
| `body` | system sans-serif | 13 | regular |
| `label` | system sans-serif | 13 | regular |
| `metadata` | system sans-serif | 12 | regular |
| `code` | system monospace | 13 | regular |

These values are centralized tokens rather than preserved product literals.
Changing them before the first contract release requires the same Gallery and
structural validation, but does not yet constitute a published-contract break.

The numeric scale must:

- distinguish title, heading, body, and metadata without excessive steps;
- keep ordinary text subject to the DS003 4.5:1 contrast rule;
- remain readable at every DS002 display scale;
- tolerate normal cross-platform font-metric variation;
- support the compact-but-readable DS007 density;
- avoid relying on large-text contrast exceptions.

ReaImGui font metrics determine actual rendered line height. Layout tokens add
the surrounding vertical rhythm; product code does not simulate CSS line height
with arbitrary local offsets.

## Glyph coverage

A glyph is the font's drawable form for a character. If a loaded font lacks a
needed glyph, the user may see a square replacement box, a blank, or an
inconsistent fallback.

The initial English interface validates the characters actually required by its
labels, messages, paths, identifiers, and punctuation. It does not request a
large language range merely as a guess about future localization.

Before enabling another locale, the release must:

1. inventory the characters and punctuation used by that locale and by expected
   user data;
2. verify that the selected family and ReaImGui font configuration render them
   on every supported host platform;
3. inspect ordinary, bold, small, and code-like roles;
4. test mixed-language content, paths, project names, and missing-glyph behavior;
5. validate wrapping and truncation across DS008 ranges;
6. decide whether system matching is reliable or whether an approved bundled
   font and fallback strategy is required.

Chinese support therefore requires an explicit CJK coverage pass. The presence
of Chinese fonts on one development machine is not sufficient evidence for all
supported installations.

## Icons and symbols

Interface icons remain DrawList graphics under the current dependency-free icon
strategy. Emoji and special font symbols are not used as required UI icons
because their appearance and availability vary by system font.

A textual symbol may be used only when it is ordinary content, present in the
validated glyph set, and not the sole carrier of an action or status meaning.

## Layout and truncation

Text components measure the active font at runtime. They do not assume that a
label has the same width on all systems.

- User-facing messages wrap when space permits.
- Critical status and validation text is not silently clipped.
- A truncated path or identifier provides a defined way to inspect or copy the
  complete value.
- Fixed-width columns are validated with the widest representative labels or
  replaced with responsive composition.
- Font-family differences must not change which product capabilities are
  available.

Detailed truncation behavior for structured and long data is defined by DS014.

## Validation

Typography validation covers:

- every semantic text role in regular and required bold forms;
- both rebuilt themes and DS003 contrast pairings;
- short, typical, and long labels;
- paths, identifiers, numbers, and mixed punctuation;
- all enabled languages and mixed-language user data;
- Compact, Standard, and Wide layouts under DS008;
- 100%, 125%, 150%, and 200% display scaling under DS002;
- Windows, macOS, and Linux for each platform the product declares supported.

No production font, size, or glyph configuration is changed by DS009 itself.
