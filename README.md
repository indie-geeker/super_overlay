# SuperOverlay

SuperOverlay is a Flutter package for app-level overlays backed by a
self-managed `OverlayEntry` tree. It provides command-style dialogs, loading
indicators, toasts, target-attached popups, highlighted masks, notifications,
route binding, widget binding, and back-button policies without requiring a
package-owned `Navigator` key.

## Quick Start

Add the package:

```yaml
dependencies:
  super_overlay: ^0.2.0
```

SuperOverlay requires Dart `>=3.7.0 <4.0.0` and Flutter `>=3.29.0`.

Initialize the overlay host once at the app root:

```dart
import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: SuperOverlay.init(),
      navigatorObservers: [SuperOverlay.observer],
      home: const AppHome(),
    );
  }
}
```

Show overlays through command services and keep the returned handle when the
calling flow owns the overlay lifecycle:

```dart
final loading = SuperOverlay.loading.show(message: 'Syncing...');
try {
  await syncProfile();
  SuperOverlay.toast(
    'Saved',
    options: const OverlayToastOptions(
      displayPolicy: OverlayToastDisplayPolicy.replaceLatest,
    ),
  );
} finally {
  await loading.close();
}
```

Dialogs return a typed result through `OverlayHandle.closed`:

```dart
final handle = SuperOverlay.dialog.show<bool>(
  builder: (_) => const ConfirmDeleteDialog(),
  options: const OverlayDialogOptions(
    tag: 'delete-confirmation',
    strategy: OverlayStrategy.replaceExisting,
    backBehavior: OverlayBackBehavior.dismiss,
  ),
);

final confirmed = await handle.closed;
```

Inside dialog content, close by handle when possible. For content that does not
receive a handle, close by target and tag:

```dart
await SuperOverlay.close(
  target: OverlayCloseTarget.dialog,
  tag: 'delete-confirmation',
  result: true,
);
```

## Production Recipes

### Default Feedback Styling

Applications can configure default loading, toast, and notification rendering
during initialization. Per-call builders still take precedence.

```dart
MaterialApp(
  builder: SuperOverlay.init(
    toastBuilder: (message) => AppToast(message: message),
    loadingBuilder: (message) => AppLoading(message: message),
    notifyStyle: NotifyStyle(
      successBuilder: (message) => AppBanner.success(message),
      errorBuilder: (message) => AppBanner.error(message),
    ),
  ),
  navigatorObservers: [SuperOverlay.observer],
  home: const AppHome(),
);
```

### Loading Plus Page-Owned Empty And Error States

Use overlays for transient request state and keep durable empty or error pages
inside the route that owns the data.

```dart
final loading = SuperOverlay.loading.show(
  message: 'Loading products...',
  options: const OverlayLoadingOptions(
    minimumVisibleDuration: Duration(milliseconds: 500),
    backBehavior: OverlayBackBehavior.block,
  ),
);

try {
  final products = await repository.loadProducts();
  setState(() {
    items = products;
    error = null;
  });
} catch (error) {
  setState(() {
    items = const [];
    this.error = error;
  });
  SuperOverlay.notify.error('Products could not be loaded');
} finally {
  await loading.close();
}
```

### Anchored Popup

Attach popups to a target context for menus, filters, or lightweight editors:

```dart
final handle = SuperOverlay.popup.show<void>(
  targetContext: buttonContext,
  builder: (_) => FilterPopup(onApply: applyFilters),
  options: const OverlayPopupOptions(
    tag: 'product-filter',
    alignment: Alignment.bottomCenter,
    strategy: OverlayStrategy.replaceExisting,
  ),
);

await handle.visible;
```

For geometry-sensitive popups, provide typed hooks:

```dart
SuperOverlay.popup.show<void>(
  targetContext: targetContext,
  builder: (_) => const ToolbarMenu(),
  options: OverlayPopupOptions(
    tag: 'toolbar-menu',
    alignment: Alignment.bottomLeft,
    alignmentMode: OverlayPopupAlignmentMode.center,
    targetRectBuilder: (rect) => rect.inflate(4),
    replacementBuilder: (info) {
      return ToolbarMenu(width: info.popupSize.width);
    },
    adjustmentBuilder: (_) {
      return const PopupAdjustment(alignment: Alignment.topRight);
    },
    scaleOriginBuilder: (size) => Offset(size.width, 0),
  ),
);
```

`maskIgnoreArea` removes one exact rectangle from the popup mask's hit-test
area. Coordinates are relative to the overlay host, so the underlying UI
receives pointer events only inside that rectangle:

```dart
SuperOverlay.popup.show<void>(
  options: const OverlayPopupOptions(
    targetPointBuilder: menuAnchor,
    maskIgnoreArea: Rect.fromLTWH(16, 16, 240, 48),
  ),
  builder: (_) => const ToolbarMenu(),
);
```

### Guided Highlight

Use popup highlighting when the user must interact with a specific target while
the rest of the screen is masked.

```dart
SuperOverlay.popup.show<void>(
  targetContext: targetContext,
  builder: (_) => const GuideBubble(),
  options: OverlayPopupOptions(
    tag: 'onboarding-step',
    dismissOnMaskTap: false,
    highlightTarget: true,
    highlightMaskColor: const Color(0x99000000),
    highlightPadding: const EdgeInsets.all(8),
    highlightBorderRadius: BorderRadius.circular(8),
  ),
);
```

### Route And Widget Binding

Dialogs and popups bind to the current route by default. They hide while another
route covers that page, reappear when the page returns, and close when the route
is removed. Register `SuperOverlay.observer` for this behavior.

Bind a dialog to a widget when the overlay must not outlive that widget:

```dart
SuperOverlay.dialog.show<void>(
  builder: (_) => const FieldHelpDialog(),
  options: OverlayDialogOptions(
    tag: 'field-help',
    bindToWidget: fieldContext,
    alignment: Alignment.bottomCenter,
    barrierColor: Colors.transparent,
    dismissOnMaskTap: false,
    consumeEvents: false,
  ),
);
```

### Global Cleanup

Prefer `handle.close()` for owned overlays. Use `SuperOverlay.close` for global
cleanup, tagged content buttons, or tests:

```dart
await SuperOverlay.close(target: OverlayCloseTarget.allToasts);

await SuperOverlay.close(
  target: OverlayCloseTarget.allDialogs,
  tag: 'checkout',
  force: true,
);
```

Check existence with typed surfaces:

```dart
final hasCheckoutOverlay = SuperOverlay.exists(
  tag: 'checkout',
  surfaces: const {OverlaySurface.dialog, OverlaySurface.popup},
);
```

## Contracts And Limits

SuperOverlay exposes a command-oriented public API from
`package:super_overlay/super_overlay.dart`. The supported entrypoints are
`SuperOverlay.init`, `SuperOverlay.observer`, `SuperOverlay.dialog`,
`SuperOverlay.loading`, `SuperOverlay.popup`, `SuperOverlay.notify`,
`SuperOverlay.toast`, `SuperOverlay.close`, `SuperOverlay.exists`, typed option
objects, and `OverlayHandle`.

`OverlayHandle.visible` completes only after the overlay's first rendered
frame. It fails with `StateError` if the request is rejected or closes before
rendering, such as when a popup target is detached or has invalid geometry.
`OverlayHandle.closed` still completes once with the optional result. Calling
`close()` more than once is safe.

Tags are business identifiers. Use `OverlayStrategy.replaceExisting` when only
one overlay for a flow should exist, `OverlayStrategy.keepExisting` when repeated
commands should reuse the active overlay, and `OverlayStrategy.stack` when
multiple overlays are intentional. Same-tag replacements are serialized, so
multiple commands issued in one event-loop turn leave the latest replacement
active. A tag reused through `keepExisting` must keep the same dialog or popup
result type; an incompatible generic result type throws `StateError` instead of
failing later with a cast error.

Removing or replacing the widget that hosts `SuperOverlay.init()` closes active
handles and clears init-level builders. Mounting a new host starts from the
package defaults unless that host supplies new builders.

Toasts are transient feedback. Empty pages, error pages, and durable network
state belong in your application widget tree.

This package intentionally stays UI-runtime lightweight: it has no runtime
dependencies beyond the Flutter SDK and does not install a global navigator key.

The current command API is a breaking public surface. Older fluent-builder,
configuration-mutation, and route-key APIs are not part of the supported
entrypoint.

## Example And Contributing

The [example app](example/README.md) is organized around common scenarios,
interaction enhancements, and advanced capabilities. It includes Toast policy
comparisons, one-at-a-time notifications, anchored dropdown and upward menus,
route/widget lifecycle cases, and an Overlay Control Lab for strategies,
Handle-owned refresh/close, lifecycle futures, scoped cleanup, and advanced
popup geometry.

Automated tests simulate safe-area padding and responsive widths. Physical
cutout-device checks remain a separate release step documented in the example
[device matrix](tool/verification/example_device_matrix.md).

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup and release-gate commands. Use
the [security policy](SECURITY.md) for private vulnerability reports.

## License

SuperOverlay is MIT licensed.
