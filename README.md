# SuperOverlay

SuperOverlay is a Flutter overlay package built on a self-managed
`OverlayEntry` tree. It provides custom dialogs, loading indicators, toasts,
target-attached popups, highlighted masks, notifications, route binding, and
back-button handling without requiring a package-owned `Navigator` key.

## Install

```yaml
dependencies:
  super_overlay: ^0.1.1
```

## Initialize

Add `SuperOverlayInit.init()` to `MaterialApp.builder` and register
`SuperOverlayInit.observer` so page-bound overlays can react to route changes.

```dart
MaterialApp(
  builder: SuperOverlayInit.init(),
  navigatorObservers: [SuperOverlayInit.observer],
  home: const AppHome(),
);
```

The package entrypoint exports the intended consumer API, including
configuration classes, public enums, `SuperOverlayController`, `AnimationParam`,
popup geometry extension types, and default feedback builder types.

## Requirements

SuperOverlay requires Dart `^3.11.4` and Flutter `>=3.41.0`.

## Global Configuration

Tune defaults before showing overlays. Per-call builder methods still override
the global defaults.

```dart
SuperOverlay.config.custom = const CustomDialogConfig(
  animationTime: Duration(milliseconds: 160),
  debounce: true,
  debounceTime: Duration(milliseconds: 500),
  bindPage: true,
);

SuperOverlay.config.toast = const ToastConfig(
  displayTime: Duration(seconds: 2),
  debounce: true,
);
```

## Custom Overlay

```dart
final result = await SuperOverlay.show(
  builder: (_) => const MyDialog(),
)
    .withTag('profile')
    .withMask(dismissible: true)
    .withBack(type: BackType.normal)
    .fire<String>();

await SuperOverlay.dismiss(
  status: DismissStatus.auto,
  tag: 'profile',
  result: 'closed',
);
```

Permanent overlays are skipped by normal untagged dismiss calls and by
`allDialog`/`allCustom` cleanup. Close them explicitly with their tag and
`force: true` when the owning flow is finished.

```dart
SuperOverlay.show(
  builder: (_) => const BlockingDialog(),
).withTag('blocking-flow').withPermanent().fire<void>();

await SuperOverlay.dismiss(tag: 'blocking-flow', force: true);
```

## Loading, Toast, Popup, And Notify

```dart
SuperOverlay.showLoading(msg: 'Loading...').fire();
await SuperOverlay.dismiss(status: DismissStatus.loading);

await SuperOverlay.showToast('Saved').fire();

await SuperOverlay.showPopup(
  targetContext: targetContext,
  builder: (_) => const PopupMenu(),
).withHighlight().fire();

await SuperOverlay.showNotify(
  msg: 'Done',
  type: NotifyType.success,
).fire();
```

## Popup Target Points

Popups can attach to a widget context, a custom target point derived from that
context, or a target point without a target widget.

```dart
await SuperOverlay.showPopup(
  targetContext: targetContext,
  builder: (_) => const PopupMenu(),
)
    .withTargetPoint((targetOffset, targetSize) {
      return targetOffset + Offset(0, targetSize.height + 8);
    })
    .fire<void>();

await SuperOverlay.showPopup(
  builder: (_) => const PopupMenu(),
).withTargetPoint((_, _) => const Offset(240, 180)).fire<void>();
```

Corner popups can align inside the target edge, centered on the target edge, or
outside the target edge. Popup geometry is clamped when it would leave the
screen.

```dart
await SuperOverlay.showPopup(
  targetContext: targetContext,
  builder: (_) => const PopupMenu(),
)
    .withAlignment(Alignment.bottomLeft)
    .withAlignmentMode(PopupAlignmentMode.center)
    .fire<void>();
```

Replacement and adjustment hooks can react to measured target and popup
geometry.

```dart
await SuperOverlay.showPopup(
  targetContext: targetContext,
  builder: (_) => const PopupMenu(),
)
    .withReplacement((info) {
      return PopupMenu(anchor: info.targetOffset, size: info.popupSize);
    })
    .withAdjustment((info) {
      return const PopupAdjustment(alignment: Alignment.centerRight);
    })
    .withScaleOrigin((popupSize) => Offset(popupSize.width, 0))
    .fire<void>();
```

Mask ignore areas apply only to the popup mask layer, so uncovered app chrome can
continue receiving input.

```dart
SuperOverlay.config.attach = const AttachDialogConfig(
  nonAnimationTypes: [NonAnimationType.highlightMask],
);

await SuperOverlay.showPopup(
  targetContext: targetContext,
  builder: (_) => const PopupMenu(),
)
    .withHighlight()
    .withMaskIgnoreArea(const Rect.fromLTRB(0, 0, 0, 80))
    .fire<void>();
```

## Default Feedback Builders

Applications can set default loading, toast, and notify rendering during
initialization. Per-call builders still take precedence.

```dart
MaterialApp(
  builder: SuperOverlayInit.init(
    toastBuilder: (message) => Text('Toast: $message'),
    loadingBuilder: (message) => Text('Loading: $message'),
    notifyStyle: NotifyStyle(
      successBuilder: (message) => Text('Success: $message'),
    ),
  ),
  navigatorObservers: [SuperOverlayInit.observer],
  home: const AppHome(),
);
```

## Await Semantics

By default, custom overlays, popups, loading indicators, and notifications
complete their `fire()` future after dismissal. Toasts complete after scheduling
by default so lightweight feedback calls do not pretend to represent dismissal.

Use `.withAwait(...)` when a call site needs different completion timing:

```dart
await SuperOverlay.show(
  builder: (_) => const MyDialog(),
).withAwait(AwaitCompletion.appear).fire<void>();

await SuperOverlay.showToast('Saved')
    .withAwait(AwaitCompletion.dismiss)
    .fire<void>();
```

`AwaitCompletion.dismiss` is the only mode whose result value is meaningful.

## Network State And Empty Pages

`super_overlay` keeps empty and error pages in the application layer. Use
overlay loading for short blocking requests, toast or notify for lightweight
feedback, and render empty/error states inside the page that owns the data.

The example app includes a `Network State Demo` that follows this split:

```dart
SuperOverlay.showLoading(msg: 'Loading...').fire();
try {
  final items = await loadItems();
  // Render list, empty page, or error page in your own widget tree.
} finally {
  await SuperOverlay.dismiss(status: DismissStatus.loading);
}
```

## Route And Widget Binding

Custom overlays and popups bind to the current page by default. When a new route
covers that page, the bound overlay hides; when the page returns, it reappears.
When the bound route is removed, the overlay is removed as well.

```dart
await SuperOverlay.show(
  builder: (_) => const Text('Bound'),
).bindPage().fire();

await SuperOverlay.show(
  builder: (_) => const Text('Follows target'),
).bindWidget(targetContext).fire();
```

## Compatibility With Reference Ideas

SuperOverlay is a breaking rewrite, not a compatibility layer for another
package or the initial route-based API. The fluent builder API is the intended
public API, reference-project names are not copied into current-project APIs,
and `useSystem` remains out of scope unless a later requirement proves it is
needed. See `doc/reference-comparison.md` for the reference comparison used to
scope this rewrite.

## Migration Notes

This rewrite is not compatible with the initial route-based API. The package no
longer exposes `SuperOverlay.navigatorKey`, `show(content:)`,
`showToast(msg:)`, or `showPopup(content:)`.

The project is MIT licensed. `THIRD_PARTY_NOTICES.md` records the MIT notice for
reference implementation ideas used during the rewrite.
