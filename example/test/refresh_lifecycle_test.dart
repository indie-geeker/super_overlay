import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

// ignore: avoid_relative_lib_imports
import '../lib/refresh_lifecycle_main.dart';

void main() {
  testWidgets(
    'global progress refreshes, explicit content wins, stop releases timer',
    (tester) async {
      await tester.pumpWidget(const RefreshLifecycleApp());
      await tester.tap(find.text('Start global progress'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('Global progress: 20%'), findsOneWidget);
      await tester.tap(find.text('Use explicit builder'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(
        find.text('Explicit content overrides global style'),
        findsOneWidget,
      );
      expect(find.textContaining('Global progress:'), findsNothing);
      await tester.tap(find.text('Stop notification'));
      await tester.pumpAndSettle();
      expect(SuperOverlay.exists(), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'covered form retains input while business resources continue and dispose cleanly',
    (tester) async {
      await tester.pumpWidget(const RefreshLifecycleApp());
      await tester.tap(find.text('Open retained form'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField), 'Retained value');
      await tester.tap(find.text('Cover page'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Retained value'), findsNothing);
      await tester.tap(find.text('Return to form'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Retained value'), findsOneWidget);
      final status = tester.widget<Text>(find.textContaining('Timer '));
      expect(
        int.parse(RegExp(r'Timer (\d+)').firstMatch(status.data!)!.group(1)!),
        greaterThanOrEqualTo(3),
      );
      await tester.tap(find.text('Close form'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}
