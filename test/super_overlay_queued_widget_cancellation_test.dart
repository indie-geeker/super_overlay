import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

import 'overlay_test_support.dart';
import 'support/vm_heap.dart';

class _Harness {
  _Harness(this.scoped, this.surface);

  final bool scoped;
  final String surface;
  final integration = SuperOverlay.integration();
  final navigatorKey = GlobalKey<NavigatorState>();
  final targetKey = GlobalKey();
  late StateSetter update;
  late BuildContext pageContext;
  late BuildContext targetContext;
  bool hasTarget = true;
  double targetSize = 40;

  Future<void> mount(WidgetTester tester) async {
    final nestedObserver = scoped ? integration.navigatorObserver() : null;
    Widget page(BuildContext context) {
      pageContext = context;
      return Scaffold(
        body: Center(
          child: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return hasTarget
                  ? Builder(
                    key: targetKey,
                    builder: (context) {
                      targetContext = context;
                      return SizedBox(width: targetSize, height: targetSize);
                    },
                  )
                  : const SizedBox.shrink();
            },
          ),
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: scoped ? null : navigatorKey,
        builder: integration.builder,
        navigatorObservers: [integration.observer],
        home:
            scoped
                ? Navigator(
                  key: navigatorKey,
                  observers: [nestedObserver!],
                  onGenerateRoute:
                      (_) => MaterialPageRoute<void>(builder: page),
                )
                : Builder(builder: page),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      integration.dispose();
    });
  }

  OverlayHandle<String> show(
    String label, {
    OverlayStrategy strategy = OverlayStrategy.replaceExisting,
    bool bindWidget = true,
    bool bindRoute = true,
    VoidCallback? onBuild,
  }) {
    Widget content(BuildContext context, OverlayHandle<String> handle) {
      onBuild?.call();
      return Text(label);
    }

    if (surface == 'popup') {
      final options = OverlayPopupOptions(
        tag: 'queued-widget',
        strategy: strategy,
        bindToRoute: bindRoute,
        targetPointBuilder:
            bindWidget ? null : (_, _) => const Offset(200, 200),
      );
      final owner = bindWidget ? targetContext : null;
      return scoped
          ? SuperOverlay.of(pageContext).popup.show<String>(
            targetContext: owner,
            builder: content,
            options: options,
          )
          : SuperOverlay.popup.show<String>(
            targetContext: owner,
            builder: content,
            options: options,
          );
    }
    final options = OverlayDialogOptions(
      tag: 'queued-widget',
      strategy: strategy,
      bindToRoute: bindRoute,
      bindToWidget: bindWidget ? targetContext : null,
    );
    if (scoped) {
      return SuperOverlay.of(
        pageContext,
      ).dialog.show<String>(builder: content, options: options);
    }
    return SuperOverlay.dialog.show<String>(builder: content, options: options);
  }

  Future<void> removeTarget(WidgetTester tester) async {
    update(() => hasTarget = false);
    await tester.pump();
    expect(targetContext.mounted, isFalse);
  }
}

Future<void> _expectCancelled(
  WidgetTester tester,
  OverlayHandle<String> handle,
  Future<void> visible, {
  String? result,
}) async {
  await tester.pumpAndSettle();
  // The pre-fix control may start a target-failure close in a post-frame
  // callback after animations have stopped scheduling frames.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await visible;
  expect(await handle.closed, result);
  expect(handle.closed, same(handle.closed));
  expect(handle.isVisible, isFalse);
  handle.refresh();
  await handle.close('late result');
  expect(await handle.closed, result);
  expect(tester.takeException(), isNull);
}

class _OwnerPayload {
  final bytes = List<int>.filled(4096, 1);
}

class _PayloadOwner extends StatelessWidget {
  const _PayloadOwner({required this.payload, super.key});

  final _OwnerPayload payload;

  @override
  Widget build(BuildContext context) => const SizedBox(width: 40, height: 40);
}

Future<OverlayHandle<String>> _retainedClosedHandle(
  WidgetTester tester,
  bool cancel,
  String surface,
  List<WeakReference<_OwnerPayload>> references,
) async {
  final payload = _OwnerPayload();
  references.add(WeakReference(payload));
  final integration = SuperOverlay.integration();
  final key = GlobalKey();
  late StateSetter update;
  var hasOwner = true;
  try {
    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: [integration.observer],
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return hasOwner
                  ? _PayloadOwner(key: key, payload: payload)
                  : const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    if (cancel) {
      if (surface == 'popup') {
        SuperOverlay.popup.show<void>(
          builder: (_, _) => const Text('Replacement predecessor'),
          options: OverlayPopupOptions(
            tag: 'retained-widget',
            targetPointBuilder: (_, _) => const Offset(200, 200),
          ),
        );
      } else {
        SuperOverlay.dialog.show<void>(
          builder: (_, _) => const Text('Replacement predecessor'),
          options: const OverlayDialogOptions(tag: 'retained-widget'),
        );
      }
      await tester.pumpAndSettle();
    }
    final handle =
        surface == 'popup'
            ? SuperOverlay.popup.show<String>(
              targetContext: key.currentContext!,
              builder: (_, _) => const Text('Independent popup content'),
              options: const OverlayPopupOptions(
                tag: 'retained-widget',
                strategy: OverlayStrategy.replaceExisting,
              ),
            )
            : SuperOverlay.dialog.show<String>(
              builder: (_, _) => const Text('Independent dialog content'),
              options: OverlayDialogOptions(
                tag: 'retained-widget',
                strategy: OverlayStrategy.replaceExisting,
                bindToWidget: key.currentContext!,
              ),
            );
    if (cancel) {
      final rejected = expectLater(handle.visible, throwsStateError);
      await tester.pump();
      update(() => hasOwner = false);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await rejected;
    } else {
      await tester.pumpAndSettle();
      await handle.visible;
      final closing = handle.close('saved result');
      await tester.pumpAndSettle();
      await closing;
      update(() => hasOwner = false);
      await tester.pumpAndSettle();
    }
    await handle.closed;
    return handle;
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  }
}

void main() {
  setUp(() {
    final original = overlayConfig.custom;
    final attach = overlayConfig.attach;
    addTearDown(() {
      overlayConfig.custom = original;
      overlayConfig.attach = attach;
    });
    overlayConfig.attach = const AttachDialogConfig(
      animationTime: Duration(milliseconds: 300),
      nonAnimationTypes: [],
    );
    overlayConfig.custom = const CustomDialogConfig(
      animationTime: Duration(milliseconds: 300),
      nonAnimationTypes: [],
    );
  });

  for (final surface in ['dialog', 'popup']) {
    for (final scoped in [false, true]) {
      final prefix = '$surface ${scoped ? 'scoped' : 'root'}';
      testWidgets('$prefix queued valid widget owner activates normally', (
        tester,
      ) async {
        final harness = _Harness(scoped, surface);
        await harness.mount(tester);
        final previous = harness.show(
          'Previous',
          strategy: OverlayStrategy.stack,
          bindWidget: false,
        );
        await tester.pumpAndSettle();
        var builds = 0;
        final next = harness.show('Valid widget', onBuild: () => builds++);
        await tester.pumpAndSettle();
        await next.visible;
        expect(builds, greaterThanOrEqualTo(1));
        expect(next.isVisible, isTrue);
        expect(await previous.closed, isNull);
        final close = next.close('valid result');
        await tester.pumpAndSettle();
        await close;
        expect(await next.closed, 'valid result');
      });

      for (final strategy in [
        OverlayStrategy.stack,
        OverlayStrategy.replaceExisting,
      ]) {
        testWidgets('$prefix initially unmounted widget cancels $strategy', (
          tester,
        ) async {
          final harness = _Harness(scoped, surface);
          await harness.mount(tester);
          final previous = harness.show(
            'Preserved previous',
            strategy: OverlayStrategy.stack,
            bindWidget: false,
          );
          await tester.pumpAndSettle();
          await harness.removeTarget(tester);
          var builds = 0;
          final cancelled = harness.show(
            'Never build stale content',
            strategy: strategy,
            onBuild: () => builds++,
          );
          final visible = expectLater(cancelled.visible, throwsStateError);
          await _expectCancelled(tester, cancelled, visible);
          expect(builds, 0);
          expect(previous.isVisible, isTrue);
        });
      }

      for (final bindRoute in [false, true]) {
        testWidgets(
          '$prefix widget removal during replacement cancels, route=$bindRoute',
          (tester) async {
            final harness = _Harness(scoped, surface);
            await harness.mount(tester);
            final previous = harness.show(
              'Closing previous',
              strategy: OverlayStrategy.stack,
              bindWidget: false,
            );
            await tester.pumpAndSettle();
            var builds = 0;
            final cancelled = harness.show(
              'Removed widget owner',
              bindRoute: bindRoute,
              onBuild: () => builds++,
            );
            final visible = expectLater(cancelled.visible, throwsStateError);
            await tester.pump();
            await harness.removeTarget(tester);
            await _expectCancelled(tester, cancelled, visible);
            expect(builds, 0);
            expect(await previous.closed, isNull);
            harness.update(() => harness.hasTarget = true);
            await tester.pump();
            final recovered = harness.show('Queue recovered');
            await tester.pumpAndSettle();
            await recovered.visible;
            expect(recovered.isVisible, isTrue);
          },
        );
      }

      testWidgets(
        '$prefix removed queued owner cannot dismiss a queue winner',
        (tester) async {
          final harness = _Harness(scoped, surface);
          await harness.mount(tester);
          harness.show(
            'Original',
            strategy: OverlayStrategy.stack,
            bindWidget: false,
          );
          await tester.pumpAndSettle();
          final winner = harness.show('Winner', bindWidget: false);
          var builds = 0;
          final cancelled = harness.show(
            'Removed successor',
            onBuild: () => builds++,
          );
          final visible = expectLater(cancelled.visible, throwsStateError);
          await tester.pump();
          await harness.removeTarget(tester);
          await _expectCancelled(tester, cancelled, visible);
          await winner.visible;
          expect(builds, 0);
          expect(winner.isVisible, isTrue);
          expect(find.text('Winner'), findsOneWidget);
        },
      );

      testWidgets(
        '$prefix first queued close result survives owner cancellation',
        (tester) async {
          final harness = _Harness(scoped, surface);
          await harness.mount(tester);
          harness.show(
            'Original',
            strategy: OverlayStrategy.stack,
            bindWidget: false,
          );
          await tester.pumpAndSettle();
          final cancelled = harness.show('Cancelled result');
          final visible = expectLater(cancelled.visible, throwsStateError);
          await tester.pump();
          final closing = cancelled.close('first result');
          expect(cancelled.close('second result'), same(closing));
          await harness.removeTarget(tester);
          await _expectCancelled(
            tester,
            cancelled,
            visible,
            result: 'first result',
          );
          await closing;
        },
      );

      testWidgets(
        '$prefix first queued close result wins with a mounted owner',
        (tester) async {
          final harness = _Harness(scoped, surface);
          await harness.mount(tester);
          harness.show(
            'Original',
            strategy: OverlayStrategy.stack,
            bindWidget: false,
          );
          await tester.pumpAndSettle();
          var builds = 0;
          final cancelled = harness.show(
            'Explicit cancellation',
            onBuild: () => builds++,
          );
          final visible = expectLater(cancelled.visible, throwsStateError);
          await tester.pump();
          final closing = cancelled.close('first result');
          expect(cancelled.close('second result'), same(closing));
          expect(harness.targetContext.mounted, isTrue);
          await _expectCancelled(
            tester,
            cancelled,
            visible,
            result: 'first result',
          );
          await closing;
          expect(builds, 0);
        },
      );

      testWidgets('$prefix covered mounted widget remains a valid owner', (
        tester,
      ) async {
        final harness = _Harness(scoped, surface);
        await harness.mount(tester);
        final pending = harness.show('Covered widget');
        var visible = false;
        pending.visible.then((_) => visible = true);
        harness.navigatorKey.currentState!.push<void>(
          MaterialPageRoute<void>(builder: (_) => const Scaffold()),
        );
        await tester.pumpAndSettle();
        expect(harness.targetContext.mounted, isTrue);
        expect(visible, isFalse);
        harness.navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        await pending.visible;
        expect(pending.isVisible, isTrue);
      });

      if (surface == 'dialog') {
        testWidgets(
          '$prefix mounted zero-size owner is not terminal cancellation',
          (tester) async {
            final harness = _Harness(scoped, surface);
            await harness.mount(tester);
            harness.update(() => harness.targetSize = 0);
            await tester.pump();
            final pending = harness.show('Geometry is not unmount');
            var closed = false;
            pending.closed.then((_) => closed = true);
            await tester.pumpAndSettle();
            expect(harness.targetContext.mounted, isTrue);
            expect(closed, isFalse);
            harness.update(() => harness.targetSize = 40);
            await tester.pumpAndSettle();
            await pending.visible;
            expect(pending.isVisible, isTrue);
          },
        );
      } else {
        testWidgets(
          '$prefix mounted invalid target retains geometry cancellation',
          (tester) async {
            final harness = _Harness(scoped, surface);
            await harness.mount(tester);
            harness.update(() => harness.targetSize = 0);
            await tester.pump();
            final pending = harness.show('Invalid mounted geometry');
            final visible = expectLater(pending.visible, throwsStateError);
            expect(harness.targetContext.mounted, isTrue);
            await tester.pumpAndSettle();
            await tester.pump(const Duration(seconds: 1));
            await _expectCancelled(tester, pending, visible);
          },
        );
      }
      for (final retireHost in [false, true]) {
        testWidgets(
          '$prefix cleanup and removed queued owner settle, host=$retireHost',
          (tester) async {
            final harness = _Harness(scoped, surface);
            await harness.mount(tester);
            harness.show(
              'Original',
              strategy: OverlayStrategy.stack,
              bindWidget: false,
            );
            await tester.pumpAndSettle();
            var builds = 0;
            final cancelled = harness.show(
              'Never shown',
              onBuild: () => builds++,
            );
            final visible = expectLater(cancelled.visible, throwsStateError);
            await tester.pump();
            if (retireHost) {
              await tester.pumpWidget(const SizedBox.shrink());
            } else {
              final cleanup = SuperOverlay.close(
                target: OverlayCloseTarget.all,
              );
              await harness.removeTarget(tester);
              await tester.pumpAndSettle();
              await cleanup;
            }
            await _expectCancelled(tester, cancelled, visible);
            expect(builds, 0);
            if (retireHost) {
              // Teardown settles both commands immediately. Drain the disposed
              // predecessor's already-started animation delay before test exit.
              await tester.pump(const Duration(seconds: 1));
            }
          },
        );
      }
    }

    for (final cancel in [false, true]) {
      testWidgets(
        '$surface retained handle releases widget payload, cancelled=$cancel',
        (tester) async {
          final references = <WeakReference<_OwnerPayload>>[];
          final handle = await _retainedClosedHandle(
            tester,
            cancel,
            surface,
            references,
          );
          await tester.runAsync(collectHeapCounts);
          expect(references.single.target, isNull);
          expect(handle.isVisible, isFalse);
          expect(await handle.closed, cancel ? null : 'saved result');
        },
      );
    }
  }
}
