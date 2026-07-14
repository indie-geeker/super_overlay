import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/main.dart';

Future<void> _pumpAtWidth(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();
}

Future<void> _revealEveryHomePanel(WidgetTester tester) async {
  for (final key in [
    'instant-feedback-panel',
    'anchored-menu-panel',
    'dialog-demo-panel',
    'network-state-panel',
    'guided-mask-panel',
    'lifecycle-panel',
    'control-lab-panel',
    'nested-navigation-panel',
  ]) {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'overflow in $key');
  }
}

void main() {
  for (final width in [320.0, 600.0, 1200.0]) {
    testWidgets('home has no layout overflow at ${width.toInt()} px', (
      tester,
    ) async {
      await _pumpAtWidth(tester, width);
      await _revealEveryHomePanel(tester);
    });
  }

  testWidgets('common scenarios stack in one column at 320 px', (tester) async {
    await _pumpAtWidth(tester, 320);

    final first = tester.getTopLeft(
      find.byKey(const ValueKey('instant-feedback-panel')),
    );
    final second = tester.getTopLeft(
      find.byKey(const ValueKey('anchored-menu-panel')),
    );

    expect(second.dx, closeTo(first.dx, 0.5));
    expect(second.dy, greaterThan(first.dy));
  });

  testWidgets('common scenarios share a row at 1200 px', (tester) async {
    await _pumpAtWidth(tester, 1200);

    final first = tester.getTopLeft(
      find.byKey(const ValueKey('instant-feedback-panel')),
    );
    final second = tester.getTopLeft(
      find.byKey(const ValueKey('anchored-menu-panel')),
    );

    expect(second.dx, greaterThan(first.dx));
    expect(second.dy, closeTo(first.dy, 0.5));
  });
}
