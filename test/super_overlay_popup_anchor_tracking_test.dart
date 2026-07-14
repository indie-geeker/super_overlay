import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';
import 'package:super_overlay/src/widget/highlight_mask.dart';

import 'super_overlay_popup_geometry_cases.dart';

void main() {
  testWidgets('popup follows a target on the frame after scrolling', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    late BuildContext targetContext;
    const targetKey = Key('moving-anchor-target');
    const popupKey = Key('moving-anchor-popup');

    await tester.pumpWidget(
      buildPopupGeometryApp(
        SingleChildScrollView(
          controller: scrollController,
          child: SizedBox(
            height: 1000,
            child: Stack(
              children: [
                Positioned(
                  left: 160,
                  top: 220,
                  child: Builder(
                    builder: (context) {
                      targetContext = context;
                      return const SizedBox(
                        key: targetKey,
                        width: 100,
                        height: 40,
                        child: Text('Moving Anchor'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder:
          (_) => const SizedBox(
            key: popupKey,
            width: 120,
            height: 32,
            child: Text('Tracked Popup'),
          ),
      options: const OverlayPopupOptions(tag: 'moving-anchor-popup'),
    );
    await tester.pumpAndSettle();

    final initialTarget = tester.getRect(find.byKey(targetKey));
    final initialPopup = tester.getRect(find.byKey(popupKey));
    expect(initialPopup.top, initialTarget.bottom);

    scrollController.jumpTo(60);
    await tester.pump();
    await tester.pump();

    final movedTarget = tester.getRect(find.byKey(targetKey));
    final movedPopup = tester.getRect(find.byKey(popupKey));
    expect(movedTarget.top, initialTarget.top - 60);
    expect(movedPopup.top, movedTarget.bottom);

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
  });

  testWidgets('moving highlight uses one rect for cutout and target taps', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    late BuildContext targetContext;
    var targetTaps = 0;
    const targetKey = Key('highlight-moving-target');

    await tester.pumpWidget(
      buildPopupGeometryApp(
        SingleChildScrollView(
          controller: scrollController,
          child: SizedBox(
            height: 900,
            child: Stack(
              children: [
                Positioned(
                  left: 180,
                  top: 240,
                  child: Builder(
                    builder: (context) {
                      targetContext = context;
                      return GestureDetector(
                        key: targetKey,
                        behavior: HitTestBehavior.opaque,
                        onTap: () => targetTaps++,
                        child: const SizedBox(
                          width: 120,
                          height: 44,
                          child: Text('Moving Highlight Target'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Moving Highlight Popup'),
      options: const OverlayPopupOptions(
        tag: 'moving-highlight-popup',
        highlightTarget: true,
      ),
    );
    await tester.pumpAndSettle();

    scrollController.jumpTo(70);
    await tester.pump();
    await tester.pump();

    final targetRect = tester.getRect(find.byKey(targetKey));
    final mask = tester.widget<HighlightMask>(find.byType(HighlightMask));
    expect(mask.targetRect, targetRect);

    await tester.tapAt(targetRect.center);
    await tester.pump();
    expect(targetTaps, 1);
    await handle.closed;
    expect(handle.isVisible, isFalse);
  });

  testWidgets('mask ignore area stays fixed in overlay host coordinates', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    late BuildContext targetContext;
    var fixedAreaTaps = 0;
    const ignoreArea = Rect.fromLTWH(16, 16, 140, 52);

    await tester.pumpWidget(
      buildPopupGeometryApp(
        Stack(
          children: [
            Positioned.fromRect(
              rect: ignoreArea,
              child: TextButton(
                onPressed: () => fixedAreaTaps++,
                child: const Text('Fixed Ignore Action'),
              ),
            ),
            Positioned.fill(
              top: 100,
              child: SingleChildScrollView(
                controller: scrollController,
                child: SizedBox(
                  height: 900,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 220,
                        top: 240,
                        child: Builder(
                          builder: (context) {
                            targetContext = context;
                            return const SizedBox(
                              width: 100,
                              height: 40,
                              child: Text('Ignore Area Anchor'),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Fixed Ignore Popup'),
      options: const OverlayPopupOptions(
        tag: 'fixed-ignore-popup',
        maskIgnoreArea: ignoreArea,
      ),
    );
    await tester.pumpAndSettle();

    scrollController.jumpTo(80);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Fixed Ignore Action'));
    await tester.pump();

    expect(fixedAreaTaps, 1);
    expect(handle.isVisible, isTrue);
    await _closeHandle(tester, handle);
  });

  testWidgets('sub-tolerance anchor movement does not rebuild popup', (
    tester,
  ) async {
    final targetOffset = ValueNotifier<Offset>(const Offset(160, 220));
    addTearDown(targetOffset.dispose);
    late BuildContext targetContext;
    var popupBuilds = 0;

    await tester.pumpWidget(
      buildPopupGeometryApp(
        ValueListenableBuilder<Offset>(
          valueListenable: targetOffset,
          builder:
              (context, offset, child) => Stack(
                children: [
                  Positioned(
                    left: offset.dx,
                    top: offset.dy,
                    child: Builder(
                      builder: (context) {
                        targetContext = context;
                        return const SizedBox(
                          width: 100,
                          height: 40,
                          child: Text('Tolerance Anchor'),
                        );
                      },
                    ),
                  ),
                ],
              ),
        ),
      ),
    );

    final handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) {
        popupBuilds++;
        return const Text('Tolerance Popup');
      },
      options: const OverlayPopupOptions(tag: 'tolerance-popup'),
    );
    await tester.pumpAndSettle();
    final buildsBeforeMovement = popupBuilds;

    targetOffset.value = const Offset(160.25, 220.25);
    await tester.pump();
    await tester.pump();

    expect(popupBuilds, buildsBeforeMovement);
    await _closeHandle(tester, handle);
  });

  testWidgets('unmounted popup target fails closed and removes its record', (
    tester,
  ) async {
    final showTarget = ValueNotifier<bool>(true);
    addTearDown(showTarget.dispose);
    late BuildContext targetContext;

    await tester.pumpWidget(
      buildPopupGeometryApp(
        ValueListenableBuilder<bool>(
          valueListenable: showTarget,
          builder: (context, visible, child) {
            if (!visible) {
              return const SizedBox.shrink();
            }
            return Builder(
              builder: (context) {
                targetContext = context;
                return const SizedBox(
                  width: 100,
                  height: 40,
                  child: Text('Disposable Anchor'),
                );
              },
            );
          },
        ),
      ),
    );

    final handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Disposable Popup'),
      options: const OverlayPopupOptions(tag: 'disposable-popup'),
    );
    await tester.pumpAndSettle();

    showTarget.value = false;
    await tester.pumpAndSettle();

    await handle.closed;
    expect(handle.isVisible, isFalse);
    expect(SuperOverlay.exists(tag: 'disposable-popup'), isFalse);
    expect(find.text('Disposable Popup'), findsNothing);
  });

  testWidgets('zero-sized popup target fails closed and removes its record', (
    tester,
  ) async {
    final targetSize = ValueNotifier<double>(40);
    addTearDown(targetSize.dispose);
    late BuildContext targetContext;

    await tester.pumpWidget(
      buildPopupGeometryApp(
        Center(
          child: ValueListenableBuilder<double>(
            valueListenable: targetSize,
            builder:
                (context, size, child) => Builder(
                  builder: (context) {
                    targetContext = context;
                    return SizedBox(
                      width: size,
                      height: size,
                      child: const Text('Resizable Anchor'),
                    );
                  },
                ),
          ),
        ),
      ),
    );

    final handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Invalid Geometry Popup'),
      options: const OverlayPopupOptions(tag: 'invalid-geometry-popup'),
    );
    await tester.pumpAndSettle();

    targetSize.value = 0;
    await tester.pumpAndSettle();

    await handle.closed;
    expect(handle.isVisible, isFalse);
    expect(SuperOverlay.exists(tag: 'invalid-geometry-popup'), isFalse);
    expect(find.text('Invalid Geometry Popup'), findsNothing);
  });

  testWidgets('popup uses root overlay coordinates with styled host', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    late BuildContext targetContext;
    const targetKey = Key('styled-host-target');
    const popupKey = Key('styled-host-popup');

    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlay.init(
          styleBuilder:
              (child) => Transform.translate(
                offset: const Offset(28, 36),
                child: Padding(
                  padding: const EdgeInsets.only(left: 22, top: 14),
                  child: child,
                ),
              ),
        ),
        navigatorObservers: [SuperOverlay.observer],
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scrollController,
            child: SizedBox(
              height: 900,
              child: Stack(
                children: [
                  Positioned(
                    left: 180,
                    top: 220,
                    child: Builder(
                      builder: (context) {
                        targetContext = context;
                        return const SizedBox(
                          key: targetKey,
                          width: 100,
                          height: 40,
                          child: Text('Styled Host Anchor'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder:
          (_) => const SizedBox(
            key: popupKey,
            width: 120,
            height: 32,
            child: Text('Styled Host Popup'),
          ),
      options: const OverlayPopupOptions(tag: 'styled-host-popup'),
    );
    await tester.pumpAndSettle();

    final targetRect = tester.getRect(find.byKey(targetKey));
    final popupRect = tester.getRect(find.byKey(popupKey));
    expect(popupRect.top, targetRect.bottom);
    expect(popupRect.center.dx, targetRect.center.dx);

    scrollController.jumpTo(55);
    await tester.pump();
    await tester.pump();

    final movedTargetRect = tester.getRect(find.byKey(targetKey));
    final movedPopupRect = tester.getRect(find.byKey(popupKey));
    expect(movedPopupRect.top, movedTargetRect.bottom);
    expect(movedPopupRect.center.dx, movedTargetRect.center.dx);

    await _closeHandle(tester, handle);
  });

  testWidgets('moving one target only rebuilds its anchored popup', (
    tester,
  ) async {
    final firstOffset = ValueNotifier<Offset>(const Offset(100, 180));
    final secondOffset = ValueNotifier<Offset>(const Offset(420, 180));
    addTearDown(firstOffset.dispose);
    addTearDown(secondOffset.dispose);
    late BuildContext firstContext;
    late BuildContext secondContext;
    var firstBuilds = 0;
    var secondBuilds = 0;

    await tester.pumpWidget(
      buildPopupGeometryApp(
        Stack(
          children: [
            ValueListenableBuilder<Offset>(
              valueListenable: firstOffset,
              builder:
                  (context, offset, child) => Positioned(
                    left: offset.dx,
                    top: offset.dy,
                    child: Builder(
                      builder: (context) {
                        firstContext = context;
                        return const SizedBox(
                          width: 80,
                          height: 32,
                          child: Text('First Anchor'),
                        );
                      },
                    ),
                  ),
            ),
            ValueListenableBuilder<Offset>(
              valueListenable: secondOffset,
              builder:
                  (context, offset, child) => Positioned(
                    left: offset.dx,
                    top: offset.dy,
                    child: Builder(
                      builder: (context) {
                        secondContext = context;
                        return const SizedBox(
                          width: 80,
                          height: 32,
                          child: Text('Second Anchor'),
                        );
                      },
                    ),
                  ),
            ),
          ],
        ),
      ),
    );

    final firstHandle = SuperOverlay.popup.show<void>(
      targetContext: firstContext,
      builder: (_) {
        firstBuilds++;
        return const Text('First Tracked Popup');
      },
      options: const OverlayPopupOptions(tag: 'first-tracked-popup'),
    );
    final secondHandle = SuperOverlay.popup.show<void>(
      targetContext: secondContext,
      builder: (_) {
        secondBuilds++;
        return const Text('Second Tracked Popup');
      },
      options: const OverlayPopupOptions(tag: 'second-tracked-popup'),
    );
    await tester.pumpAndSettle();
    final firstBuildsBeforeMovement = firstBuilds;
    final secondBuildsBeforeMovement = secondBuilds;

    firstOffset.value = const Offset(100, 240);
    await tester.pump();
    await tester.pump();

    expect(firstBuilds, greaterThan(firstBuildsBeforeMovement));
    expect(secondBuilds, secondBuildsBeforeMovement);

    await _closeHandle(tester, secondHandle);
    await _closeHandle(tester, firstHandle);
  });
}

Future<void> _closeHandle(
  WidgetTester tester,
  OverlayHandle<void> handle,
) async {
  final close = handle.close();
  await tester.pumpAndSettle();
  await close;
  await handle.closed;
}
