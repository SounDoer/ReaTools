# ReaProjectLink Settings Pilot Native Validation — 2026-10-13

Status: Migration implemented under explicit Product-owner authorization on
2026-10-13. The earlier Gallery scene remains a recorded native visual failure;
the migrated product page still requires the matrix below and no native
interaction result is inferred from automated smoke frames.

## Purpose

This is the minimum DS016 matrix for accepting the migrated ReaProjectLink
Settings presentation. It narrows the complete
Gallery runbook to Button, Icon Button, Field Shell, Checkbox, Segmented
Control, Path Selection, and Confirmation Dialog.

The Gallery uses deterministic fixtures. It does not call ReaProjectLink
services, edit the active REAPER project, or write product settings.

## Environment

| Field | Value |
| --- | --- |
| Date | 2026-10-13 |
| Reviewer | Product owner, native review |
| Baseline commit | `4d5fb66`; the candidate is recorded by the commit containing this validation document |
| Operating system | Windows build 22631 |
| REAPER | 7.78 x64 |
| ReaImGui API target | 0.9 |
| Available display scale | 125% (`AppliedDPI` 120), pending inspection |
| Other display scales | 100%, 150%, and 200% unavailable |
| Window mode | Floating Gallery |
| Automation capability | Blocked: Windows app inventory returned no REAPER window |

## Start the Settings component scene

From the ReaTools repository, open the first deterministic scene:

```powershell
./packages/ReaToolUI/gallery/open_gallery.ps1 `
  -Section Components `
  -Theme light `
  -Preview compact
```

Use the Gallery controls to switch between Light and Dark and between Compact,
Standard, and Wide. Restart with explicit launcher parameters when a cell needs
a reproducible initial state.

Open the Patterns section for Path Selection and Confirmation Dialog:

```powershell
./packages/ReaToolUI/gallery/open_gallery.ps1 `
  -Section Patterns `
  -Theme light `
  -Preview compact
```

## Visual matrix

For each row, inspect all seven Settings targets. Pass requires readable text,
clear hierarchy and state, no clipping or overlap, visible focus, and vertical
reflow without primary horizontal scrolling.

| Theme | Preview | Scale | Components | Patterns | Result | Note |
| --- | --- | --- | --- | --- | --- | --- |
| Light | Compact | 125% | Button, Icon Button, Field Shell, Checkbox, Segmented Control | Path Selection, Confirmation Dialog | Blocked | Native window could not be inspected |
| Light | Standard | 125% | Same scope | Same scope | Blocked | Native window could not be inspected |
| Light | Wide | 125% | Same scope | Same scope | Blocked | Native window could not be inspected |
| Dark | Compact | 125% | Same scope | Same scope | Blocked | Native window could not be inspected |
| Dark | Standard | 125% | Same scope | Same scope | Blocked | Native window could not be inspected |
| Dark | Wide | 125% | Not inspected | Path Selection and visible Pattern fixtures | Fail | Interaction recovered after the hidden-modal fix, but the overall hierarchy and visual finish still feel like a development control catalog rather than a polished product system |

## Observed result

The first Patterns navigation attempt became non-interactive because the
Confirmation Dialog fixture opened an invisible modal while entering the
section. The fixture was changed to require an explicit open action, and the
Gallery's ImGui window and child scopes were balanced unconditionally. After
that fix, section switching and scrolling worked in the Dark, Wide, 125% scene.

The reviewer nevertheless rejected the scene visually. The current presentation
is structurally consistent but does not yet establish enough hierarchy,
composition, density control, or product-level finish. This is a blocking
visual failure, not a subjective note attached to a passing cell.

Follow-up candidates in `e789a8c` and `d316ef8` introduced a task-oriented
ReaProjectLink composition, a calibrated spacing hierarchy, explicit adapter
chrome, and additional contrast coverage. These changes pass automated
validation but do not convert the failed native row to Pass. The revised scene
still requires an explicit reviewer result.

After incremental visual tuning proved inefficient, DS019 replaced the custom
Studio Neutral direction with a Radix Themes reference baseline: Slate gray,
Teal accent, solid panels, neutral surface segmented controls, medium radius,
and Radix spacing. Subsequent review clarified that this checkpoint calibrates
shared Foundations and confirmed Components, not a finished Settings page. The
Cross-product Scenario is therefore a provisional integration fixture only;
its navigation, information architecture, and page composition are not shared
contracts and are not being approved by this validation pass. The failed matrix
result remains unchanged until the component baseline receives a new review.

## Interaction matrix

Inspect at least one representative enabled instance of each target with both
pointer and keyboard. Do not infer an interaction result from static rendering.

| Target | Required evidence | Pointer | Keyboard | Result |
| --- | --- | --- | --- | --- |
| Button | Default, hover, pressed, focused, disabled, and danger hierarchy | Blocked | Blocked | Blocked |
| Icon Button | Accessible label, hover, focus, disabled state, and activation | Blocked | Blocked | Blocked |
| Field Shell | Label, description, validation states, long text, and read-only state | Blocked | Blocked | Blocked |
| Checkbox | Checked, unchecked, mixed or not-applicable state, focus, and disabled state | Blocked | Blocked | Blocked |
| Segmented Control | Selection, focus order, disabled option, and Compact reflow | Blocked | Blocked | Blocked |
| Path Selection | Long path access, picker request, validation, edit, and commit | Blocked | Blocked | Blocked |
| Confirmation Dialog | Safe Cancel focus, Enter safety, Escape, close, and focus restoration | Blocked | Blocked | Blocked |

## Completion rule

The Settings pilot is not natively accepted until every applicable 125% cell is
Pass or has a documented, accepted non-blocking platform variation. Unavailable
display scales remain Blocked and do not become Pass by inference. A failure
must record the target, theme, preview, scale, input method, and concise
reproduction.

After a fix, rerun `packages/ReaToolUI/tests/run_validation.ps1` and repeat the
affected manual cells plus any shared Foundation cells the fix can influence.
