# Foundation Consistency Audit — 2026-10-13

Status: In progress. Automated consistency issues found in the first pass have
been corrected. Native visual and interaction evidence remains gated by DS016.

## Scope

This audit checks whether the shared visual foundations control the complete
ReaImGui presentation rather than only individually styled Components. It
covers spacing, typography, shape, color, status, host chrome, focus, and
responsive composition.

## Corrected in this pass

- Page, container, item, section, region, and indentation spacing now have
  separate Semantic responsibilities. ReaImGui item and inner spacing no
  longer come from host defaults.
- Popup background, default borders, separators, scrollbars, Tree and
  Disclosure selection surfaces, disabled opacity, and disabled text now pass
  through the shared adapter and token registry.
- Scrollbar states have a persistent non-text contrast baseline of at least
  3:1 against their track in both themes.
- Popup text retains at least 4.5:1 contrast in both themes.
- Typography, shape, status-token, and keyboard-focus documentation now matches
  the development implementation.

## Reviewed without a new decision

- Motion remains immediate by default and does not currently leak decorative
  animation or unrestricted redraw into Components.
- Status and danger remain separate meanings. Status presentations include a
  readable role label rather than relying on color alone.
- Component-local width decisions use the width actually available to the
  component. Product capability is not hidden by a layout range.
- DrawList icon geometry contains normalized calculations, not reusable raw
  spacing decisions. Icon color and size enter through shared roles.

## Open gates

### Responsive thresholds

DS008 names `semantic.layout.breakpoint.standard` and
`semantic.layout.breakpoint.wide`, but numeric thresholds have not been
confirmed or registered. Gallery preview widths are deterministic review
canvases, not approved product breakpoints. Assigning these values requires a
representative ReaProjectLink composition review and user confirmation.

### Native focus and transient behavior

The Gallery enables native keyboard navigation and the adapter controls the
focus color. Pointer and keyboard traversal, safe modal default focus, Escape,
and focus restoration still require visible DS016 inspection.

### Platform typography and glyphs

The current Windows system-font scene is available for review. macOS, Linux,
CJK coverage, and 100%, 150%, and 200% display-scale evidence remain
unavailable and must not be inferred from automated frames.

## Automated evidence

- ReaToolUI token validation, adapter stack balance, theme parity, text
  contrast, non-text chrome contrast, and 30 deterministic Gallery scenarios
  pass.
- ReaProjectLink and ReaAssetFlow remain unchanged consumers; repository-level
  validation is required after this shared-foundation pass.

