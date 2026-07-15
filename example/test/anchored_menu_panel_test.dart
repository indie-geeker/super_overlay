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

    await tester.tap(find.text('评分最高'));
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    expect(find.text('当前排序：评分最高'), findsOneWidget);

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

    await tester.tap(find.text('从相册选择'));
    await tester.pumpAndSettle();
    expect(popup, findsNothing);
    expect(find.text('最近操作：从相册选择'), findsOneWidget);

    await _closePopups(tester);
  });

  testWidgets('moving anchor keeps one popup open and tracks its position', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    final trigger = find.byKey(const ValueKey('moving-anchor-trigger'));

    await tester.ensureVisible(trigger);
    await tester.tap(trigger);
    await tester.pumpAndSettle();

    final popup = find.byKey(const ValueKey('moving-anchor-popup'));
    expect(popup, findsOneWidget);
    final popupElement = tester.element(popup);
    final initialAnchorPosition = tester.getTopLeft(trigger);
    final initialPopupPosition = tester.getTopLeft(popup);

    await tester.tap(find.byKey(const ValueKey('moving-anchor-shift-control')));
    await tester.pumpAndSettle();

    final movedAnchorPosition = tester.getTopLeft(trigger);
    final movedPopupPosition = tester.getTopLeft(popup);
    expect(movedAnchorPosition.dx, isNot(initialAnchorPosition.dx));
    expect(movedPopupPosition.dx, isNot(initialPopupPosition.dx));
    expect(popup, findsOneWidget);
    expect(tester.element(popup), same(popupElement));

    await _closePopups(tester);
  });
}

Future<void> _closePopups(WidgetTester tester) async {
  await SuperOverlay.close(target: OverlayCloseTarget.allPopups, force: true);
  await tester.pumpAndSettle();
}
