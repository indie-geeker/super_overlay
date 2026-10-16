import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

// ignore: avoid_relative_lib_imports
import '../lib/main.dart';

void main() {
  testWidgets(
    'all notification options remain usable at 320 px and double text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 1000);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(const MyApp());
      final selector = find.byKey(
        const ValueKey('feedback-notification-selector'),
      );
      for (final label in ['Success', 'Failure', 'Warning', 'Error', 'Alert']) {
        await tester.ensureVisible(selector);
        await tester.tap(selector);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(label).last);
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Show Notification'));
        await tester.tap(find.text('Show Notification'));
        await tester.pump();
        expect(find.textContaining('$label notification:'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _closeFeedback(tester);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('instant feedback separates policy state from its run action', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Instant Feedback'), findsOneWidget);
    expect(find.text('Replace Latest'), findsOneWidget);
    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('Stack'), findsOneWidget);
    expect(find.text('Run Toast Demo'), findsOneWidget);

    await tester.ensureVisible(find.text('Run Toast Demo'));
    await tester.tap(find.text('Run Toast Demo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Save result 3'), findsOneWidget);
    expect(find.text('Save result 1'), findsNothing);

    await _closeFeedback(tester);
  });

  testWidgets('instant feedback queues upload results in order', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.ensureVisible(find.text('Queue'));
    await tester.tap(find.text('Queue'));
    await tester.tap(find.text('Run Toast Demo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('File 1 uploaded'), findsOneWidget);
    expect(find.text('File 2 uploaded'), findsNothing);

    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump();

    expect(find.text('File 1 uploaded'), findsNothing);
    expect(find.text('File 2 uploaded'), findsOneWidget);

    await _closeFeedback(tester);
  });

  testWidgets('instant feedback stacks parallel task results', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.ensureVisible(find.text('Stack'));
    await tester.tap(find.text('Stack'));
    await tester.tap(find.text('Run Toast Demo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    for (final message in [
      'Background sync complete',
      'Permission check passed',
      'Cache warm-up complete',
    ]) {
      expect(find.text(message), findsOneWidget);
    }
    expect(
      tester.getTopLeft(find.text('Permission check passed')).dy,
      greaterThan(tester.getTopLeft(find.text('Background sync complete')).dy),
    );

    await _closeFeedback(tester);
  });

  testWidgets('instant feedback replaces the selected notification type', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.ensureVisible(find.text('Show Notification'));
    await tester.tap(find.text('Show Notification'));
    await tester.pump();
    expect(
      find.text('Success notification: operation complete'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('feedback-notification-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Error').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Notification'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Success notification: operation complete'), findsNothing);
    expect(find.text('Error notification: operation failed'), findsOneWidget);

    await _closeFeedback(tester);
  });

  testWidgets('instant feedback card omits integration controls', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.textContaining('refreshActive'), findsNothing);
    expect(find.textContaining('handle.refresh()'), findsNothing);
    expect(find.text('Create Refresh Toasts'), findsNothing);
    expect(
      find.byKey(const ValueKey('feedback-notification-selector')),
      findsOneWidget,
    );
  });
}

Future<void> _closeFeedback(WidgetTester tester) async {
  await SuperOverlay.close(target: OverlayCloseTarget.allToasts, force: true);
  await SuperOverlay.close(
    target: OverlayCloseTarget.allNotifications,
    force: true,
  );
  await tester.pumpAndSettle();
}
