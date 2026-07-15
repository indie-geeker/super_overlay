# Example English, Safe Notification, and Popup Motion Design

## Goal

Make the complete example application English-only, keep the first home card
focused on end-user feedback scenarios, protect top notifications from physical
display cutouts, and make anchored popups reveal from the target-facing edge.

## Approved scope

- Translate all user-visible copy under `example/lib`, including the home page,
  secondary pages, overlay surfaces, status messages, and fake data.
- Remove refresh/integration controls from the first Instant Feedback card.
  The advanced Control Lab remains the place for handle, refresh, lifecycle,
  and policy demonstrations.
- Fix notification cutout protection in the shared overlay layout rather than
  adding a device-specific example offset.
- Change the default attached-popup animation to an edge-anchored size reveal.
- Do not add a new public popup animation option or a compatibility shim.

## Design

### Physical safe area

`OverlayDialogWidget` currently relies on `SafeArea`, which reads
`MediaQuery.padding`. That is sufficient in the existing widget tests, but it
can be zero after an ancestor consumes the padding even while
`MediaQuery.viewPadding` still reports a physical cutout. The overlay will give
`SafeArea.minimum` the physical left, top, and right view padding. `SafeArea`
will take the larger of the inherited padding and this minimum, so normal
layouts are unchanged and consumed padding cannot place a notification behind
a cutout. Bottom behavior remains driven by the normal safe padding so keyboard
handling is not widened by this change.

The example notification builder retains its 12 logical-pixel top inset. This
creates a visual gap after the physical safe area rather than serving as the
cutout protection itself.

### English-only example

Every user-visible string in `example/lib` will be translated to concise
English. Existing scenario names stay product-oriented: feedback, anchored
menus, dialogs, network state, guided masks, lifecycle behavior, control-lab
contracts, and nested navigation. Public API identifiers such as
`refreshActive`, `handle.refresh()`, and `navigatorObserver()` remain unchanged
where advanced pages intentionally teach those APIs.

A source-level test will reject Han characters under `example/lib`. Existing
widget tests will be updated to assert the English labels they interact with.
This keeps navigation and behavior coverage coupled to the displayed copy.

### First-card simplification

`InstantFeedbackPanel` will keep:

- the three Toast display policies;
- one action that runs the selected scenario;
- a user-facing status banner;
- the notification type selector and show action.

It will remove the refresh-contract section, its long-lived Toast handles,
refresh counters, refresh tags, buttons, and disposal work. Those controls are
integration details and duplicate the advanced Control Lab's purpose.

### Anchor-aware popup motion

The default `AttachDialogConfig.animationType` will become
`AnimationType.size`. `SizeAnimation` will derive both its axis and its fixed
edge from the popup's effective target alignment:

- below target (`bottom*`): fix the popup's top edge and expand downward;
- above target (`top*`): fix the bottom edge and expand upward;
- right of target (`centerRight`): fix the left edge and expand rightward;
- left of target (`centerLeft`): fix the right edge and expand leftward.

`AttachDialogWidget` already rebuilds with its effective alignment after
geometry adjustment, so the reveal origin follows a popup that flips to another
side because of available space.

## Error and lifecycle behavior

No dismissal, mask, focus, route-binding, replacement, or target-tracking
semantics change. Popup target loss continues through the existing unavailable
target path. Notification strategy and duration behavior remain unchanged.

## Verification

Implementation will follow red-green-refactor cycles for:

1. a consumed-padding notification case where `padding.top == 0` and
   `viewPadding.top > 0`;
2. below/above and left/right size-reveal origins;
3. absence of integration controls from the first card;
4. absence of Han characters from `example/lib` and updated English widget
   flows.

Final verification will include formatting, package analysis/tests, example
analysis/tests, and a source scan for untranslated display copy.
