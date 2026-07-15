import 'package:flutter/material.dart';
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

    Future<SizeTransition> openPopup(Alignment alignment) async {
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
        matching: find.byType(SizeTransition),
      );
      expect(transition, findsOneWidget);
      return tester.widget<SizeTransition>(transition);
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
    expect(below.axis, Axis.vertical);
    expect(below.axisAlignment, -1);
    expect(below.fixedCrossAxisSizeFactor, 1);
    await closeCurrentPopup();

    final above = await openPopup(Alignment.topCenter);
    expect(above.axis, Axis.vertical);
    expect(above.axisAlignment, 1);
    await closeCurrentPopup();

    final right = await openPopup(Alignment.centerRight);
    expect(right.axis, Axis.horizontal);
    expect(right.axisAlignment, -1);
    expect(right.fixedCrossAxisSizeFactor, 1);
    await closeCurrentPopup();

    final left = await openPopup(Alignment.centerLeft);
    expect(left.axis, Axis.horizontal);
    expect(left.axisAlignment, 1);
    await closeCurrentPopup();
  });
}
