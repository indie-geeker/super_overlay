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
  });
}
