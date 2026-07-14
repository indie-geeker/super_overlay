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

typedef _ShowTaggedOverlay =
    OverlayHandle<void> Function({
      required String label,
      required OverlayStrategy strategy,
    });

Future<void> _expectEveryStackedMatchReplaced(
  WidgetTester tester, {
  required String surface,
  required _ShowTaggedOverlay show,
}) async {
  final firstLabel = 'First stacked $surface';
  final secondLabel = 'Second stacked $surface';
  final replacementLabel = 'Replacement $surface';
  final first = show(label: firstLabel, strategy: OverlayStrategy.stack);
  final second = show(label: secondLabel, strategy: OverlayStrategy.stack);

  await tester.pumpAndSettle();

  expect(find.text(firstLabel), findsOneWidget);
  expect(find.text(secondLabel), findsOneWidget);
  expect(first.isVisible, isTrue);
  expect(second.isVisible, isTrue);

  final replacement = show(
    label: replacementLabel,
    strategy: OverlayStrategy.replaceExisting,
  );

  await tester.pumpAndSettle();

  expect(find.text(firstLabel), findsNothing);
  expect(find.text(secondLabel), findsNothing);
  expect(find.text(replacementLabel), findsOneWidget);
  expect(first.isVisible, isFalse);
  expect(second.isVisible, isFalse);
  expect(replacement.isVisible, isTrue);
  await first.closed;
  await second.closed;

  await replacement.close();
}

void main() {
  testWidgets('same-turn dialog replacement leaves only the latest overlay', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

    final first = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('First racing dialog'),
      options: const OverlayDialogOptions(
        tag: 'racing-dialog',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );
    final second = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Second racing dialog'),
      options: const OverlayDialogOptions(
        tag: 'racing-dialog',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('First racing dialog'), findsNothing);
    expect(find.text('Second racing dialog'), findsOneWidget);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);

    await second.close();
  });

  testWidgets('same-turn popup replacement leaves only the latest overlay', (
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

    final first = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('First racing popup'),
      options: const OverlayPopupOptions(
        tag: 'racing-popup',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );
    final second = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Second racing popup'),
      options: const OverlayPopupOptions(
        tag: 'racing-popup',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('First racing popup'), findsNothing);
    expect(find.text('Second racing popup'), findsOneWidget);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);

    await second.close();
  });

  testWidgets(
    'same-turn notification replacement leaves only the latest overlay',
    (tester) async {
      await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

      final first = SuperOverlay.notify.success(
        'First racing notification',
        options: const OverlayNotifyOptions(
          tag: 'racing-notification',
          strategy: OverlayStrategy.replaceExisting,
          displayDuration: null,
        ),
      );
      final second = SuperOverlay.notify.success(
        'Second racing notification',
        options: const OverlayNotifyOptions(
          tag: 'racing-notification',
          strategy: OverlayStrategy.replaceExisting,
          displayDuration: null,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('First racing notification'), findsNothing);
      expect(find.text('Second racing notification'), findsOneWidget);
      expect(first.isVisible, isFalse);
      expect(second.isVisible, isTrue);

      await second.close();
    },
  );

  testWidgets('same-turn toast replacement leaves only the latest overlay', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

    final first = SuperOverlay.toast(
      'First racing toast',
      options: const OverlayToastOptions(
        tag: 'racing-toast',
        strategy: OverlayStrategy.replaceExisting,
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    );
    final second = SuperOverlay.toast(
      'Second racing toast',
      options: const OverlayToastOptions(
        tag: 'racing-toast',
        strategy: OverlayStrategy.replaceExisting,
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('First racing toast'), findsNothing);
    expect(find.text('Second racing toast'), findsOneWidget);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);

    await second.close();
  });

  testWidgets('dialog replacement closes every stacked same-tag overlay', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

    await _expectEveryStackedMatchReplaced(
      tester,
      surface: 'dialog',
      show:
          ({required label, required strategy}) =>
              SuperOverlay.dialog.show<void>(
                builder: (_) => Text(label),
                options: OverlayDialogOptions(
                  tag: 'stacked-dialog',
                  strategy: strategy,
                ),
              ),
    );
  });

  testWidgets('popup replacement closes every stacked same-tag overlay', (
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

    await _expectEveryStackedMatchReplaced(
      tester,
      surface: 'popup',
      show:
          ({required label, required strategy}) =>
              SuperOverlay.popup.show<void>(
                targetContext: targetContext,
                builder: (_) => Text(label),
                options: OverlayPopupOptions(
                  tag: 'stacked-popup',
                  strategy: strategy,
                ),
              ),
    );
  });

  testWidgets(
    'notification replacement closes every stacked same-tag overlay',
    (tester) async {
      await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

      await _expectEveryStackedMatchReplaced(
        tester,
        surface: 'notification',
        show:
            ({required label, required strategy}) =>
                SuperOverlay.notify.success(
                  label,
                  options: OverlayNotifyOptions(
                    tag: 'stacked-notification',
                    strategy: strategy,
                    displayDuration: null,
                  ),
                ),
      );
    },
  );

  testWidgets('toast replacement closes every stacked same-tag overlay', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

    await _expectEveryStackedMatchReplaced(
      tester,
      surface: 'toast',
      show:
          ({required label, required strategy}) => SuperOverlay.toast(
            label,
            options: OverlayToastOptions(
              tag: 'stacked-toast',
              strategy: strategy,
              displayPolicy: OverlayToastDisplayPolicy.stack,
              displayDuration: const Duration(minutes: 1),
            ),
          ),
    );
  });

  testWidgets('canceling a queued replacement preserves the current winner', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

    final original = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Original queued dialog'),
      options: const OverlayDialogOptions(
        tag: 'queued-dialog',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );
    await tester.pumpAndSettle();
    await original.visible;

    final winner = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Current queued winner'),
      options: const OverlayDialogOptions(
        tag: 'queued-dialog',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );
    final canceled = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Canceled queued successor'),
      options: const OverlayDialogOptions(
        tag: 'queued-dialog',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );
    final canceledClose = canceled.close();

    await tester.pumpAndSettle();
    await canceledClose;

    expect(find.text('Current queued winner'), findsOneWidget);
    expect(find.text('Canceled queued successor'), findsNothing);
    expect(winner.isVisible, isTrue);
    expect(canceled.isVisible, isFalse);

    await winner.close();
  });
}
