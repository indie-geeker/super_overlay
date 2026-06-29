# SuperOverlay

SuperOverlay is a Flutter overlay package built around a self-managed
`OverlayEntry` tree. The development rewrite intentionally removes the older
Navigator route API and exposes initialization through `SuperOverlayInit`.

## Initialization

```dart
MaterialApp(
  builder: SuperOverlayInit.init(),
  navigatorObservers: [SuperOverlayInit.observer],
  home: const AppHome(),
);
```

## Usage

```dart
await SuperOverlay.show(builder: (_) => const MyDialog())
    .withTag('profile')
    .withMask(dismissible: true)
    .fire<String>();

await SuperOverlay.showLoading(msg: 'Loading...').fire();
await SuperOverlay.showToast('Saved').fire();
await SuperOverlay.showPopup(
  targetContext: targetContext,
  builder: (_) => const PopupMenu(),
).fire();
await SuperOverlay.showNotify(msg: 'Done', type: NotifyType.success).fire();

await SuperOverlay.dismiss(status: DismissStatus.auto, tag: 'profile');
final exists = SuperOverlay.checkExist(tag: 'profile');
```

## Migration Notes

This rewrite is not compatible with the initial route-based API. The package no
longer exposes `SuperOverlay.navigatorKey`, `show(content:)`,
`showToast(msg:)`, or `showPopup(content:)`.
