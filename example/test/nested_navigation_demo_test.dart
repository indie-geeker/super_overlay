import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

// ignore: avoid_relative_lib_imports
import '../lib/main.dart';

void main() {
  testWidgets(
    'nested scoped dialogs suspend resume and close with owner route',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.ensureVisible(find.text('Open Nested Navigator Demo'));
      await tester.tap(find.text('Open Nested Navigator Demo'));
      await tester.pumpAndSettle();

      expect(find.text('Nested Navigator'), findsWidgets);
      await tester.tap(find.text('Show Nested Home Scoped Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Nested Home Scoped Dialog'), findsOneWidget);

      await tester.tap(find.text('Open Nested Detail'));
      await tester.pumpAndSettle();
      expect(find.text('Nested Detail'), findsWidgets);
      expect(find.text('Nested Home Scoped Dialog'), findsNothing);

      await tester.tap(find.text('Back to Nested Home'));
      await tester.pumpAndSettle();
      expect(find.text('Nested Home Scoped Dialog'), findsOneWidget);

      await SuperOverlay.close(
        target: OverlayCloseTarget.dialog,
        tag: 'nested-home-dialog',
        force: true,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Nested Detail'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show Detail Scoped Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Detail Route Scoped Dialog'), findsOneWidget);

      await tester.tap(find.text('Back to Nested Home'));
      await tester.pumpAndSettle();
      expect(find.text('Detail Route Scoped Dialog'), findsNothing);
      expect(SuperOverlay.exists(tag: 'nested-detail-dialog'), isFalse);
    },
  );
}
