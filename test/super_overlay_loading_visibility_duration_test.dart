import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

Future<SuperOverlayIntegration> _mount(WidgetTester tester) async {
  final integration = SuperOverlay.integration();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      builder: integration.builder,
      navigatorObservers: [integration.observer],
      home: const Scaffold(),
    ),
  );
  return integration;
}

OverlayHandle<void> _show(String message, {Duration? displayDuration}) =>
    SuperOverlay.loading.show(
      message: message,
      builder: (_) => Text(message),
      options: OverlayLoadingOptions(
        tag: 'shared-loading',
        minimumVisibleDuration: const Duration(seconds: 1),
        displayDuration: displayDuration,
      ),
    );

void main() {
  for (final closeBeforeFrame in [false, true]) {
    testWidgets(
      'delayed first frame starts minimum visible budget, early close=$closeBeforeFrame',
      (tester) async {
        await _mount(tester);
        final handle = _show('delayed loading');
        var closed = false;
        Future<void> close() => handle.close().then((_) => closed = true);
        final earlyClose = closeBeforeFrame ? close() : null;
        // Wall time before first paint does not spend the visible-time budget.
        await tester.pump(const Duration(seconds: 2));
        await handle.visible;
        final closing = earlyClose ?? close();
        await tester.pump(const Duration(milliseconds: 999));
        expect(closed, isFalse);
        expect(handle.isVisible, isTrue);
        expect(find.text('delayed loading'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
        await closing;
        await handle.closed;
        expect(closed, isTrue);
        expect(handle.isVisible, isFalse);
      },
    );
  }

  testWidgets(
    'automatic close cannot consume minimum budget before first paint',
    (tester) async {
      await _mount(tester);
      final handle = _show(
        'automatic loading',
        displayDuration: const Duration(milliseconds: 100),
      );
      var closed = false;
      handle.closed.then((_) => closed = true);
      await tester.pump(const Duration(seconds: 2));
      await handle.visible;
      await tester.pump(const Duration(milliseconds: 999));
      expect(closed, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      await handle.closed;
      expect(closed, isTrue);
    },
  );

  for (final replaceBeforeFrame in [false, true]) {
    testWidgets(
      'replacement owns its minimum budget, before first frame=$replaceBeforeFrame',
      (tester) async {
        await _mount(tester);
        final first = _show('first loading');
        if (!replaceBeforeFrame) {
          await tester.pump();
          await first.visible;
          await tester.pump(const Duration(milliseconds: 600));
        }
        final firstClose = first.close();
        final replacement = _show('replacement loading');
        var replacementClosed = false;
        final closing = replacement.close().then(
          (_) => replacementClosed = true,
        );
        await tester.pump(const Duration(milliseconds: 800));
        await replacement.visible;
        await firstClose;
        await first.closed;
        expect(first.isVisible, isFalse);
        await tester.pump(const Duration(milliseconds: 999));
        expect(replacementClosed, isFalse);
        expect(replacement.isVisible, isTrue);
        // A stale handle cannot release the current call's budget.
        await first.close();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
        await closing;
        expect(replacementClosed, isTrue);
      },
    );
  }

  for (final afterFirstFrame in [false, true]) {
    testWidgets(
      'host teardown settles pending minimum, painted=$afterFirstFrame',
      (tester) async {
        await _mount(tester);
        final handle = _show('teardown loading');
        final closing = handle.close();
        if (afterFirstFrame) {
          await tester.pump();
          await handle.visible;
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await closing;
        await handle.closed;
        expect(handle.isVisible, isFalse);
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('teardown loading'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('zero minimum still closes before first paint', (tester) async {
    await _mount(tester);
    final handle = SuperOverlay.loading.show(message: 'never painted');
    final rejected = expectLater(handle.visible, throwsStateError);
    final closing = handle.close();
    await tester.pumpAndSettle();
    await closing;
    await rejected;
    expect(handle.isVisible, isFalse);
  });

  for (final fail in [false, true]) {
    testWidgets(
      'loading.run preserves synchronous work and minimum, error=$fail',
      (tester) async {
        await _mount(tester);
        var started = false;
        var settled = false;
        Object? caught;
        int? value;
        final error = StateError('business failure');
        final task = SuperOverlay.loading.run<int>(
          () {
            started = true;
            if (fail) throw error;
            return 42;
          },
          builder: (_) => const Text('running loading'),
          options: const OverlayLoadingOptions(
            minimumVisibleDuration: Duration(seconds: 1),
          ),
        );
        final result = task.then<void>(
          (result) {
            settled = true;
            value = result;
          },
          onError: (Object failure, StackTrace _) {
            settled = true;
            caught = failure;
          },
        );
        expect(started, isTrue);
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 999));
        expect(settled, isFalse);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
        await result;
        expect(settled, isTrue);
        expect(value, fail ? isNull : 42);
        expect(caught, fail ? same(error) : isNull);
        expect(SuperOverlay.exists(), isFalse);
      },
    );
  }
}
