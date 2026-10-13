# Motion and Activity Feedback

Status: Confirmed by DS010 on 2026-10-12.

The first design-system version does not require animation. State changes,
activity, progress, and results must remain understandable through persistent
text, component state, and other non-motion cues.

Motion may be added later when it materially communicates continuity or ongoing
activity. It is never added solely to decorate the interface or make an ordinary
state change feel more elaborate.

## Motion purposes

A motion proposal is valid only when it serves at least one of these purposes:

- show that an operation is still active when progress cannot be measured;
- show continuity between two states whose relationship would otherwise be
  unclear;
- direct attention to a meaningful state change without obscuring other work.

Motion is not used to:

- decorate an idle screen;
- make buttons, cards, or menus feel more playful;
- repeatedly attract attention to a stable status;
- compensate for unclear labels, hierarchy, or feedback;
- delay an operation or its result;
- convey information that disappears when animation is disabled.

## First version behavior

The first version uses immediate state changes by default:

- hover, pressed, selected, focused, disabled, and validation styles change
  without a required transition;
- cards and responsive layouts reflow without sliding animation;
- menus, combos, notices, and Reviews do not require fade or scale transitions;
- loading and checking states use explicit readable text;
- determinate progress uses a stable progress value and label when a workflow
  exposes meaningful progress;
- success and error feedback follows its visibility and dismissal rules without
  requiring animated entry or exit.

The existing `Checking...` label and timed toast are examples of state and
feedback timing, not animation. Their current wording and four-second lifetime
remain audit input rather than design-system requirements.

## Activity indicators

An indeterminate activity indicator may be introduced only when an operation
lasts long enough that static status alone is insufficient. It must be paired
with descriptive text such as `Checking references...`; a moving spinner without
a label is not the complete status.

The static fallback shows the same text and state. Pausing or removing motion
must not make the operation look idle, completed, or failed.

Determinate progress is preferred when the application has honest measurable
progress. The design must not animate toward invented percentages or smooth
over a stalled operation in a way that misrepresents its state.

## Reduced motion

Because the first version requires no animation, it does not need a separate
Reduced Motion preference.

Any future motion must define a reduced or static behavior before adoption. If
the supported host reliably exposes an operating-system reduced-motion
preference, the implementation follows it. If it does not, nonessential motion
defaults to the static behavior unless a justified product-level preference is
approved.

Reduced behavior preserves information, focus, reading order, and completion
feedback. It removes or simplifies motion; it does not remove the underlying
state change.

## Timing and performance

Animation timing uses an elapsed monotonic time source rather than frame counts.
The implementation does not assume a stable frame rate.

Motion must not:

- block input or workflow execution;
- keep expensive work active while the window is hidden or the animation is no
  longer visible;
- create an unrestricted redraw loop for decorative content;
- change layout on every frame when a paint-only treatment is sufficient;
- make a low frame rate produce a different final state.

A proposed animation records its start condition, stop condition, maximum
duration, interruption behavior, static fallback, and rendering cost.

## Duration tokens

DS010 does not approve a numeric motion-duration scale because the first version
has no required transitions. The `duration` and `motion` token categories remain
reserved for a confirmed future animation.

Feedback lifetime is a separate responsibility. For example, how long a success
toast remains visible is a feedback-policy token, not automatically a motion
duration. Error feedback that requires action does not disappear merely because
a duration elapsed.

When motion tokens are introduced, components consume semantic purposes rather
than choosing milliseconds directly:

```text
semantic.motion.duration.state_change
semantic.motion.duration.activity_cycle
```

These examples reserve naming shape only; they are not approved tokens or
values.

## Component contract

A component with future motion records:

- the information the motion communicates;
- the non-motion cue carrying the same information;
- start, completion, cancellation, and interruption behavior;
- focus behavior during the change;
- reduced or static behavior;
- whether the motion affects paint only or changes layout;
- the semantic timing token it consumes.

Product views do not add local transitions or animation loops to shared
components.

## Validation

Any future animated component is checked for:

- complete understanding with motion disabled;
- predictable completion under variable frame rates;
- interruption by navigation, cancellation, window closure, and repeated
  activation;
- no loss or unexpected movement of DS004 focus;
- acceptable rendering cost alongside REAPER workloads;
- both rebuilt themes and DS002 display scales;
- long-running, instant, failed, and cancelled operations.

No production animation, toast lifetime, or loading behavior is changed by
DS010 itself.
