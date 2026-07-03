import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

Widget buildPopupDismissApp(Widget child) {
  return MaterialApp(
    builder: SuperOverlayInit.init(),
    navigatorObservers: [SuperOverlayInit.observer],
    home: Scaffold(body: child),
  );
}

void main() {
  registerPopupDismissTests();
}

void registerPopupDismissTests() {
  testWidgets('popup target rect transform controls attachment geometry', (
    tester,
  ) async {
    const targetKey = Key('popup-target-box');

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
                    SuperOverlay.showPopup(
                          targetContext: targetContext,
                          builder:
                              (_) => const SizedBox(
                                width: 120,
                                height: 40,
                                child: Text('Shifted Popup'),
                              ),
                        )
                        .withTargetRect(
                          (targetRect) => targetRect.shift(const Offset(0, 24)),
                        )
                        .withTag('shifted-popup')
                        .fire<void>();
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

    await SuperOverlay.dismiss(
      status: DismissStatus.attach,
      tag: 'shifted-popup',
    );
    await tester.pumpAndSettle();
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

    SuperOverlay.showPopup(
      targetContext: targetContext,
      builder: (_) => const Text('Locked Popup'),
    ).withMask(dismissible: false).withTag('locked').fire<void>();
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(790, 590));
    await tester.pumpAndSettle();
    expect(find.text('Locked Popup'), findsOneWidget);

    await SuperOverlay.dismiss(status: DismissStatus.attach, tag: 'locked');
    await tester.pumpAndSettle();

    SuperOverlay.showPopup(
      targetContext: targetContext,
      builder: (_) => const Text('Dismissible Popup'),
    ).withMask(dismissible: true).fire<void>();
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(790, 590));
    await tester.pumpAndSettle();
    expect(find.text('Dismissible Popup'), findsNothing);
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

    SuperOverlay.showPopup(
          targetContext: targetContext,
          builder: (_) => const Text('Ignore Area Popup'),
        )
        .withMask(dismissible: true)
        .withMaskIgnoreArea(const Rect.fromLTRB(0, 0, 0, 100))
        .withTag('ignore-area-popup')
        .fire<void>();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bottom Action'));
    await tester.pumpAndSettle();

    expect(bottomTaps, 1);
    expect(find.text('Ignore Area Popup'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Ignore Area Popup'), findsNothing);
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

      SuperOverlay.showPopup(
        targetContext: targetContext,
        builder: (_) => const Text('Attach One'),
      ).withTag('attach-one').fire<void>();
      await tester.pumpAndSettle();

      await SuperOverlay.dismiss(
        status: DismissStatus.attach,
        tag: 'attach-one',
      );
      await tester.pumpAndSettle();
      expect(find.text('Attach One'), findsNothing);

      SuperOverlay.showPopup(
        targetContext: targetContext,
        builder: (_) => const Text('Attach Two'),
      ).fire<void>();
      SuperOverlay.show(builder: (_) => const Text('Custom Two')).fire<void>();
      await tester.pumpAndSettle();

      await SuperOverlay.dismiss(status: DismissStatus.allDialog);
      await tester.pumpAndSettle();

      expect(find.text('Attach Two'), findsNothing);
      expect(find.text('Custom Two'), findsNothing);
    },
  );
}
