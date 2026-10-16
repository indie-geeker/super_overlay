import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

Future<BuildContext> _mountTarget(WidgetTester tester, Rect bounds) async {
  final integration = SuperOverlay.integration();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  });
  late BuildContext target;
  await tester.pumpWidget(
    MaterialApp(
      builder: integration.builder,
      navigatorObservers: [integration.observer],
      home: Scaffold(
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fromRect(
              rect: bounds,
              child: Builder(
                builder: (context) {
                  target = context;
                  return const SizedBox.expand();
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return target;
}

void main() {
  final invalidBounds = <String, Rect>{
    'zero size': const Rect.fromLTWH(100, 100, 0, 0),
    'zero width': const Rect.fromLTWH(100, 100, 0, 30),
    'zero height': const Rect.fromLTWH(100, 100, 80, 0),
    'left': const Rect.fromLTWH(-80, 100, 80, 30),
    'top': const Rect.fromLTWH(100, -30, 80, 30),
    'right': const Rect.fromLTWH(800, 100, 80, 30),
    'bottom': const Rect.fromLTWH(100, 600, 80, 30),
  };
  for (final bounds in invalidBounds.entries) {
    testWidgets(
      'initial ${bounds.key} target rejects visible before building',
      (tester) async {
        final target = await _mountTarget(tester, bounds.value);
        var builds = 0;
        final handle = SuperOverlay.popup.show<void>(
          targetContext: target,
          builder: (_, _) {
            builds++;
            return const Text('must not render');
          },
          options: const OverlayPopupOptions(tag: 'invalid-initial'),
        );
        final rejected = expectLater(handle.visible, throwsStateError);
        await tester.pumpAndSettle();
        await rejected;
        await handle.closed;
        expect(target.mounted, isTrue);
        expect(builds, 0);
        expect(handle.isVisible, isFalse);
        expect(SuperOverlay.exists(tag: 'invalid-initial'), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('point override cannot revive an invalid mounted anchor', (
    tester,
  ) async {
    final target = await _mountTarget(
      tester,
      const Rect.fromLTWH(-100, 100, 80, 30),
    );
    final handle = SuperOverlay.popup.show<void>(
      targetContext: target,
      builder: (_, _) => const Text('must not render'),
      options: OverlayPopupOptions(
        targetPointBuilder: (_, _) => const Offset(100, 100),
      ),
    );
    final rejected = expectLater(handle.visible, throwsStateError);
    await tester.pumpAndSettle();
    await rejected;
    await handle.closed;
    expect(find.text('must not render'), findsNothing);
  });

  testWidgets('partially clipped initial anchor still becomes visible', (
    tester,
  ) async {
    final target = await _mountTarget(
      tester,
      const Rect.fromLTWH(-20, 100, 80, 30),
    );
    final handle = SuperOverlay.popup.show<void>(
      targetContext: target,
      builder: (_, _) => const Text('partially clipped'),
    );
    await tester.pumpAndSettle();
    await handle.visible;
    expect(handle.isVisible, isTrue);
    expect(find.text('partially clipped'), findsOneWidget);
  });

  testWidgets('explicit point without an anchor retains zero-size geometry', (
    tester,
  ) async {
    await _mountTarget(tester, const Rect.fromLTWH(0, 0, 0, 0));
    final handle = SuperOverlay.popup.show<void>(
      builder:
          (_, _) => const SizedBox(
            key: ValueKey('point-popup'),
            width: 100,
            height: 40,
          ),
      options: OverlayPopupOptions(
        targetPointBuilder: (_, _) => const Offset(240, 180),
      ),
    );
    await tester.pumpAndSettle();
    await handle.visible;
    final rect = tester.getRect(find.byKey(const ValueKey('point-popup')));
    expect(rect.topCenter, const Offset(240, 180));
  });
}
