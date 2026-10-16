import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

Future<SuperOverlayIntegration> _mount(WidgetTester tester, {Key? key}) async {
  final integration = SuperOverlay.integration();
  await tester.pumpWidget(
    MaterialApp(
      key: key,
      builder: integration.builder,
      navigatorObservers: [integration.observer],
      home: const Scaffold(body: Text('owner')),
    ),
  );
  return integration;
}

Future<void> _dispose(
  WidgetTester tester,
  SuperOverlayIntegration integration,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  integration.dispose();
}

class _FailingCleanupService extends OverlayLoadingService {
  @override
  OverlayHandle<void> show({
    String message = '',
    WidgetBuilder? builder,
    OverlayLoadingOptions options = const OverlayLoadingOptions(),
  }) => OverlayHandle<void>(
    visible: Future<void>.value(),
    closed: Future<void>.value(),
    close: ([void result]) => Future<void>.error(StateError('cleanup failure')),
    refresh: () {},
    isVisible: () => false,
  );
}

void main() {
  for (final popup in [false, true]) {
    testWidgets(
      '${popup ? 'popup' : 'dialog'} content closes its own typed handle',
      (tester) async {
        final integration = await _mount(tester);
        OverlayHandle<bool>? received;
        Widget content(BuildContext context, OverlayHandle<bool> overlay) {
          received = overlay;
          return SizedBox(
            width: 180,
            height: 80,
            child: FilledButton(
              onPressed: () => unawaited(overlay.close(true)),
              child: const Text('confirm'),
            ),
          );
        }

        final scoped = SuperOverlay.of(tester.element(find.text('owner')));
        final handle =
            popup
                ? scoped.popup.show<bool>(
                  targetContext: tester.element(find.text('owner')),
                  builder: content,
                )
                : scoped.dialog.show<bool>(builder: content);
        await tester.pumpAndSettle();
        expect(received, same(handle));
        await tester.tap(find.text('confirm'));
        await tester.pumpAndSettle();
        expect(await handle.closed, isTrue);
        expect(handle.isVisible, isFalse);
        await _dispose(tester, integration);
      },
    );
  }

  testWidgets('kept dialog rebuilds with its original content handle', (
    tester,
  ) async {
    final integration = await _mount(tester);
    OverlayHandle<bool>? contentHandle;
    final first = SuperOverlay.dialog.show<bool>(
      builder: (_, overlay) {
        contentHandle = overlay;
        return const Text('original');
      },
      options: const OverlayDialogOptions(tag: 'same'),
    );
    final kept = SuperOverlay.dialog.show<bool>(
      builder: (_, _) => throw StateError('duplicate builder must not run'),
      options: const OverlayDialogOptions(
        tag: 'same',
        strategy: OverlayStrategy.keepExisting,
      ),
    );
    await tester.pumpAndSettle();
    kept.refresh();
    await tester.pump();
    expect(contentHandle, same(first));
    final close = kept.close(true);
    await tester.pumpAndSettle();
    await close;
    expect(await first.closed, isTrue);
    expect(await kept.closed, isTrue);
    await _dispose(tester, integration);
  });

  for (final fails in [false, true]) {
    testWidgets('loading.run settles and cleans up, fails=$fails', (
      tester,
    ) async {
      final integration = await _mount(tester);
      final action = Completer<int>();
      final error = StateError('business failure');
      final run = SuperOverlay.loading.run(
        () => action.future,
        message: 'running',
      );
      final check =
          fails
              ? expectLater(run, throwsA(same(error)))
              : expectLater(run, completion(42));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('running'), findsOneWidget);
      if (fails) {
        action.completeError(error);
      } else {
        action.complete(42);
      }
      await tester.pumpAndSettle();
      await check;
      expect(
        SuperOverlay.exists(surfaces: const {OverlaySurface.loading}),
        isFalse,
      );
      await _dispose(tester, integration);
    });
  }

  testWidgets('loading.run supports synchronous work and synchronous failure', (
    tester,
  ) async {
    final integration = await _mount(tester);
    expect(await SuperOverlay.loading.run(() => 42), 42);
    final error = StateError('synchronous failure');
    await expectLater(
      SuperOverlay.loading.run<int>(() => throw error),
      throwsA(same(error)),
    );
    await tester.pumpAndSettle();
    expect(SuperOverlay.exists(), isFalse);
    await _dispose(tester, integration);
  });

  test(
    'loading.run preserves a business error when cleanup also fails',
    () async {
      final error = StateError('business failure');
      await expectLater(
        _FailingCleanupService().run<int>(() => throw error),
        throwsA(same(error)),
      );
      await expectLater(
        _FailingCleanupService().run(() => 42),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'cleanup failure',
          ),
        ),
      );
    },
  );

  testWidgets(
    'overlapping runs keep the newer loading until its work finishes',
    (tester) async {
      final integration = await _mount(tester);
      final firstAction = Completer<int>();
      final secondAction = Completer<int>();
      final first = SuperOverlay.loading.run(
        () => firstAction.future,
        message: 'first',
      );
      final second = SuperOverlay.loading.run(
        () => secondAction.future,
        message: 'second',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('second'), findsOneWidget);
      firstAction.complete(1);
      await tester.pump();
      expect(await first, 1);
      expect(find.text('second'), findsOneWidget);
      secondAction.complete(2);
      await tester.pumpAndSettle();
      expect(await second, 2);
      expect(SuperOverlay.exists(), isFalse);
      await _dispose(tester, integration);
    },
  );

  testWidgets('old run cannot close loading after root replacement', (
    tester,
  ) async {
    final firstIntegration = await _mount(tester, key: const ValueKey('first'));
    final action = Completer<void>();
    final oldRun = SuperOverlay.loading.run(
      () => action.future,
      message: 'old task',
    );
    await tester.pump(const Duration(milliseconds: 300));
    final nextIntegration = await _mount(tester, key: const ValueKey('next'));
    firstIntegration.dispose();
    await tester.pumpAndSettle();
    final next = SuperOverlay.loading.show(message: 'next loading');
    await tester.pump(const Duration(milliseconds: 300));
    action.complete();
    await tester.pump();
    await oldRun;
    expect(next.isVisible, isTrue);
    final close = next.close();
    await tester.pumpAndSettle();
    await close;
    await _dispose(tester, nextIntegration);
  });

  test('loading.run does not start work when no host is installed', () async {
    var started = false;
    await expectLater(
      SuperOverlay.loading.run(() {
        started = true;
        return 42;
      }),
      throwsStateError,
    );
    expect(started, isFalse);
  });
}
