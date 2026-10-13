# Destructive Confirmation Pattern

Status: Confirmed by DS013 on 2026-10-12.

Potentially destructive actions use the least disruptive safeguard that makes
their consequence understandable. The system chooses among direct execution,
a focused Confirmation Dialog, and an Inline Review according to consequence,
recoverability, scope, surprise, and the amount of context required.

Danger intent under DS005 identifies the action's consequence. It does not
automatically determine which confirmation form is appropriate.

## Decision factors

Choose a safeguard by evaluating:

- **Recoverability:** Can the result be undone or restored reliably?
- **Scope:** Does it affect one local object or many projects, files, objects,
  or external resources?
- **Surprise:** Is the consequence an obvious result of the action label and
  current context?
- **Immediacy:** Does activation perform the change immediately or enter a
  reviewable preparation step?
- **Complexity:** Can the consequence be understood in one short message, or
  must the user inspect issues, previews, and choices?
- **External effect:** Does it change storage, REAPER, Wwise, NAS content, or
  another system that may not share local recovery behavior?

Color, the presence of a `danger` variant, or the technical API used to execute
the action is not sufficient by itself.

## Safeguard levels

### Direct execution

Execute directly when the action is low consequence, readily reversible, and
unsurprising in context. Show an immediate result and provide Undo when a real,
reliable undo operation exists.

Do not add a confirmation merely to protect routine navigation, selection,
refresh, preview, or harmless configuration changes. Repeated low-value prompts
train users to approve dialogs without reading them.

The absence of a dialog does not remove the need for an explicit action label,
disabled-state rules, result feedback, and error recovery.

### Confirmation Dialog

Use a focused Confirmation Dialog when one isolated action has a material but
compact, readily explained consequence. Typical cases include deleting one
preset, resetting local tool state, detaching one association, or overwriting a
known target whose scope fits in one message.

The dialog answers:

- what action will occur;
- which target or scope is affected;
- what will be lost, replaced, detached, or reset;
- whether recovery is possible;
- what the user can do instead.

A dialog is not used when the user needs a table, preview, several decisions,
or issue-by-issue correction to understand the operation.

### Inline Review

Use an Inline Review when the operation already has a preparation or review
stage, affects multiple targets, contains several risks or choices, or requires
preview and correction before completion.

The Review keeps consequence next to the relevant item and allows the user to:

- understand scope and summary;
- inspect warning and blocked conditions;
- resolve required choices;
- preview mappings, paths, or affected records;
- return to editing without losing context;
- execute one clearly labeled completion action after requirements are met.

Do not stack a sequence of confirmation dialogs after a Review has already made
the same consequences clear. A newly discovered blocking condition returns to
the Review or error state instead of producing another generic approval prompt.

## Decision matrix

| Situation | Default safeguard |
| --- | --- |
| Low consequence, obvious, reliably reversible | Direct execution with result feedback |
| One target, material consequence, short explanation | Confirmation Dialog |
| Multiple targets, choices, warnings, or preview required | Inline Review |
| Operation cannot proceed safely | Blocked state; confirmation cannot override it |
| Warning can be accepted after informed review | Dialog or Inline Review according to scope |
| Consequence changes after confirmation | Stop and present the new consequence before execution |

Typed confirmation, countdowns, repeated confirmation, and `I understand`
checkboxes are not part of the initial Pattern. They require evidence that the
ordinary dialog or Review cannot make an unusually severe consequence safe and
understandable.

## Confirmation Dialog anatomy

A shared Confirmation Dialog contains:

1. a concise consequence-oriented title;
2. a message naming the target and material result;
3. optional secondary detail required to judge recovery or scope;
4. one explicit confirming action;
5. one clear Cancel action;
6. optional safe alternative only when it directly resolves the situation.

The title and confirming action use specific verbs:

```text
Delete preset
Reset ReaProjectLink state
Detach source project
Overwrite existing Wwise objects
```

Avoid generic titles and actions such as:

```text
Are you sure?
Warning
Yes
OK
Continue
```

The message does not repeat the button label without adding consequence. It
names the affected target wherever practical.

## Focus and dismissal

The dangerous confirming action is not the initial focus. The first safe useful
control, normally Cancel, receives default focus under DS004.

- Escape cancels without executing when the host permits it.
- Closing the dialog is equivalent to Cancel.
- Enter must not accidentally confirm merely because the dialog opened.
- Focus remains trapped within a modal Confirmation Dialog and returns to the
  trigger after dismissal where ReaImGui supports it.
- Background controls do not appear actionable while the modal is active.

The confirming action uses the DS005 danger intent when the consequence is
destructive. Cancel remains visually secondary but clearly available.

## Execution state

After confirmation:

- prevent duplicate activation while the operation is running;
- retain enough context to report failure and recovery;
- use DS010 static activity feedback before considering animation;
- close the dialog when responsibility has transferred clearly to an operation
  status, or keep it present in a non-editable running state when closure would
  lose essential context;
- report partial completion explicitly rather than presenting a generic success;
- do not ask for the same confirmation again unless the consequence or target
  materially changed.

A failed action does not imply that the user's original confirmation remains
valid forever. Retry may reuse it only while target, scope, and consequence are
unchanged and still visible.

## Warning, blocked, and danger

The three concepts remain independent:

- `warning` describes a condition that needs attention but may permit progress;
- `blocked` describes a condition that prevents safe or correct continuation;
- `danger` describes the consequence of activating an action.

A warning may accompany a safe action. A dangerous action may exist in a ready
state. A blocked condition cannot be bypassed merely by styling an action as
dangerous or adding a confirmation.

Every presentation includes readable consequence text and a persistent
non-color cue under DS003 and DS005.

## Product examples

| Product case | Default pattern | Reason |
| --- | --- | --- |
| Delete one ReaAssetFlow preset | Confirmation Dialog | Isolated file deletion with compact scope |
| Reset ReaProjectLink local state | Confirmation Dialog | Material local reset that fits one consequence message |
| Detach a ReaProjectLink association | Confirmation Dialog or existing Review | Depends on whether affected state needs inspection |
| ReaAssetFlow multi-track merge risk | Inline Review | Multiple selected items and structural consequence need preview |
| ReaAssetFlow duplicate Wwise paths | Inline Review | Collision groups need item-level inspection and correction |
| ReaAssetFlow replace-existing transfer | Inline Review for multi-object scope | External destructive effect and previewable target set |
| ReaProjectLink publish or sync decisions | Existing Review Pattern | Multiple conditions and choices are already reviewed |
| Refresh a preview or cached list | Direct execution | Expected, low-consequence operation |

These mappings are defaults. Product specifications determine actual
recoverability, scope, and behavior before implementation.

## Host dialog fallback

An operating-system or REAPER message box may remain as a temporary migration
fallback. A conforming shared Confirmation Dialog is preferred when the native
API cannot provide specific action labels, focus behavior, wrapped detail, or
consistent theme treatment.

Fallback use does not weaken consequence wording or safeguard selection. It is
recorded as an implementation limitation rather than becoming the design-system
contract.

## Validation

Each destructive flow is tested for:

- correct safeguard selection at realistic scope;
- explicit target and consequence wording;
- safe default focus, Escape, close, and focus restoration;
- duplicate activation prevention;
- success, failure, cancellation, and partial-completion feedback;
- changed target or scope between trigger and execution;
- both themes, DS008 layout ranges, and long paths or names;
- no reliance on color alone;
- no redundant confirmation after a complete Inline Review.

No production confirmation flow is changed by DS013 itself.
