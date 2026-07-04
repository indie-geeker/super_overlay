import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

Widget buildPopupDismissApp(Widget child) {
  return MaterialApp(
    builder: SuperOverlay.init(),
    navigatorObservers: [SuperOverlay.observer],
    home: Scaffold(body: child),
  );
}

Future<void> _closePopupHandle(
  WidgetTester tester,
  OverlayHandle<void> handle,
) async {
  expect(handle.isVisible, isTrue);
  final close = handle.close();
  await tester.pumpAndSettle();
  await close;
  await handle.closed;
  expect(handle.isVisible, isFalse);
}

void main() {
  registerPopupDismissTests();
}

void registerPopupDismissTests() {
  testWidgets('popup target rect transform controls attachment geometry', (
    tester,
  ) async {
    const targetKey = Key('popup-target-box');
    late OverlayHandle<void> handle;

    await tester.pumpWidget(
      buildPopupDismissApp(
        Align(
          alignment: Alignment.topLeft,
          child: Builder(
            builder: (targetContext) {
              return SizedBox(
                key: targetKey,
                width: 120,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    handle = SuperOverlay.popup.show<void>(
                      targetContext: targetContext,
                      builder:
                          (_) => const SizedBox(
                            width: 120,
                            height: 40,
                            child: Text('Shifted Popup'),
                          ),
                      options: OverlayPopupOptions(
                        tag: 'shifted-popup',
                        targetRectBuilder:
                            (targetRect) =>
                                targetRect.shift(const Offset(0, 24)),
                      ),
                    );
                  },
                  child: const Text('Shift Target'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Shift Target'));
    await tester.pumpAndSettle();

    final targetBottom = tester.getRect(find.byKey(targetKey)).bottom;
    final popupTop = tester.getTopLeft(find.text('Shifted Popup')).dy;
    expect(popupTop, greaterThanOrEqualTo(targetBottom + 24));

    await _closePopupHandle(tester, handle);
  });

  testWidgets('popup mask click dismisses only when enabled', (tester) async {
    late BuildContext targetContext;
    await tester.pumpWidget(
      buildPopupDismissApp(
        Builder(
          builder: (context) {
            targetContext = context;
            return const Text('mask target');
          },
        ),
      ),
    );

    final lockedHandle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Locked Popup'),
      options: const OverlayPopupOptions(
        tag: 'locked',
        dismissOnMaskTap: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(790, 590));
    await tester.pumpAndSettle();
    expect(find.text('Locked Popup'), findsOneWidget);
    expect(lockedHandle.isVisible, isTrue);

    await _closePopupHandle(tester, lockedHandle);

    final dismissibleHandle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Dismissible Popup'),
      options: const OverlayPopupOptions(dismissOnMaskTap: true),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(790, 590));
    await tester.pumpAndSettle();
    await dismissibleHandle.closed;
    expect(find.text('Dismissible Popup'), findsNothing);
    expect(dismissibleHandle.isVisible, isFalse);
  });

  testWidgets('popup mask ignore area lets uncovered taps pass through', (
    tester,
  ) async {
    var bottomTaps = 0;
    late BuildContext targetContext;

    await tester.pumpWidget(
      buildPopupDismissApp(
        Stack(
          children: [
            Positioned(
              left: 80,
              top: 80,
              child: Builder(
                builder: (context) {
                  targetContext = context;
                  return const SizedBox(
                    width: 80,
                    height: 40,
                    child: Text('Ignore Target'),
                  );
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 80,
              child: TextButton(
                onPressed: () => bottomTaps++,
                child: const Text('Bottom Action'),
              ),
            ),
          ],
        ),
      ),
    );

    final handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Ignore Area Popup'),
      options: const OverlayPopupOptions(
        tag: 'ignore-area-popup',
        dismissOnMaskTap: true,
        maskIgnoreArea: Rect.fromLTRB(0, 0, 0, 100),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bottom Action'));
    await tester.pumpAndSettle();

    expect(bottomTaps, 1);
    expect(find.text('Ignore Area Popup'), findsOneWidget);
    expect(handle.isVisible, isTrue);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await handle.closed;

    expect(find.text('Ignore Area Popup'), findsNothing);
    expect(handle.isVisible, isFalse);
  });

  testWidgets(
    'attach dialogs participate in attach and dialog dismiss statuses',
    (tester) async {
      late BuildContext targetContext;
      await tester.pumpWidget(
        buildPopupDismissApp(
          Builder(
            builder: (context) {
              targetContext = context;
              return const Text('dismiss target');
            },
          ),
        ),
      );

      final attachOne = SuperOverlay.popup.show<void>(
        targetContext: targetContext,
        builder: (_) => const Text('Attach One'),
        options: const OverlayPopupOptions(tag: 'attach-one'),
      );
      await tester.pumpAndSettle();
      expect(attachOne.isVisible, isTrue);

      await SuperOverlay.dismiss(
        status: DismissStatus.attach,
        tag: 'attach-one',
      );
      await tester.pumpAndSettle();
      await attachOne.closed;
      expect(find.text('Attach One'), findsNothing);
      expect(attachOne.isVisible, isFalse);

      final attachTwo = SuperOverlay.popup.show<void>(
        targetContext: targetContext,
        builder: (_) => const Text('Attach Two'),
      );
      final customTwo = SuperOverlay.dialog.show<void>(
        builder: (_) => const Text('Custom Two'),
      );
      await tester.pumpAndSettle();
      expect(attachTwo.isVisible, isTrue);
      expect(customTwo.isVisible, isTrue);

      await SuperOverlay.dismiss(status: DismissStatus.allDialog);
      await tester.pumpAndSettle();
      await attachTwo.closed;
      await customTwo.closed;

      expect(find.text('Attach Two'), findsNothing);
      expect(find.text('Custom Two'), findsNothing);
      expect(attachTwo.isVisible, isFalse);
      expect(customTwo.isVisible, isFalse);
    },
  );
}
