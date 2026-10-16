import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

// ignore: avoid_relative_lib_imports
import '../lib/minimal_main.dart';

void main() {
  testWidgets('minimal example cancellation does not start the task', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(MinimalOverlayApp(runTask: () async => calls++));
    await tester.tap(find.text('Confirm and run'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelled'), findsOneWidget);
    expect(calls, 0);
    expect(SuperOverlay.exists(), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  for (final fails in [false, true]) {
    testWidgets('minimal example closes loading after task, fails=$fails', (
      tester,
    ) async {
      final task = Completer<void>();
      await tester.pumpWidget(MinimalOverlayApp(runTask: () => task.future));
      await tester.tap(find.text('Confirm and run'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(SuperOverlay.exists(), isTrue);
      if (fails) {
        task.completeError(StateError('demo failure'));
      } else {
        task.complete();
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text(fails ? 'Task failed' : 'Completed'), findsOneWidget);
      expect(SuperOverlay.exists(), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
