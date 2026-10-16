import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';
import 'package:super_overlay/src/helper/navigator_scope_registry.dart';
import 'package:super_overlay/src/helper/overlay_manager.dart';

void main() {
  testWidgets(
    'repeated generations release queues, timers, routes and joined closes',
    (tester) async {
      final manager = OverlayManager.instance;
      final registry = NavigatorScopeRegistry.instance;
      final scopes = registry.debugRegisteredScopeCount;
      final snapshots = registry.debugRetainedRootSnapshotCount;
      var completions = 0;
      for (var cycle = 0; cycle < 20; cycle++) {
        final integration = SuperOverlay.integration();
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(cycle),
            builder: integration.builder,
            navigatorObservers: [integration.observer],
            home: const Scaffold(),
          ),
        );
        final dialog = SuperOverlay.dialog.show<void>(
          builder: (_, _) => const Text('resource dialog'),
          options: const OverlayDialogOptions(
            tag: 'reused',
            displayDuration: Duration(minutes: 1),
          ),
        );
        final notice = SuperOverlay.notify.success(
          'resource notice',
          options: const OverlayNotifyOptions(
            tag: 'reused',
            displayDuration: Duration(minutes: 1),
          ),
        );
        dialog.closed.then((_) => completions++);
        notice.closed.then((_) => completions++);
        await tester.pumpAndSettle();
        await Future.wait([dialog.visible, notice.visible]);
        expect(manager.debugResourceCounts['timers'], 2);
        final closes =
            cycle.isEven
                ? [
                  dialog.close(),
                  dialog.close(),
                  notice.close(),
                  notice.close(),
                ]
                : <Future<void>>[];
        await tester.pumpWidget(const SizedBox.shrink());
        integration.dispose();
        await tester.pumpAndSettle();
        await tester.pump();
        await Future.wait([...closes, dialog.closed, notice.closed]);
        dialog.refresh();
        notice.refresh();
        await dialog.close();
        expect(completions, (cycle + 1) * 2);
        expect(manager.debugResourceCounts.values, everyElement(0));
        expect(registry.debugRegisteredScopeCount, scopes);
        expect(registry.debugTrackedRouteCount, 0);
        expect(registry.debugRetainedRootSnapshotCount, snapshots);
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
