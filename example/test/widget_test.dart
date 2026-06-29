import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

// ignore: avoid_relative_lib_imports
import '../lib/main.dart';

void main() {
  testWidgets('example demonstrates the SuperOverlay feature set', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('SuperOverlay Demo'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('Toast'), findsOneWidget);
    expect(find.text('Popup'), findsOneWidget);
    expect(find.text('Highlight'), findsOneWidget);
    expect(find.text('Notify'), findsOneWidget);
    expect(find.text('Route Binding'), findsOneWidget);
    expect(find.text('Back Handling'), findsOneWidget);

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.text('Custom overlay'), findsOneWidget);

    await tester.tap(find.text('Close custom'));
    await tester.pumpAndSettle();
    expect(find.text('Custom overlay'), findsNothing);

    await tester.tap(find.text('Toast'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Saved from toast'), findsOneWidget);

    await SuperOverlay.dismiss(status: DismissStatus.allToast);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notify'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Notify message'), findsOneWidget);

    await SuperOverlay.dismiss(status: DismissStatus.allNotify);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Popup'));
    await tester.pumpAndSettle();
    expect(find.text('Popup menu'), findsOneWidget);

    await tester.tapAt(const Offset(790, 590));
    await tester.pumpAndSettle();
    expect(find.text('Popup menu'), findsNothing);

    await tester.tap(find.text('Route Binding'));
    await tester.pumpAndSettle();
    expect(find.text('Route binding page'), findsOneWidget);

    await tester.tap(find.text('Show bound overlay'));
    await tester.pumpAndSettle();
    expect(find.text('Bound to this page'), findsOneWidget);
  });
}
