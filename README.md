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

## Migration Notes

This rewrite is not compatible with the initial route-based API. The package no
longer exposes `SuperOverlay.navigatorKey`, `show(content:)`,
`showToast(msg:)`, or `showPopup(content:)`.

The project is MIT licensed. `THIRD_PARTY_NOTICES.md` records the MIT notice for
reference implementation ideas used during the rewrite.
