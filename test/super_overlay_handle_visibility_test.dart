import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

Widget _buildOverlayApp(Widget child) {
  return MaterialApp(
    builder: SuperOverlay.init(),
    navigatorObservers: [SuperOverlay.observer],
    home: Scaffold(body: child),
  );
}

Future<void> _expectVisibleAfterRender(
  WidgetTester tester,
  OverlayHandle<void> handle,
  Finder content,
) async {
  var visibleCompleted = false;
  handle.visible.then((_) => visibleCompleted = true);

  await tester.idle();
  expect(visibleCompleted, isFalse);
  expect(content, findsNothing);

  await tester.pump();
  await tester.idle();
  expect(content, findsOneWidget);
  expect(visibleCompleted, isTrue);

  final close = handle.close();
  await tester.pumpAndSettle();
  await close;
}

void main() {
  testWidgets('dialog visible completes after content renders', (tester) async {
    await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Visible dialog'),
    );

    await _expectVisibleAfterRender(
      tester,
      handle,
      find.text('Visible dialog'),
    );
  });

  testWidgets('loading visible completes after content renders', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.loading.show(message: 'Visible loading');

    await _expectVisibleAfterRender(
      tester,
      handle,
      find.text('Visible loading'),
    );
  });

  testWidgets('popup visible completes after valid target layout', (
    tester,
  ) async {
    late BuildContext targetContext;
    await tester.pumpWidget(
      _buildOverlayApp(
        Builder(
          builder: (context) {
            targetContext = context;
            return const SizedBox(width: 80, height: 40);
          },
        ),
      ),
    );

    final handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Visible popup'),
    );

    await _expectVisibleAfterRender(tester, handle, find.text('Visible popup'));
  });

  testWidgets('notification visible completes after content renders', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.notify.success('Visible notification');

    await _expectVisibleAfterRender(
      tester,
      handle,
      find.text('Visible notification'),
    );
  });

  testWidgets('toast visible completes after content renders', (tester) async {
    await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.toast(
      'Visible toast',
      options: const OverlayToastOptions(displayDuration: Duration(minutes: 1)),
    );

    await _expectVisibleAfterRender(tester, handle, find.text('Visible toast'));
  });

  testWidgets('keepExisting shares the original visibility future', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

    final first = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Shared visible dialog'),
      options: const OverlayDialogOptions(tag: 'shared-visible'),
    );
    final second = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Ignored duplicate dialog'),
      options: const OverlayDialogOptions(
        tag: 'shared-visible',
        strategy: OverlayStrategy.keepExisting,
      ),
    );
    var secondVisible = false;
    second.visible.then((_) => secondVisible = true);

    await tester.idle();
    expect(secondVisible, isFalse);

    await tester.pump();
    await first.visible;
    await second.visible;
    expect(secondVisible, isTrue);
    expect(find.text('Shared visible dialog'), findsOneWidget);
    expect(find.text('Ignored duplicate dialog'), findsNothing);

    final close = first.close();
    await tester.pumpAndSettle();
    await close;
  });
}
