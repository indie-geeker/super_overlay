part of 'super_overlay_test.dart';

void registerPopupGeometryTests() {
  testWidgets('popup appears relative to target widget', (tester) async {
    await tester.pumpWidget(
      buildApp(
        Align(
          alignment: Alignment.topLeft,
          child: Builder(
            builder: (targetContext) {
              return SizedBox(
                width: 80,
                height: 40,
                child: ElevatedButton(
                  onPressed: () {
                    SuperOverlay.showPopup(
                      targetContext: targetContext,
                      builder: (_) => const SizedBox(
                        width: 120,
                        height: 40,
                        child: Text('Popup Content'),
                      ),
                    ).withTag('popup').fire<void>();
                  },
                  child: const Text('Target'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Target'));
    await tester.pumpAndSettle();

    expect(find.text('Popup Content'), findsOneWidget);
    final targetBottom = tester.getBottomLeft(find.text('Target')).dy;
    final popupTop = tester.getTopLeft(find.text('Popup Content')).dy;
    expect(popupTop, greaterThanOrEqualTo(targetBottom));

    await SuperOverlay.dismiss(status: DismissStatus.attach, tag: 'popup');
    await tester.pumpAndSettle();
  });

  testWidgets('popup side alignment places content outside target', (
    tester,
  ) async {
    late BuildContext targetContext;
    const targetKey = Key('side-alignment-target');
    const rightPopupKey = Key('right-aligned-popup');
    const leftPopupKey = Key('left-aligned-popup');

    await tester.pumpWidget(
      buildApp(
        Stack(
          children: [
            Positioned(
              left: 220,
              top: 180,
              child: Builder(
                builder: (context) {
                  targetContext = context;
                  return const SizedBox(
                    key: targetKey,
                    width: 80,
                    height: 40,
                    child: Text('Side Target'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    SuperOverlay.showPopup(
      targetContext: targetContext,
      builder: (_) => const SizedBox(
        key: rightPopupKey,
        width: 60,
        height: 30,
        child: Text('Right Popup'),
      ),
    ).withAlignment(Alignment.centerRight).withTag('right-popup').fire<void>();
    await tester.pumpAndSettle();

    final targetRect = tester.getRect(find.byKey(targetKey));
    final rightPopupRect = tester.getRect(find.byKey(rightPopupKey));
    expect(rightPopupRect.left, targetRect.right);
    expect(rightPopupRect.center.dy, targetRect.center.dy);

    await SuperOverlay.dismiss(
      status: DismissStatus.attach,
      tag: 'right-popup',
    );
    await tester.pumpAndSettle();

    SuperOverlay.showPopup(
      targetContext: targetContext,
      builder: (_) => const SizedBox(
        key: leftPopupKey,
        width: 60,
        height: 30,
        child: Text('Left Popup'),
      ),
    ).withAlignment(Alignment.centerLeft).withTag('left-popup').fire<void>();
    await tester.pumpAndSettle();

    final leftPopupRect = tester.getRect(find.byKey(leftPopupKey));
    expect(leftPopupRect.right, targetRect.left);
    expect(leftPopupRect.center.dy, targetRect.center.dy);

    await SuperOverlay.dismiss(status: DismissStatus.attach, tag: 'left-popup');
    await tester.pumpAndSettle();
  });

  testWidgets('popup clamps inside screen bounds', (tester) async {
    await tester.pumpWidget(
      buildApp(
        Align(
          alignment: Alignment.bottomRight,
          child: Builder(
            builder: (targetContext) {
              return SizedBox(
                width: 48,
                height: 32,
                child: ElevatedButton(
                  onPressed: () {
                    SuperOverlay.showPopup(
                      targetContext: targetContext,
                      builder: (_) => const SizedBox(
                        width: 320,
                        height: 160,
                        child: Text('Clamped Popup'),
                      ),
                    ).fire<void>();
                  },
                  child: const Text('Edge'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edge'), warnIfMissed: false);
    await tester.pumpAndSettle();

    final popupRect = tester.getRect(find.byType(SizedBox).last);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(popupRect.left, greaterThanOrEqualTo(0));
    expect(popupRect.top, greaterThanOrEqualTo(0));
    expect(popupRect.right, lessThanOrEqualTo(screen.width));
    expect(popupRect.bottom, lessThanOrEqualTo(screen.height));

    await SuperOverlay.dismiss(status: DismissStatus.allAttach);
    await tester.pumpAndSettle();
  });

  testWidgets('popup highlight creates a transparent target area', (
    tester,
  ) async {
    var targetClicks = 0;

    await tester.pumpWidget(
      buildApp(
        Center(
          child: Builder(
            builder: (targetContext) {
              return ElevatedButton(
                onPressed: () {
                  targetClicks++;
                  if (targetClicks == 1) {
                    SuperOverlay.showPopup(
                      targetContext: targetContext,
                      builder: (_) => const Text('Highlighted Popup'),
                    ).withHighlight().fire<void>();
                  }
                },
                child: const Text('Highlight Target'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Highlight Target'));
    await tester.pumpAndSettle();
    expect(find.text('Highlighted Popup'), findsOneWidget);

    await tester.tap(find.text('Highlight Target'));
    await tester.pumpAndSettle();
    expect(targetClicks, 2);

    await SuperOverlay.dismiss(status: DismissStatus.allAttach);
    await tester.pumpAndSettle();
  });

  testWidgets('popup highlight applies mask color, padding, and radius', (
    tester,
  ) async {
    late BuildContext targetContext;

    await tester.pumpWidget(
      buildApp(
        Center(
          child: Builder(
            builder: (context) {
              targetContext = context;
              return const SizedBox(
                width: 120,
                height: 48,
                child: Text('Highlight Settings Target'),
              );
            },
          ),
        ),
      ),
    );

    final radius = BorderRadius.circular(18);
    SuperOverlay.showPopup(
          targetContext: targetContext,
          builder: (_) => const Text('Configured Highlight Popup'),
        )
        .withHighlight(
          maskColor: const Color(0xAA101820),
          padding: const EdgeInsets.all(12),
          borderRadius: radius,
        )
        .withMask(dismissible: false)
        .fire<void>();
    await tester.pumpAndSettle();

    final mask = tester.widget<HighlightMask>(find.byType(HighlightMask));
    expect(mask.maskColor, const Color(0xAA101820));
    expect(mask.padding, const EdgeInsets.all(12));
    expect(mask.borderRadius, radius);

    await SuperOverlay.dismiss(status: DismissStatus.allAttach);
    await tester.pumpAndSettle();
  });
}
