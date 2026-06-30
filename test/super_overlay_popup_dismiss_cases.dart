part of 'super_overlay_test.dart';

void registerPopupDismissTests() {
  testWidgets('popup target rect transform controls attachment geometry', (
    tester,
  ) async {
    const targetKey = Key('popup-target-box');

    await tester.pumpWidget(
      buildApp(
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
                          builder: (_) => const SizedBox(
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
      buildApp(
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

  testWidgets(
    'attach dialogs participate in attach and dialog dismiss statuses',
    (tester) async {
      late BuildContext targetContext;
      await tester.pumpWidget(
        buildApp(
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
