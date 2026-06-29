# SuperOverlay

SuperOverlay is a Flutter overlay package built on a self-managed
`OverlayEntry` tree. It provides custom dialogs, loading indicators, toasts,
target-attached popups, highlighted masks, notifications, route binding, and
back-button handling without requiring a package-owned `Navigator` key.

## Install

```yaml
dependencies:
  super_overlay: ^0.1.0-dev.1
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

## Loading, Toast, Popup, And Notify

```dart
await SuperOverlay.showLoading(msg: 'Loading...').fire();

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

## Migration Notes

This rewrite is not compatible with the initial route-based API. The package no
longer exposes `SuperOverlay.navigatorKey`, `show(content:)`,
`showToast(msg:)`, or `showPopup(content:)`.

The project is MIT licensed. `THIRD_PARTY_NOTICES.md` records the MIT notice for
reference implementation ideas used during the rewrite.
