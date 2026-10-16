import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';
import 'package:super_overlay/src/helper/overlay_manager.dart';

import 'overlay_test_support.dart';

void main() {
  for (final boundary in ['route replacement', 'popup target removal']) {
    testWidgets('joined close survives $boundary during animation', (
      tester,
    ) async {
      final originalDialog = overlayConfig.custom;
      final originalPopup = overlayConfig.attach;
      overlayConfig.custom = const CustomDialogConfig(
        animationTime: Duration(milliseconds: 500),
        nonAnimationTypes: [NonAnimationType.open, NonAnimationType.routeClose],
      );
      overlayConfig.attach = const AttachDialogConfig(
        animationTime: Duration(milliseconds: 500),
        nonAnimationTypes: [NonAnimationType.open, NonAnimationType.routeClose],
      );
      addTearDown(() {
        overlayConfig.custom = originalDialog;
        overlayConfig.attach = originalPopup;
      });
      final integration = SuperOverlay.integration();
      final navigator = GlobalKey<NavigatorState>();
      final targetMounted = ValueNotifier(true);
      late BuildContext owner;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: integration.builder,
          navigatorObservers: [integration.observer],
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: targetMounted,
              builder:
                  (_, present, __) =>
                      present
                          ? Builder(
                            builder: (context) {
                              owner = context;
                              return const SizedBox(width: 100, height: 40);
                            },
                          )
                          : const SizedBox.shrink(),
            ),
          ),
        ),
      );
      final handle =
          boundary == 'route replacement'
              ? SuperOverlay.of(owner).dialog.show<bool>(
                builder: (_, _) => const Text('closing dialog'),
                options: const OverlayDialogOptions(tag: 'boundary'),
              )
              : SuperOverlay.of(owner).popup.show<bool>(
                targetContext: owner,
                builder:
                    (_, _) => const SizedBox(
                      width: 100,
                      height: 40,
                      child: Text('closing popup'),
                    ),
                options: const OverlayPopupOptions(tag: 'boundary'),
              );
      var settlements = 0;
      handle.closed.then((_) => settlements++);
      await tester.pumpAndSettle();
      await handle.visible;
      final closes = [handle.close(true), handle.close(false)];
      await tester.pump(const Duration(milliseconds: 30));
      expect(OverlayManager.instance.debugResourceCounts['closingDialogs'], 1);
      if (boundary == 'route replacement') {
        navigator.currentState!.pushReplacement<void, void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('replacement route')),
          ),
        );
      } else {
        targetMounted.value = false;
      }
      await tester.pumpAndSettle();
      await Future.wait(closes);
      expect(await handle.closed, isTrue);
      expect(settlements, 1);
      expect(OverlayManager.instance.debugResourceCounts['closingDialogs'], 0);

      final next = SuperOverlay.dialog.show<void>(
        builder: (_, _) => const Text('new same-tag content'),
        options: const OverlayDialogOptions(tag: 'boundary'),
      );
      await tester.pumpAndSettle();
      await next.visible;
      await handle.close();
      handle.refresh();
      expect(next.isVisible, isTrue);
      final close = next.close();
      await tester.pumpAndSettle();
      await close;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      integration.dispose();
      targetMounted.dispose();
      expect(
        OverlayManager.instance.debugResourceCounts.values,
        everyElement(0),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
