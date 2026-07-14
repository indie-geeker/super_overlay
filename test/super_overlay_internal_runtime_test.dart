import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

import 'overlay_test_support.dart';

Widget _buildOverlayApp(Widget child) {
  return MaterialApp(
    builder: SuperOverlay.init(),
    navigatorObservers: [SuperOverlay.observer],
    home: child,
  );
}

typedef _ShowReplacingOverlay =
    OverlayHandle<void> Function({
      required String label,
      required OverlayStrategy strategy,
    });

Future<void> _expectReplacementWaitsForInFlightClose(
  WidgetTester tester, {
  required String surface,
  required _ShowReplacingOverlay show,
}) async {
  final originalLabel = 'In-flight $surface';
  final replacementLabel = 'Replacement after in-flight $surface';
  final original = show(label: originalLabel, strategy: OverlayStrategy.stack);
  await tester.pumpAndSettle();
  await original.visible;

  var originalClosed = false;
  final originalClosedProbe = original.closed.then<void>((_) {
    originalClosed = true;
  });
  final originalClose = original.close();
  await tester.pump();

  final replacement = show(
    label: replacementLabel,
    strategy: OverlayStrategy.replaceExisting,
  );
  var replacementVisible = false;
  final replacementVisibleProbe = replacement.visible.then<void>((_) {
    replacementVisible = true;
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  expect(originalClosed, isFalse);
  expect(replacementVisible, isFalse);
  expect(find.text(replacementLabel), findsNothing);

  await tester.pumpAndSettle();
  await originalClose;
  await originalClosedProbe;
  await replacementVisibleProbe;

  expect(originalClosed, isTrue);
  expect(find.text(originalLabel), findsNothing);
  expect(find.text(replacementLabel), findsOneWidget);
  expect(replacement.isVisible, isTrue);

  final replacementClose = replacement.close();
  await tester.pumpAndSettle();
  await replacementClose;
}

void main() {
  setUp(() {
    overlayConfig.custom = const CustomDialogConfig();
    overlayConfig.attach = const AttachDialogConfig();
    overlayConfig.notify = const NotifyConfig();
    overlayConfig.toast = const ToastConfig();
  });

  testWidgets(
    'dialog replaceExisting close during old animation prevents stuck content',
    (tester) async {
      overlayConfig.custom = const CustomDialogConfig(
        animationTime: Duration(milliseconds: 200),
        nonAnimationTypes: [NonAnimationType.routeClose],
      );
      await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

      SuperOverlay.dialog.show<void>(
        builder: (_) => const Center(child: Text('Closing gap dialog')),
        options: const OverlayDialogOptions(tag: 'gap-replace-dialog'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Closing gap dialog'), findsOneWidget);

      final replacement = SuperOverlay.dialog.show<void>(
        builder: (_) => const Center(child: Text('Canceled replacement')),
        options: const OverlayDialogOptions(
          tag: 'gap-replace-dialog',
          strategy: OverlayStrategy.replaceExisting,
        ),
      );
      await tester.pump();
      expect(find.text('Canceled replacement'), findsNothing);

      var closed = false;
      final closedProbe = replacement.closed.then((_) => closed = true);
      final close = replacement.close();
      await tester.pumpAndSettle();
      await close;

      expect(closed, isTrue);
      await closedProbe;
      expect(find.text('Closing gap dialog'), findsNothing);
      expect(find.text('Canceled replacement'), findsNothing);
      expect(replacement.isVisible, isFalse);
    },
  );

  testWidgets(
    'dialog replaceExisting waits for close animation before showing replacement',
    (tester) async {
      overlayConfig.custom = const CustomDialogConfig(
        animationTime: Duration(milliseconds: 200),
        nonAnimationTypes: [NonAnimationType.routeClose],
      );
      await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

      SuperOverlay.dialog.show<void>(
        builder: (_) => const Center(child: Text('Closing dialog')),
        options: const OverlayDialogOptions(tag: 'animated-replace-dialog'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Closing dialog'), findsOneWidget);

      final second = SuperOverlay.dialog.show<void>(
        builder: (_) => const Center(child: Text('Replacement dialog')),
        options: const OverlayDialogOptions(
          tag: 'animated-replace-dialog',
          strategy: OverlayStrategy.replaceExisting,
        ),
      );

      await tester.pump();
      expect(find.text('Closing dialog'), findsOneWidget);
      expect(find.text('Replacement dialog'), findsNothing);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Replacement dialog'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('Closing dialog'), findsNothing);
      expect(find.text('Replacement dialog'), findsOneWidget);

      final close = second.close();
      await tester.pumpAndSettle();
      await close;
    },
  );

  testWidgets('dialog replacement awaits an already in-flight close', (
    tester,
  ) async {
    overlayConfig.custom = const CustomDialogConfig(
      animationTime: Duration(milliseconds: 500),
      nonAnimationTypes: [NonAnimationType.routeClose],
    );
    await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

    await _expectReplacementWaitsForInFlightClose(
      tester,
      surface: 'dialog',
      show:
          ({required label, required strategy}) =>
              SuperOverlay.dialog.show<void>(
                builder: (_) => Center(child: Text(label)),
                options: OverlayDialogOptions(
                  tag: 'in-flight-dialog',
                  strategy: strategy,
                ),
              ),
    );
  });

  testWidgets('popup replacement awaits an already in-flight close', (
    tester,
  ) async {
    overlayConfig.attach = const AttachDialogConfig(
      animationTime: Duration(milliseconds: 500),
      nonAnimationTypes: [NonAnimationType.routeClose],
    );
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

    await _expectReplacementWaitsForInFlightClose(
      tester,
      surface: 'popup',
      show:
          ({required label, required strategy}) =>
              SuperOverlay.popup.show<void>(
                targetContext: targetContext,
                builder: (_) => Text(label),
                options: OverlayPopupOptions(
                  tag: 'in-flight-popup',
                  strategy: strategy,
                ),
              ),
    );
  });

  testWidgets('notification replacement awaits an already in-flight close', (
    tester,
  ) async {
    overlayConfig.notify = const NotifyConfig(
      animationTime: Duration(milliseconds: 500),
      nonAnimationTypes: [],
    );
    await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

    await _expectReplacementWaitsForInFlightClose(
      tester,
      surface: 'notification',
      show:
          ({required label, required strategy}) => SuperOverlay.notify.success(
            label,
            options: OverlayNotifyOptions(
              tag: 'in-flight-notification',
              strategy: strategy,
              displayDuration: null,
            ),
          ),
    );
  });

  testWidgets(
    'toast replaceExisting waits for close animation before showing replacement',
    (tester) async {
      overlayConfig.toast = const ToastConfig(
        animationTime: Duration(milliseconds: 200),
        nonAnimationTypes: [],
      );
      await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

      SuperOverlay.toast(
        'Closing toast',
        options: const OverlayToastOptions(
          tag: 'animated-replace-toast',
          displayPolicy: OverlayToastDisplayPolicy.stack,
          displayDuration: Duration(minutes: 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Closing toast'), findsOneWidget);

      final second = SuperOverlay.toast(
        'Replacement toast',
        options: const OverlayToastOptions(
          tag: 'animated-replace-toast',
          strategy: OverlayStrategy.replaceExisting,
          displayPolicy: OverlayToastDisplayPolicy.stack,
          displayDuration: Duration(minutes: 1),
        ),
      );

      await tester.pump();
      expect(find.text('Closing toast'), findsOneWidget);
      expect(find.text('Replacement toast'), findsNothing);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Replacement toast'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('Closing toast'), findsNothing);
      expect(find.text('Replacement toast'), findsOneWidget);

      final close = second.close();
      await tester.pumpAndSettle();
      await close;
    },
  );
}
