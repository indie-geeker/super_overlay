import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';
import 'package:super_overlay/src/widget/animation/highlight_mask_animation.dart';
import 'package:super_overlay/src/widget/highlight_mask.dart';

Widget buildPopupGeometryApp(Widget child) {
  return MaterialApp(
    builder: SuperOverlayInit.init(),
    navigatorObservers: [SuperOverlayInit.observer],
    home: Scaffold(body: child),
  );
}

void main() {
  registerPopupGeometryTests();
}

void registerPopupGeometryTests() {
  testWidgets('popup appears relative to target widget', (tester) async {
    await tester.pumpWidget(
      buildPopupGeometryApp(
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
                      builder:
                          (_) => const SizedBox(
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

  testWidgets('popup target point overrides target context origin', (
    tester,
  ) async {
    late BuildContext targetContext;
    Offset? observedTargetOffset;
    Size? observedTargetSize;
    const targetKey = Key('point-target');
    const popupKey = Key('point-popup');
    const targetPoint = Offset(120, 160);

    await tester.pumpWidget(
      buildPopupGeometryApp(
        Stack(
          children: [
            Positioned(
              left: 30,
              top: 40,
              child: Builder(
                builder: (context) {
                  targetContext = context;
                  return const SizedBox(
                    key: targetKey,
                    width: 70,
                    height: 30,
                    child: Text('Point Target'),
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
          builder:
              (_) => const SizedBox(
                key: popupKey,
                width: 80,
                height: 20,
                child: Text('Point Popup'),
              ),
        )
        .withTargetPoint((targetOffset, targetSize) {
          observedTargetOffset = targetOffset;
          observedTargetSize = targetSize;
          return targetPoint;
        })
        .withTag('point-popup')
        .fire<void>();
    await tester.pumpAndSettle();

    expect(observedTargetOffset, tester.getTopLeft(find.byKey(targetKey)));
    expect(observedTargetSize, tester.getSize(find.byKey(targetKey)));
    final popupRect = tester.getRect(find.byKey(popupKey));
    expect(popupRect.center.dx, targetPoint.dx + observedTargetSize!.width / 2);
    expect(popupRect.top, targetPoint.dy + observedTargetSize!.height);

    await SuperOverlay.dismiss(
      status: DismissStatus.attach,
      tag: 'point-popup',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('popup can position from target point without target context', (
    tester,
  ) async {
    Offset? observedTargetOffset;
    Size? observedTargetSize;
    const popupKey = Key('targetless-point-popup');
    const targetPoint = Offset(240, 180);

    await tester.pumpWidget(buildPopupGeometryApp(const SizedBox.shrink()));

    SuperOverlay.showPopup(
          builder:
              (_) => const SizedBox(
                key: popupKey,
                width: 100,
                height: 24,
                child: Text('Targetless Popup'),
              ),
        )
        .withTargetPoint((targetOffset, targetSize) {
          observedTargetOffset = targetOffset;
          observedTargetSize = targetSize;
          return targetPoint;
        })
        .withTag('targetless-popup')
        .fire<void>();
    await tester.pumpAndSettle();

    expect(observedTargetOffset, Offset.zero);
    expect(observedTargetSize, Size.zero);
    final popupRect = tester.getRect(find.byKey(popupKey));
    expect(popupRect.center.dx, targetPoint.dx);
    expect(popupRect.top, targetPoint.dy);

    await SuperOverlay.dismiss(
      status: DismissStatus.attach,
      tag: 'targetless-popup',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('popup skips invalid target point geometry', (tester) async {
    await tester.pumpWidget(buildPopupGeometryApp(const SizedBox.shrink()));

    SuperOverlay.showPopup(
          builder:
              (_) => const SizedBox(
                width: 80,
                height: 20,
                child: Text('Invalid Point Popup'),
              ),
        )
        .withTargetPoint((_, _) => const Offset(double.nan, 10))
        .withTag('invalid-point-popup')
        .fire<void>();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Invalid Point Popup'), findsNothing);

    await SuperOverlay.dismiss(
      status: DismissStatus.attach,
      tag: 'invalid-point-popup',
      force: true,
    );
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
      buildPopupGeometryApp(
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
      builder:
          (_) => const SizedBox(
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
      builder:
          (_) => const SizedBox(
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
      buildPopupGeometryApp(
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
                      builder:
                          (_) => const SizedBox(
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

  testWidgets('popup near left edge clamps without moving vertically', (
    tester,
  ) async {
    late BuildContext targetContext;
    const targetKey = Key('left-edge-target');
    const popupKey = Key('left-edge-popup');

    await tester.pumpWidget(
      buildPopupGeometryApp(
        Stack(
          children: [
            Positioned(
              left: 0,
              top: 100,
              child: Builder(
                builder: (context) {
                  targetContext = context;
                  return const SizedBox(
                    key: targetKey,
                    width: 40,
                    height: 30,
                    child: Text('Left Edge Target'),
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
          builder:
              (_) => const SizedBox(
                key: popupKey,
                width: 120,
                height: 24,
                child: Text('Left Edge Popup'),
              ),
        )
        .withAlignment(Alignment.bottomLeft)
        .withAlignmentMode(PopupAlignmentMode.center)
        .withTag('left-edge-popup')
        .fire<void>();
    await tester.pumpAndSettle();

    final targetRect = tester.getRect(find.byKey(targetKey));
    final popupRect = tester.getRect(find.byKey(popupKey));
    expect(popupRect.left, 0);
    expect(popupRect.top, targetRect.bottom);

    await SuperOverlay.dismiss(
      status: DismissStatus.attach,
      tag: 'left-edge-popup',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('popup near bottom edge clamps to screen bounds', (tester) async {
    late BuildContext targetContext;
    const popupKey = Key('bottom-edge-popup');

    await tester.pumpWidget(
      buildPopupGeometryApp(
        Stack(
          children: [
            Positioned(
              left: 220,
              top: 570,
              child: Builder(
                builder: (context) {
                  targetContext = context;
                  return const SizedBox(
                    width: 80,
                    height: 24,
                    child: Text('Bottom Edge Target'),
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
          builder:
              (_) => const SizedBox(
                key: popupKey,
                width: 100,
                height: 80,
                child: Text('Bottom Edge Popup'),
              ),
        )
        .withAlignment(Alignment.bottomCenter)
        .withAlignmentMode(PopupAlignmentMode.center)
        .withTag('bottom-edge-popup')
        .fire<void>();
    await tester.pumpAndSettle();

    final popupRect = tester.getRect(find.byKey(popupKey));
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(popupRect.bottom, screen.height);

    await SuperOverlay.dismiss(
      status: DismissStatus.attach,
      tag: 'bottom-edge-popup',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('popup corner alignment supports inside center and outside', (
    tester,
  ) async {
    late BuildContext targetContext;
    const targetKey = Key('corner-mode-target');

    await tester.pumpWidget(
      buildPopupGeometryApp(
        Stack(
          children: [
            Positioned(
              left: 200,
              top: 180,
              child: Builder(
                builder: (context) {
                  targetContext = context;
                  return const SizedBox(
                    key: targetKey,
                    width: 80,
                    height: 40,
                    child: Text('Corner Target'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    Future<Rect> showWithMode(PopupAlignmentMode mode, String tag) async {
      final popupKey = Key('$tag-popup');
      SuperOverlay.showPopup(
            targetContext: targetContext,
            builder:
                (_) => SizedBox(
                  key: popupKey,
                  width: 60,
                  height: 24,
                  child: Text('$tag Popup'),
                ),
          )
          .withAlignment(Alignment.bottomLeft)
          .withAlignmentMode(mode)
          .withTag(tag)
          .fire<void>();
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byKey(popupKey));
      await SuperOverlay.dismiss(status: DismissStatus.attach, tag: tag);
      await tester.pumpAndSettle();
      return rect;
    }

    final targetRect = tester.getRect(find.byKey(targetKey));
    final insideRect = await showWithMode(PopupAlignmentMode.inside, 'inside');
    final centerRect = await showWithMode(PopupAlignmentMode.center, 'center');
    final outsideRect = await showWithMode(
      PopupAlignmentMode.outside,
      'outside',
    );

    expect(insideRect.left, targetRect.left);
    expect(centerRect.center.dx, targetRect.left);
    expect(outsideRect.right, targetRect.left);
  });

  testWidgets('popup replacement receives target and popup geometry', (
    tester,
  ) async {
    late BuildContext targetContext;
    PopupLayoutInfo? observedInfo;
    const targetKey = Key('replacement-target');
    const replacementKey = Key('replacement-popup');

    await tester.pumpWidget(
      buildPopupGeometryApp(
        Stack(
          children: [
            Positioned(
              left: 80,
              top: 90,
              child: Builder(
                builder: (context) {
                  targetContext = context;
                  return const SizedBox(
                    key: targetKey,
                    width: 70,
                    height: 30,
                    child: Text('Replacement Target'),
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
          builder:
              (_) => const SizedBox(
                width: 60,
                height: 20,
                child: Text('Original Popup'),
              ),
        )
        .withReplacement((info) {
          observedInfo = info;
          return const SizedBox(
            key: replacementKey,
            width: 60,
            height: 20,
            child: Text('Replacement Popup'),
          );
        })
        .withTag('replacement-popup')
        .fire<void>();
    await tester.pumpAndSettle();

    final targetRect = tester.getRect(find.byKey(targetKey));
    final popupRect = tester.getRect(find.byKey(replacementKey));
    expect(find.text('Original Popup'), findsNothing);
    expect(observedInfo?.targetOffset, targetRect.topLeft);
    expect(observedInfo?.targetSize, targetRect.size);
    expect(observedInfo?.popupOffset, popupRect.topLeft);
    expect(observedInfo?.popupSize, popupRect.size);

    await SuperOverlay.dismiss(
      status: DismissStatus.attach,
      tag: 'replacement-popup',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('popup adjustment can replace content and alignment', (
    tester,
  ) async {
    late BuildContext targetContext;
    const targetKey = Key('adjustment-target');
    const adjustedKey = Key('adjusted-popup');

    await tester.pumpWidget(
      buildPopupGeometryApp(
        Stack(
          children: [
            Positioned(
              left: 200,
              top: 180,
              child: Builder(
                builder: (context) {
                  targetContext = context;
                  return const SizedBox(
                    key: targetKey,
                    width: 80,
                    height: 40,
                    child: Text('Adjustment Target'),
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
          builder:
              (_) => const SizedBox(
                width: 50,
                height: 20,
                child: Text('Unadjusted Popup'),
              ),
        )
        .withAdjustment(
          (_) => const PopupAdjustment(
            alignment: Alignment.centerRight,
            builder: _adjustedPopupBuilder,
          ),
        )
        .withTag('adjusted-popup')
        .fire<void>();
    await tester.pumpAndSettle();

    final targetRect = tester.getRect(find.byKey(targetKey));
    final popupRect = tester.getRect(find.byKey(adjustedKey));
    expect(find.text('Unadjusted Popup'), findsNothing);
    expect(popupRect.left, targetRect.right);
    expect(popupRect.center.dy, targetRect.center.dy);

    await SuperOverlay.dismiss(
      status: DismissStatus.attach,
      tag: 'adjusted-popup',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('popup scale origin can be derived from popup size', (
    tester,
  ) async {
    final originalAttach = SuperOverlay.config.attach;
    addTearDown(() => SuperOverlay.config.attach = originalAttach);
    SuperOverlay.config.attach = const AttachDialogConfig(
      animationType: AnimationType.scale,
      nonAnimationTypes: [],
    );

    await tester.pumpWidget(buildPopupGeometryApp(const SizedBox.shrink()));

    SuperOverlay.showPopup(
          builder:
              (_) => const SizedBox(
                width: 80,
                height: 40,
                child: Text('Scaled Popup'),
              ),
        )
        .withTargetPoint((_, _) => const Offset(200, 120))
        .withScaleOrigin(
          (popupSize) => Offset(popupSize.width, popupSize.height),
        )
        .withTag('scaled-popup')
        .fire<void>();
    await tester.pumpAndSettle();

    final transition = tester.widget<ScaleTransition>(
      find.byType(ScaleTransition).last,
    );
    expect(transition.alignment, const Alignment(1, 1));

    await SuperOverlay.dismiss(
      status: DismissStatus.attach,
      tag: 'scaled-popup',
      force: true,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('popup controller refresh rebuilds replacement content', (
    tester,
  ) async {
    final controller = SuperOverlayController();
    var count = 0;

    await tester.pumpWidget(buildPopupGeometryApp(const SizedBox.shrink()));

    SuperOverlay.showPopup(
          builder:
              (_) => const SizedBox(
                width: 80,
                height: 20,
                child: Text('Base Replacement Popup'),
              ),
        )
        .withTargetPoint((_, _) => const Offset(220, 140))
        .withReplacement(
          (_) => SizedBox(
            width: 80,
            height: 20,
            child: Text('Replacement Count $count'),
          ),
        )
        .withController(controller)
        .withTag('replacement-refresh-popup')
        .fire<void>();
    await tester.pumpAndSettle();

    expect(find.text('Replacement Count 0'), findsOneWidget);

    count = 1;
    controller.refresh();
    await tester.pumpAndSettle();

    expect(find.text('Replacement Count 0'), findsNothing);
    expect(find.text('Replacement Count 1'), findsOneWidget);

    await SuperOverlay.dismiss(
      status: DismissStatus.attach,
      tag: 'replacement-refresh-popup',
      force: true,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('popup highlight creates a transparent target area', (
    tester,
  ) async {
    var targetClicks = 0;

    await tester.pumpWidget(
      buildPopupGeometryApp(
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
      buildPopupGeometryApp(
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

  testWidgets('popup highlight mask can skip fade animation', (tester) async {
    final originalAttach = SuperOverlay.config.attach;
    addTearDown(() => SuperOverlay.config.attach = originalAttach);
    SuperOverlay.config.attach = const AttachDialogConfig(
      nonAnimationTypes: [NonAnimationType.highlightMask],
    );

    late BuildContext targetContext;
    await tester.pumpWidget(
      buildPopupGeometryApp(
        Center(
          child: Builder(
            builder: (context) {
              targetContext = context;
              return const SizedBox(
                width: 80,
                height: 40,
                child: Text('No Fade Target'),
              );
            },
          ),
        ),
      ),
    );

    SuperOverlay.showPopup(
      targetContext: targetContext,
      builder: (_) => const Text('No Fade Popup'),
    ).withHighlight().withTag('no-fade-popup').fire<void>();
    await tester.pumpAndSettle();

    final animation = tester.widget<HighlightMaskAnimation>(
      find.byType(HighlightMaskAnimation),
    );
    expect(animation.animate, isFalse);

    await SuperOverlay.dismiss(
      status: DismissStatus.attach,
      tag: 'no-fade-popup',
    );
    await tester.pumpAndSettle();
  });
}

Widget _adjustedPopupBuilder(BuildContext context) {
  return const SizedBox(
    key: Key('adjusted-popup'),
    width: 50,
    height: 20,
    child: Text('Adjusted Popup'),
  );
}
