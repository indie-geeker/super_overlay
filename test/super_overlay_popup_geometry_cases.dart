import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

import 'overlay_test_support.dart';
import 'package:super_overlay/src/widget/animation/highlight_mask_animation.dart';
import 'package:super_overlay/src/widget/highlight_mask.dart';

Widget buildPopupGeometryApp(Widget child) {
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
  registerPopupGeometryTests();
}

void registerPopupGeometryTests() {
  testWidgets('popup appears relative to target widget', (tester) async {
    late OverlayHandle<void> handle;

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
                    handle = SuperOverlay.popup.show<void>(
                      targetContext: targetContext,
                      builder:
                          (_) => const SizedBox(
                            width: 120,
                            height: 40,
                            child: Text('Popup Content'),
                          ),
                      options: const OverlayPopupOptions(tag: 'popup'),
                    );
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

    await _closePopupHandle(tester, handle);
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
    final handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder:
          (_) => const SizedBox(
            key: popupKey,
            width: 80,
            height: 20,
            child: Text('Point Popup'),
          ),
      options: OverlayPopupOptions(
        tag: 'point-popup',
        targetPointBuilder: (targetOffset, targetSize) {
          observedTargetOffset = targetOffset;
          observedTargetSize = targetSize;
          return targetPoint;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(observedTargetOffset, tester.getTopLeft(find.byKey(targetKey)));
    expect(observedTargetSize, tester.getSize(find.byKey(targetKey)));
    final popupRect = tester.getRect(find.byKey(popupKey));
    expect(popupRect.center.dx, targetPoint.dx + observedTargetSize!.width / 2);
    expect(popupRect.top, targetPoint.dy + observedTargetSize!.height);

    await _closePopupHandle(tester, handle);
  });

  testWidgets('popup can position from target point without target context', (
    tester,
  ) async {
    Offset? observedTargetOffset;
    Size? observedTargetSize;
    const popupKey = Key('targetless-point-popup');
    const targetPoint = Offset(240, 180);

    await tester.pumpWidget(buildPopupGeometryApp(const SizedBox.shrink()));

    final handle = SuperOverlay.popup.show<void>(
      builder:
          (_) => const SizedBox(
            key: popupKey,
            width: 100,
            height: 24,
            child: Text('Targetless Popup'),
          ),
      options: OverlayPopupOptions(
        tag: 'targetless-popup',
        targetPointBuilder: (targetOffset, targetSize) {
          observedTargetOffset = targetOffset;
          observedTargetSize = targetSize;
          return targetPoint;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(observedTargetOffset, Offset.zero);
    expect(observedTargetSize, Size.zero);
    final popupRect = tester.getRect(find.byKey(popupKey));
    expect(popupRect.center.dx, targetPoint.dx);
    expect(popupRect.top, targetPoint.dy);

    await _closePopupHandle(tester, handle);
  });

  testWidgets('popup skips invalid target point geometry', (tester) async {
    await tester.pumpWidget(buildPopupGeometryApp(const SizedBox.shrink()));

    final handle = SuperOverlay.popup.show<void>(
      builder:
          (_) => const SizedBox(
            width: 80,
            height: 20,
            child: Text('Invalid Point Popup'),
          ),
      options: const OverlayPopupOptions(
        tag: 'invalid-point-popup',
        targetPointBuilder: _invalidTargetPoint,
      ),
    );
    var visibleSucceeded = false;
    Object? visibleError;
    handle.visible.then(
      (_) {
        visibleSucceeded = true;
      },
      onError: (Object error) {
        visibleError = error;
      },
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Invalid Point Popup'), findsNothing);
    expect(visibleSucceeded, isFalse);
    expect(visibleError, isA<StateError>());
    await handle.closed;
    expect(handle.isVisible, isFalse);
    expect(SuperOverlay.exists(tag: 'invalid-point-popup'), isFalse);
  });

  testWidgets('popup skips invalid target context geometry', (tester) async {
    late BuildContext targetContext;

    await tester.pumpWidget(
      buildPopupGeometryApp(
        Builder(
          builder: (context) {
            targetContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpWidget(buildPopupGeometryApp(const SizedBox.shrink()));

    final handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder:
          (_) => const SizedBox(
            width: 80,
            height: 20,
            child: Text('Invalid Context Popup'),
          ),
      options: const OverlayPopupOptions(tag: 'invalid-context-popup'),
    );
    var visibleSucceeded = false;
    Object? visibleError;
    handle.visible.then(
      (_) {
        visibleSucceeded = true;
      },
      onError: (Object error) {
        visibleError = error;
      },
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Invalid Context Popup'), findsNothing);
    expect(visibleSucceeded, isFalse);
    expect(visibleError, isA<StateError>());
    await handle.closed;
    expect(handle.isVisible, isFalse);
    expect(SuperOverlay.exists(tag: 'invalid-context-popup'), isFalse);
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

    final rightHandle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder:
          (_) => const SizedBox(
            key: rightPopupKey,
            width: 60,
            height: 30,
            child: Text('Right Popup'),
          ),
      options: const OverlayPopupOptions(
        tag: 'right-popup',
        alignment: Alignment.centerRight,
      ),
    );
    await tester.pumpAndSettle();

    final targetRect = tester.getRect(find.byKey(targetKey));
    final rightPopupRect = tester.getRect(find.byKey(rightPopupKey));
    expect(rightPopupRect.left, targetRect.right);
    expect(rightPopupRect.center.dy, targetRect.center.dy);

    await _closePopupHandle(tester, rightHandle);

    final leftHandle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder:
          (_) => const SizedBox(
            key: leftPopupKey,
            width: 60,
            height: 30,
            child: Text('Left Popup'),
          ),
      options: const OverlayPopupOptions(
        tag: 'left-popup',
        alignment: Alignment.centerLeft,
      ),
    );
    await tester.pumpAndSettle();

    final leftPopupRect = tester.getRect(find.byKey(leftPopupKey));
    expect(leftPopupRect.right, targetRect.left);
    expect(leftPopupRect.center.dy, targetRect.center.dy);

    await _closePopupHandle(tester, leftHandle);
  });

  testWidgets('popup clamps inside screen bounds', (tester) async {
    late OverlayHandle<void> handle;

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
                    handle = SuperOverlay.popup.show<void>(
                      targetContext: targetContext,
                      builder:
                          (_) => const SizedBox(
                            width: 320,
                            height: 160,
                            child: Text('Clamped Popup'),
                          ),
                    );
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

    await _closePopupHandle(tester, handle);
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

    final handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder:
          (_) => const SizedBox(
            key: popupKey,
            width: 120,
            height: 24,
            child: Text('Left Edge Popup'),
          ),
      options: const OverlayPopupOptions(
        tag: 'left-edge-popup',
        alignment: Alignment.bottomLeft,
        alignmentMode: OverlayPopupAlignmentMode.center,
      ),
    );
    await tester.pumpAndSettle();

    final targetRect = tester.getRect(find.byKey(targetKey));
    final popupRect = tester.getRect(find.byKey(popupKey));
    expect(popupRect.left, 0);
    expect(popupRect.top, targetRect.bottom);

    await _closePopupHandle(tester, handle);
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

    final handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder:
          (_) => const SizedBox(
            key: popupKey,
            width: 100,
            height: 80,
            child: Text('Bottom Edge Popup'),
          ),
      options: const OverlayPopupOptions(
        tag: 'bottom-edge-popup',
        alignment: Alignment.bottomCenter,
        alignmentMode: OverlayPopupAlignmentMode.center,
      ),
    );
    await tester.pumpAndSettle();

    final popupRect = tester.getRect(find.byKey(popupKey));
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(popupRect.bottom, screen.height);

    await _closePopupHandle(tester, handle);
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

    Future<Rect> showWithMode(
      OverlayPopupAlignmentMode mode,
      String tag,
    ) async {
      final popupKey = Key('$tag-popup');
      final handle = SuperOverlay.popup.show<void>(
        targetContext: targetContext,
        builder:
            (_) => SizedBox(
              key: popupKey,
              width: 60,
              height: 24,
              child: Text('$tag Popup'),
            ),
        options: OverlayPopupOptions(
          tag: tag,
          alignment: Alignment.bottomLeft,
          alignmentMode: mode,
        ),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byKey(popupKey));
      await _closePopupHandle(tester, handle);
      return rect;
    }

    final targetRect = tester.getRect(find.byKey(targetKey));
    final insideRect = await showWithMode(
      OverlayPopupAlignmentMode.inside,
      'inside',
    );
    final centerRect = await showWithMode(
      OverlayPopupAlignmentMode.center,
      'center',
    );
    final outsideRect = await showWithMode(
      OverlayPopupAlignmentMode.outside,
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

    final handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder:
          (_) => const SizedBox(
            width: 60,
            height: 20,
            child: Text('Original Popup'),
          ),
      options: OverlayPopupOptions(
        tag: 'replacement-popup',
        replacementBuilder: (info) {
          observedInfo = info;
          return const SizedBox(
            key: replacementKey,
            width: 60,
            height: 20,
            child: Text('Replacement Popup'),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    final targetRect = tester.getRect(find.byKey(targetKey));
    final popupRect = tester.getRect(find.byKey(replacementKey));
    expect(find.text('Original Popup'), findsNothing);
    expect(observedInfo?.targetOffset, targetRect.topLeft);
    expect(observedInfo?.targetSize, targetRect.size);
    expect(observedInfo?.popupOffset, popupRect.topLeft);
    expect(observedInfo?.popupSize, popupRect.size);

    await _closePopupHandle(tester, handle);
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

    final handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder:
          (_) => const SizedBox(
            width: 50,
            height: 20,
            child: Text('Unadjusted Popup'),
          ),
      options: const OverlayPopupOptions(
        tag: 'adjusted-popup',
        adjustmentBuilder: _adjustedPopupAdjustment,
      ),
    );
    await tester.pumpAndSettle();

    final targetRect = tester.getRect(find.byKey(targetKey));
    final popupRect = tester.getRect(find.byKey(adjustedKey));
    expect(find.text('Unadjusted Popup'), findsNothing);
    expect(popupRect.left, targetRect.right);
    expect(popupRect.center.dy, targetRect.center.dy);

    await _closePopupHandle(tester, handle);
  });

  testWidgets('popup scale origin can be derived from popup size', (
    tester,
  ) async {
    final originalAttach = overlayConfig.attach;
    addTearDown(() => overlayConfig.attach = originalAttach);
    overlayConfig.attach = const AttachDialogConfig(
      animationType: AnimationType.scale,
      nonAnimationTypes: [],
    );

    await tester.pumpWidget(buildPopupGeometryApp(const SizedBox.shrink()));

    final handle = SuperOverlay.popup.show<void>(
      builder:
          (_) => const SizedBox(
            width: 80,
            height: 40,
            child: Text('Scaled Popup'),
          ),
      options: const OverlayPopupOptions(
        tag: 'scaled-popup',
        targetPointBuilder: _scaledTargetPoint,
        scaleOriginBuilder: _bottomRightScaleOrigin,
      ),
    );
    await tester.pumpAndSettle();

    final transition = tester.widget<ScaleTransition>(
      find.byType(ScaleTransition).last,
    );
    expect(transition.alignment, const Alignment(1, 1));

    await _closePopupHandle(tester, handle);
  });

  testWidgets('popup controller refresh rebuilds replacement content', (
    tester,
  ) async {
    var count = 0;

    await tester.pumpWidget(buildPopupGeometryApp(const SizedBox.shrink()));

    final handle = SuperOverlay.popup.show<void>(
      builder:
          (_) => const SizedBox(
            width: 80,
            height: 20,
            child: Text('Base Replacement Popup'),
          ),
      options: OverlayPopupOptions(
        tag: 'replacement-refresh-popup',
        targetPointBuilder: _replacementRefreshTargetPoint,
        replacementBuilder:
            (_) => SizedBox(
              width: 80,
              height: 20,
              child: Text('Replacement Count $count'),
            ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Replacement Count 0'), findsOneWidget);

    count = 1;
    handle.refresh();
    await tester.pumpAndSettle();

    expect(find.text('Replacement Count 0'), findsNothing);
    expect(find.text('Replacement Count 1'), findsOneWidget);

    await _closePopupHandle(tester, handle);
  });

  testWidgets('popup highlight creates a transparent target area', (
    tester,
  ) async {
    var targetClicks = 0;
    late OverlayHandle<void> handle;

    await tester.pumpWidget(
      buildPopupGeometryApp(
        Center(
          child: Builder(
            builder: (targetContext) {
              return ElevatedButton(
                onPressed: () {
                  targetClicks++;
                  if (targetClicks == 1) {
                    handle = SuperOverlay.popup.show<void>(
                      targetContext: targetContext,
                      builder: (_) => const Text('Highlighted Popup'),
                      options: const OverlayPopupOptions(highlightTarget: true),
                    );
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

    await handle.closed;
    expect(handle.isVisible, isFalse);
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
    final handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Configured Highlight Popup'),
      options: OverlayPopupOptions(
        dismissOnMaskTap: false,
        highlightTarget: true,
        highlightMaskColor: const Color(0xAA101820),
        highlightPadding: const EdgeInsets.all(12),
        highlightBorderRadius: radius,
      ),
    );
    await tester.pumpAndSettle();

    final mask = tester.widget<HighlightMask>(find.byType(HighlightMask));
    expect(mask.maskColor, const Color(0xAA101820));
    expect(mask.padding, const EdgeInsets.all(12));
    expect(mask.borderRadius, radius);

    await _closePopupHandle(tester, handle);
  });

  testWidgets('popup highlight mask can skip fade animation', (tester) async {
    final originalAttach = overlayConfig.attach;
    addTearDown(() => overlayConfig.attach = originalAttach);
    overlayConfig.attach = const AttachDialogConfig(
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

    final handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('No Fade Popup'),
      options: const OverlayPopupOptions(
        tag: 'no-fade-popup',
        highlightTarget: true,
      ),
    );
    await tester.pumpAndSettle();

    final animation = tester.widget<HighlightMaskAnimation>(
      find.byType(HighlightMaskAnimation),
    );
    expect(animation.animate, isFalse);

    await _closePopupHandle(tester, handle);
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

Offset _invalidTargetPoint(Offset targetOffset, Size targetSize) {
  return const Offset(double.nan, 10);
}

PopupAdjustment _adjustedPopupAdjustment(PopupLayoutInfo info) {
  return const PopupAdjustment(
    alignment: Alignment.centerRight,
    builder: _adjustedPopupBuilder,
  );
}

Offset _scaledTargetPoint(Offset targetOffset, Size targetSize) {
  return const Offset(200, 120);
}

Offset _bottomRightScaleOrigin(Size popupSize) {
  return Offset(popupSize.width, popupSize.height);
}

Offset _replacementRefreshTargetPoint(Offset targetOffset, Size targetSize) {
  return const Offset(220, 140);
}
