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
}
