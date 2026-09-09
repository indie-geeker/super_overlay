import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:super_overlay/src/widget/animation/popup_reveal_animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

import 'overlay_test_support.dart';

void main() {
  setUp(() {
    overlayConfig.attach = const AttachDialogConfig();
  });

  testWidgets('default popup reveal expands away from its target edge', (
    tester,
  ) async {
    expect(const AttachDialogConfig().animationType, AnimationType.size);

    late BuildContext targetContext;
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlay.init(),
        navigatorObservers: [SuperOverlay.observer],
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) {
                targetContext = context;
                return const SizedBox(width: 120, height: 48);
              },
            ),
          ),
        ),
      ),
    );

    OverlayHandle<void>? currentHandle;

    Future<({Rect content, Rect reveal})> openPopup(Alignment alignment) async {
      currentHandle = SuperOverlay.popup.show<void>(
        targetContext: targetContext,
        builder:
            (_) => const SizedBox(
              key: ValueKey('animated-popup'),
              width: 120,
              height: 80,
            ),
        options: OverlayPopupOptions(alignment: alignment),
      );
      await tester.pump();

      final transition = find.ancestor(
        of: find.byKey(const ValueKey('animated-popup')),
        matching: find.byType(PopupRevealAnimation),
      );
      expect(transition, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      final clip =
          find
              .descendant(of: transition, matching: find.byType(ClipRect))
              .first;
      return (
        content: tester.getRect(find.byKey(const ValueKey('animated-popup'))),
        reveal:
            (() {
              final render = tester.renderObject<RenderClipRect>(clip);
              return render
                  .describeApproximatePaintClip(render.child!)!
                  .shift(render.localToGlobal(Offset.zero));
            })(),
      );
    }

    Future<void> closeCurrentPopup() async {
      final handle = currentHandle;
      currentHandle = null;
      if (handle == null) {
        return;
      }
      final close = handle.close();
      await tester.pumpAndSettle();
      await close;
    }

    final below = await openPopup(Alignment.bottomCenter);
    expect(below.reveal.height, greaterThan(0));
    expect(below.reveal.height, lessThan(below.content.height));
    expect(below.reveal.top, closeTo(below.content.top, 0.01));
    expect(below.reveal.width, below.content.width);
    await closeCurrentPopup();

    final above = await openPopup(Alignment.topCenter);
    expect(above.reveal.bottom, closeTo(above.content.bottom, 0.01));
    expect(above.reveal.height, lessThan(above.content.height));
    await closeCurrentPopup();

    final right = await openPopup(Alignment.centerRight);
    expect(right.reveal.left, closeTo(right.content.left, 0.01));
    expect(right.reveal.width, lessThan(right.content.width));
    expect(right.reveal.height, right.content.height);
    await closeCurrentPopup();

    final left = await openPopup(Alignment.centerLeft);
    expect(left.reveal.right, closeTo(left.content.right, 0.01));
    expect(left.reveal.width, lessThan(left.content.width));
    await closeCurrentPopup();
  });
}
