import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

import 'overlay_test_support.dart';

class _Harness {
  final integration = SuperOverlay.integration();
  final navigator = GlobalKey<NavigatorState>();

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: integration.builder,
        navigatorObservers: [integration.observer],
        home: const Scaffold(body: Text('first page')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('second page')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  }
}

void main() {
  for (final popup in [false, true]) {
    for (final lowerBehavior in [
      OverlayBackBehavior.dismiss,
      OverlayBackBehavior.block,
    ]) {
      testWidgets(
        'passThrough ${popup ? 'popup' : 'dialog'} reaches lower ${lowerBehavior.name}',
        (tester) async {
          final harness = _Harness();
          await harness.mount(tester);
          final lower = SuperOverlay.dialog.show<void>(
            builder: (_, _) => const Text('lower dialog'),
            options: OverlayDialogOptions(backBehavior: lowerBehavior),
          );
          final upper =
              popup
                  ? SuperOverlay.popup.show<void>(
                    targetContext: tester.element(find.text('second page')),
                    builder: (_, _) => const Text('upper popup'),
                    options: const OverlayPopupOptions(
                      backBehavior: OverlayBackBehavior.passThrough,
                    ),
                  )
                  : SuperOverlay.dialog.show<void>(
                    builder: (_, _) => const Text('upper dialog'),
                    options: const OverlayDialogOptions(
                      backBehavior: OverlayBackBehavior.passThrough,
                    ),
                  );
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(upper.isVisible, isTrue);
          expect(lower.isVisible, lowerBehavior == OverlayBackBehavior.block);
          expect(find.text('second page'), findsOneWidget);
          if (lowerBehavior == OverlayBackBehavior.dismiss) {
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(find.text('first page'), findsOneWidget);
            expect(upper.isVisible, isFalse);
          }
          await harness.dispose(tester);
        },
      );
    }
  }

  for (final surface in ['dialog', 'popup', 'notification']) {
    for (final all in [false, true]) {
      testWidgets('bulk ${all ? 'all' : surface} joins an existing close', (
        tester,
      ) async {
        final originalDialog = overlayConfig.custom;
        final originalPopup = overlayConfig.attach;
        final originalNotify = overlayConfig.notify;
        overlayConfig.custom = const CustomDialogConfig(
          animationTime: Duration(milliseconds: 500),
          nonAnimationTypes: [],
        );
        overlayConfig.attach = const AttachDialogConfig(
          animationTime: Duration(milliseconds: 500),
          nonAnimationTypes: [],
        );
        overlayConfig.notify = const NotifyConfig(
          animationTime: Duration(milliseconds: 500),
          nonAnimationTypes: [],
        );
        addTearDown(() {
          overlayConfig.custom = originalDialog;
          overlayConfig.attach = originalPopup;
          overlayConfig.notify = originalNotify;
        });
        final harness = _Harness();
        await harness.mount(tester);
        final handle = switch (surface) {
          'dialog' => SuperOverlay.dialog.show<void>(
            builder: (_, _) => const Text('closing surface'),
            options: const OverlayDialogOptions(tag: 'matching'),
          ),
          'popup' => SuperOverlay.popup.show<void>(
            targetContext: tester.element(find.text('second page')),
            builder: (_, _) => const Text('closing surface'),
            options: const OverlayPopupOptions(tag: 'matching'),
          ),
          _ => SuperOverlay.notify.alert(
            'closing surface',
            options: const OverlayNotifyOptions(
              tag: 'matching',
              displayDuration: null,
            ),
          ),
        };
        await tester.pumpAndSettle();
        final individual = handle.close();
        await tester.pump(const Duration(milliseconds: 20));
        var bulkDone = false;
        final bulk = SuperOverlay.close(
          target:
              all
                  ? OverlayCloseTarget.all
                  : switch (surface) {
                    'dialog' => OverlayCloseTarget.allDialogs,
                    'popup' => OverlayCloseTarget.allPopups,
                    _ => OverlayCloseTarget.allNotifications,
                  },
          tag: 'matching',
        ).then((_) => bulkDone = true);
        await tester.idle();
        expect(bulkDone, isFalse);
        await tester.pump(const Duration(milliseconds: 200));
        expect(bulkDone, isFalse);
        await tester.pumpAndSettle();
        await Future.wait([individual, bulk]);
        expect(bulkDone, isTrue);
        await handle.closed;
        await harness.dispose(tester);
      });
    }
  }

  testWidgets('tagged bulk close leaves a different closing tag independent', (
    tester,
  ) async {
    final original = overlayConfig.custom;
    overlayConfig.custom = const CustomDialogConfig(
      animationTime: Duration(milliseconds: 500),
      nonAnimationTypes: [],
    );
    addTearDown(() => overlayConfig.custom = original);
    final harness = _Harness();
    await harness.mount(tester);
    final handle = SuperOverlay.dialog.show<void>(
      builder: (_, _) => const Text('unrelated close'),
      options: const OverlayDialogOptions(tag: 'other'),
    );
    await tester.pumpAndSettle();
    var individualDone = false;
    final individual = handle.close().then((_) => individualDone = true);
    await SuperOverlay.close(
      target: OverlayCloseTarget.allDialogs,
      tag: 'matching',
    );
    expect(individualDone, isFalse);
    await tester.pumpAndSettle();
    await individual;
    await harness.dispose(tester);
  });
}
