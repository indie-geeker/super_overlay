import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';
import 'overlay_test_support.dart';

void main() {
  testWidgets('toast slide distance uses content size with keyboard layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    overlayConfig.toast = const ToastConfig(
      animationType: AnimationType.centerFadeOtherSlide,
    );
    addTearDown(() => overlayConfig.toast = const ToastConfig());
    final integration = SuperOverlay.integration();
    addTearDown(integration.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: [integration.observer],
        home: const Scaffold(),
      ),
    );
    final handle = SuperOverlay.toast(
      'motion',
      builder:
          (_) => const SizedBox(
            key: ValueKey('toast-body'),
            width: 100,
            height: 40,
          ),
      options: const OverlayToastOptions(displayDuration: Duration(minutes: 1)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final rect = tester.getRect(find.byKey(const ValueKey('toast-body')));
    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    expect(rect.top, closeTo(780, .1));
    expect(rect.bottom, closeTo(820, .1));
  });

  testWidgets('popup keeps its flipped side throughout the size reveal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext target;
    final integration = SuperOverlay.integration();
    addTearDown(integration.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: [integration.observer],
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 100,
                top: 650,
                child: Builder(
                  builder: (context) {
                    target = context;
                    return const SizedBox(width: 100, height: 40);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final handle = SuperOverlay.popup.show<void>(
      targetContext: target,
      builder:
          (_) => const SizedBox(
            key: ValueKey('popup-body'),
            width: 160,
            height: 160,
          ),
    );
    await tester.pump();
    final rects = <Rect>[];
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      rects.add(tester.getRect(find.byKey(const ValueKey('popup-body'))));
    }
    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    for (final rect in rects) {
      expect(
        rect.bottom,
        closeTo(650, .1),
        reason: 'full content must stay above the target in every frame',
      );
    }
  });
}
