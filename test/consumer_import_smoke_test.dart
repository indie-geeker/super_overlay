import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

void main() {
  test('package entrypoint exports command API contracts', () {
    expect(SuperOverlay.init, isA<TransitionBuilder Function()>());
    expect(SuperOverlay.observer, isA<NavigatorObserver>());

    const dialogOptions = OverlayDialogOptions(
      tag: 'dialog',
      strategy: OverlayStrategy.replaceExisting,
      backBehavior: OverlayBackBehavior.dismiss,
    );
    expect(dialogOptions.tag, 'dialog');

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
