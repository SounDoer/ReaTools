# Keyboard Navigation and Focus Baseline

Status: Confirmed by DS004 on 2026-10-12.

ReaProjectLink provides a modest keyboard baseline that follows ReaImGui's
native behavior. Keyboard operation is a compatibility and usability safeguard,
not a separate power-user workflow or shortcut system.

## Scope

The baseline applies to every interactive component supplied by the shared
design system. It covers reachability, visible focus, predictable order,
activation, transient UI, and focus restoration.

It does not require:

- application-wide keyboard shortcuts;
- custom key remapping or a shortcut-discovery interface;
- gamepad navigation;
- a custom directional-navigation engine;
- bespoke arrow-key behavior for every composite control;
- screen-reader support beyond what the host and ReaImGui expose.

These capabilities may be proposed later when a confirmed workflow needs them.

## ReaImGui configuration

The application enables ReaImGui's master keyboard-navigation flag when it
creates the UI context. Product views do not disable navigation for ordinary
windows or replace native activation behavior with manual key polling.

This is an implementation requirement for the future design-system migration;
DS004 does not modify production code by itself.

## Focusable content

Every enabled interactive control participates in keyboard navigation:

- buttons and icon buttons;
- checkboxes and other selection controls;
- inputs and editable values;
- combo boxes, menus, and menu items;
- disclosure controls;
- actions inside notices, dialogs, and Reviews.

Static content does not receive focus merely because it is visually prominent.
This includes headings, body text, status labels, decorative icons, cards,
separators, and layout containers.

Disabled controls are omitted from the focus sequence. If an unavailable action
needs an explanation, the explanation is presented in ordinary visible content
or through an accessible enabled control rather than requiring focus on the
disabled item.

## Navigation order

Focus follows the visible reading and task order, normally top to bottom and
left to right. ReaImGui's submission order is kept consistent with that visual
order so native navigation remains predictable.

Product views do not create a separate manual tab-order system. Layout helpers
that visually reposition an action must preserve a sensible submission order,
and overlays must not leave hidden background actions as the apparent next
target.

## Native interaction behavior

Standard ReaImGui controls retain their native keyboard behavior. Components do
not reimplement keys that ReaImGui already handles.

Custom-drawn controls use a real ReaImGui interactive item as their hit target.
They must expose the same enabled, hovered, pressed, and focused states as their
visible counterpart. A DrawList shape alone is never treated as an interactive
control.

The initial Segmented Control may retain its implementation as a row of native
buttons. Bespoke single-tab-stop and arrow-key behavior is not required until a
confirmed workflow or usability test demonstrates the need.

## Visible focus

Every focused interactive control has a visible focus treatment. A custom
component must not draw only a hover treatment because keyboard focus can exist
without pointer hover.

The shared default is a two-logical-unit focus outline drawn without changing
layout. It uses the semantic focus color and meets the DS003 minimum of 3:1
against adjacent colors. The outline remains distinguishable from selected,
warning, blocked, and destructive states.

A standard ReaImGui focus treatment may be retained when it satisfies the same
visibility requirement. Otherwise the component supplements it with the shared
outline.

## Entry, transient UI, and restoration

Ordinary views do not force focus to a control when they open. The user enters
the control sequence through native navigation.

A newly opened modal or focused confirmation places focus on the first safe,
useful control when ReaImGui permits it. A destructive action is not the default
focused action. Menus, combo popups, and dialogs use their native close behavior,
including Escape where supported.

When a transient surface closes, focus returns to its trigger when ReaImGui can
preserve that relationship. Dynamic content changes must not deliberately move
focus to an unrelated control.

## Component contract

Every interactive component specification records:

- whether it participates in navigation;
- its native activation behavior;
- its focused visual state;
- its disabled focus behavior;
- any focus movement when it opens or closes transient content.

Product screens consume those contracts rather than assigning local focus
colors or inventing local keyboard rules.

## Validation

Each component and representative workflow receives a small manual smoke test:

1. enable keyboard navigation and enter the window;
2. traverse enabled controls in visible task order;
3. confirm every focused control is clearly visible in both themes;
4. activate representative standard and custom controls without the pointer;
5. open and close menus, combos, and dialogs;
6. confirm disabled and static content do not create dead stops;
7. confirm closing transient UI does not strand focus on hidden content.

The test verifies the baseline only. It is not a requirement to reproduce every
workflow without a pointer.

## ReaImGui capability references

The installed ReaImGui API exposes the facilities needed by this baseline:
`ConfigFlags_NavEnableKeyboard`, `IsItemFocused`, `SetItemDefaultFocus`,
`SetKeyboardFocusHere`, and interactive items such as `InvisibleButton`.

The current `icon_button` already uses `InvisibleButton`, so its migration needs
a focused visual state rather than a new interaction model. The current context
is created without the keyboard-navigation flag; enabling it belongs to the
later implementation phase.
