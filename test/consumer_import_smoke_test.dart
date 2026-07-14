import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

void main() {
  test('package entrypoint exports command API contracts', () {
    expect(SuperOverlay.init, isA<TransitionBuilder Function()>());
    expect(SuperOverlay.observer, isA<NavigatorObserver>());

    final SuperOverlayIntegration integration = SuperOverlay.integration();
    final SuperOverlayNavigatorObserver rootObserver = integration.observer;
    final SuperOverlayNavigatorObserver scopedObserver =
        integration.navigatorObserver();
    expect(integration.builder, isA<TransitionBuilder>());
    expect(rootObserver, isNot(same(scopedObserver)));
    scopedObserver.dispose();
    integration.dispose();

    final OverlayLoadingService loading = SuperOverlay.loading;
    final OverlayDialogService dialog = SuperOverlay.dialog;
    final OverlayPopupService popup = SuperOverlay.popup;
    final OverlayNotifyService notify = SuperOverlay.notify;
    expect(loading, same(SuperOverlay.loading));
    expect(dialog, same(SuperOverlay.dialog));
    expect(popup, same(SuperOverlay.popup));
    expect(notify, same(SuperOverlay.notify));

    const dialogOptions = OverlayDialogOptions(
      tag: 'dialog',
      strategy: OverlayStrategy.replaceExisting,
      backBehavior: OverlayBackBehavior.dismiss,
      requestFocus: true,
      semanticsLabel: 'Confirmation dialog',
      barrierSemanticsLabel: 'Dismiss confirmation dialog',
    );
    expect(dialogOptions.tag, 'dialog');

    const popupOptions = OverlayPopupOptions(requestFocus: false);
    const loadingOptions = OverlayLoadingOptions(
      requestFocus: true,
      semanticsLabel: 'Loading profile',
      barrierSemanticsLabel: 'Loading in progress',
    );
    expect(popupOptions.requestFocus, isFalse);
    expect(loadingOptions.requestFocus, isTrue);

    final handle = OverlayHandle<void>.detached();
    expect(handle.isVisible, isFalse);
    expect(handle.visible, completes);
    expect(handle.closed, completion(isNull));
    expect(handle.close(), completes);
    handle.refresh();

    expect(OverlayCloseTarget.topMost, isA<OverlayCloseTarget>());
    expect(OverlaySurface.dialog, isA<OverlaySurface>());
    expect(SuperOverlay.close, isA<Function>());
    expect(SuperOverlay.exists, isA<Function>());
    expect(SuperOverlay.of, isA<ScopedSuperOverlay Function(BuildContext)>());
    ScopedOverlayDialogService? scopedDialog;
    ScopedOverlayPopupService? scopedPopup;
    expect(scopedDialog, isNull);
    expect(scopedPopup, isNull);
  });

  test('package entrypoint hides legacy fluent and config surface', () {
    final entrypoint = File('lib/super_overlay.dart').readAsStringSync();
    expect(entrypoint, isNot(contains("export 'src/config/")));
    expect(entrypoint, isNot(contains("export 'src/kit/overlay_controller")));

    final core = File('lib/src/super_overlay_core.dart').readAsStringSync();
    expect(core, isNot(contains('static final OverlayConfig config')));
    expect(core, isNot(contains(RegExp(r'static\s+Future<[^>]+>\s+dismiss'))));
    expect(core, isNot(contains(RegExp(r'static\s+bool\s+checkExist'))));
  });
}

void compileScopedCommands(ScopedSuperOverlay scoped) {
  final OverlayHandle<bool> dialog = scoped.dialog.show<bool>(
    builder: (_) => const SizedBox.shrink(),
  );
  final OverlayHandle<void> popup = scoped.popup.show<void>(
    builder: (_) => const SizedBox.shrink(),
  );
  dialog.refresh();
  popup.refresh();
}
