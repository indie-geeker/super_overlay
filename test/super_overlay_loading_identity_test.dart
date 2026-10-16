import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

import 'overlay_test_support.dart';

Future<void> _mount(WidgetTester tester, {bool animateClose = false}) async {
  final integration = SuperOverlay.integration();
  final config = overlayConfig.loading;
  if (animateClose) {
    overlayConfig.loading = const LoadingConfig(nonAnimationTypes: []);
  }
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
    overlayConfig.loading = config;
  });
  await tester.pumpWidget(
    MaterialApp(
      builder: integration.builder,
      navigatorObservers: [integration.observer],
      home: const Scaffold(),
    ),
  );
}

String _identity() {
  for (var i = 0; i < 10000; i++) {
    final tag = '_super_overlay_command_loading_$i';
    if (SuperOverlay.exists(
      tag: tag,
      surfaces: const {OverlaySurface.loading},
    )) {
      return tag;
    }
  }
  throw StateError('No active loading identity.');
}

OverlayHandle<void> _show(
  String text, {
  String? tag,
  Duration minimum = Duration.zero,
}) => SuperOverlay.loading.show(
  builder: (_) => Text(text),
  options: OverlayLoadingOptions(tag: tag, minimumVisibleDuration: minimum),
);

void main() {
  for (final paintFirst in [false, true]) {
    testWidgets(
      'old Loading handle cannot close or see its business-tag collision, paint=$paintFirst',
      (tester) async {
        await _mount(tester);
        final first = _show('first');
        if (paintFirst) await tester.pumpAndSettle();
        final identity = _identity();
        final second = _show('second', tag: identity);
        expect(first.isVisible, isFalse);
        final closing = first.close();
        first.refresh();
        await tester.pumpAndSettle();
        await closing;
        expect(second.isVisible, isTrue);
        expect(find.text('second'), findsOneWidget);
        final global = SuperOverlay.close(
          target: OverlayCloseTarget.loading,
          tag: identity,
        );
        await tester.pumpAndSettle();
        await global;
        expect(second.isVisible, isFalse);
      },
    );
  }

  testWidgets(
    'stale Loading close does not join a replacement minimum-duration wait',
    (tester) async {
      await _mount(tester);
      final first = _show('first');
      final identity = _identity();
      final second = _show(
        'second',
        tag: identity,
        minimum: const Duration(seconds: 1),
      );
      var secondClosed = false;
      final secondClose = second.close().then((_) => secondClosed = true);
      var firstClosed = false;
      final firstClose = first.close().then((_) => firstClosed = true);
      await tester.pump();
      expect(firstClosed, isTrue);
      expect(secondClosed, isFalse);
      expect(second.isVisible, isTrue);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await Future.wait([firstClose, secondClose]);
    },
  );

  testWidgets(
    'old Loading close leaves a deferred business-tag collision intact',
    (tester) async {
      await _mount(tester, animateClose: true);
      final first = _show('first');
      await tester.pumpAndSettle();
      final identity = _identity();
      final global = SuperOverlay.loading.close();
      final second = _show('deferred second', tag: identity);
      expect(second.isVisible, isFalse);
      final oldClose = first.close();
      await tester.pumpAndSettle();
      await Future.wait([global, oldClose]);
      expect(second.isVisible, isTrue);
      expect(find.text('deferred second'), findsOneWidget);
      await second.visible;
      final closeSecond = second.close();
      await tester.pumpAndSettle();
      await closeSecond;
    },
  );

  testWidgets(
    'deferred Loading close does not join a pending business-tag collision',
    (tester) async {
      await _mount(tester, animateClose: true);
      final seed = _show('seed');
      final id = int.parse(_identity().split('_').last);
      final seedClose = seed.close();
      await tester.pumpAndSettle();
      await seedClose;
      _show('first', tag: '_super_overlay_command_loading_${id + 2}');
      await tester.pumpAndSettle();
      var oldSettled = false;
      final global = SuperOverlay.loading.close().then(
        (_) => oldSettled = true,
      );
      final second = _show('cancel deferred');
      var secondSettled = false;
      final secondClose = second.close().then((_) => secondSettled = true);
      await tester.pump(const Duration(milliseconds: 1));
      expect(secondSettled, isTrue);
      expect(oldSettled, isFalse);
      expect(second.isVisible, isFalse);
      await second.closed;
      await expectLater(second.visible, throwsStateError);
      await tester.pumpAndSettle();
      await Future.wait([global, secondClose]);
    },
  );
}
