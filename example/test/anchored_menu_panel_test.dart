import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

// ignore: avoid_relative_lib_imports
import '../lib/main.dart';

void main() {
  testWidgets('sort menu opens below its own trigger and applies selection', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    final trigger = find.byKey(const ValueKey('sort-menu-trigger'));

    await tester.ensureVisible(trigger);
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    final popup = find.byKey(const ValueKey('sort-menu-popup'));
    expect(popup, findsOneWidget);
    expect(
      tester.getTopLeft(popup).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(trigger).dy),
    );

    await tester.tap(find.text('Top Rated'));
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    expect(find.text('Current sort: Top Rated'), findsOneWidget);

    await _closePopups(tester);
  });

  testWidgets('attachment menu opens above its trigger and applies action', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    final input = find.byKey(const ValueKey('attachment-message-field'));
    final trigger = find.byKey(const ValueKey('attachment-menu-trigger'));

    await tester.ensureVisible(input);
    await tester.tap(input);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.ensureVisible(trigger);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 280));
    await tester.pumpAndSettle();
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    final popup = find.byKey(const ValueKey('attachment-menu-popup'));
    expect(popup, findsOneWidget);
    expect(
      tester.getBottomLeft(popup).dy,
      lessThanOrEqualTo(tester.getTopLeft(trigger).dy),
    );
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('Photo Library'));
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    expect(find.text('Last action: Photo Library'), findsOneWidget);

    await _closePopups(tester);
  });
}

Future<void> _closePopups(WidgetTester tester) async {
  await SuperOverlay.close(target: OverlayCloseTarget.allPopups, force: true);
  await tester.pumpAndSettle();
}
