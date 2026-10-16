import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

import 'overlay_test_support.dart';
import 'support/vm_heap.dart';

class _RoutePayload {
  final bytes = List<int>.filled(4096, 1);
}

Future<OverlayHandle<String>> _closedHandleAfterRouteRemoval(
  WidgetTester tester,
  String surface,
  bool cancelBeforeActivation,
  List<WeakReference<_RoutePayload>> references,
) async {
  final payload = _RoutePayload();
  references.add(WeakReference(payload));
  final integration = SuperOverlay.integration();
  final navigatorKey = GlobalKey<NavigatorState>();
  try {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: integration.builder,
        navigatorObservers: [integration.observer],
        home: const Scaffold(),
      ),
    );
    final owner = MaterialPageRoute<void>(
      builder: (_) => Scaffold(body: Text('${payload.bytes.length}')),
    );
    navigatorKey.currentState!.push<void>(owner);
    await tester.pumpAndSettle();
    final handle =
        surface == 'dialog'
            ? SuperOverlay.dialog.show<String>(
              builder: (_, _) => const Text('Independent overlay content'),
              options: const OverlayDialogOptions(
                strategy: OverlayStrategy.replaceExisting,
              ),
            )
            : SuperOverlay.popup.show<String>(
              builder: (_, _) => const Text('Independent overlay content'),
              options: const OverlayPopupOptions(
                strategy: OverlayStrategy.replaceExisting,
                targetPointBuilder: _target,
              ),
            );
    if (cancelBeforeActivation) {
      final visible = expectLater(handle.visible, throwsStateError);
      navigatorKey.currentState!.removeRoute(owner);
      await tester.pumpAndSettle();
      await visible;
    } else {
      await tester.pumpAndSettle();
      final close = handle.close();
      await tester.pumpAndSettle();
      await close;
      navigatorKey.currentState!.removeRoute(owner);
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

class _Harness {
  _Harness(this.scoped)
    : integration = SuperOverlay.integration(),
      navigatorKey = GlobalKey<NavigatorState>();

  final bool scoped;
  final SuperOverlayIntegration integration;
  final GlobalKey<NavigatorState> navigatorKey;
  SuperOverlayNavigatorObserver? nestedObserver;
  late BuildContext firstContext;
  late BuildContext ownerContext;

  NavigatorState get navigator => navigatorKey.currentState!;

  Future<void> mount(WidgetTester tester) async {
    if (scoped) nestedObserver = integration.navigatorObserver();
    Widget firstPage(BuildContext context) {
      firstContext = context;
      return const Scaffold(body: Text('First page'));
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
                      (_) => MaterialPageRoute<void>(builder: firstPage),
                )
                : Builder(builder: firstPage),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      integration.dispose();
    });
  }

  Future<MaterialPageRoute<void>> pushOwner(WidgetTester tester) async {
    final route = MaterialPageRoute<void>(
      builder: (context) {
        ownerContext = context;
        return const Scaffold(body: Text('Owner page'));
      },
    );
    navigator.push<void>(route);
    await tester.pumpAndSettle();
    return route;
  }

  OverlayHandle<String> show(
    String surface,
    String label, {
    OverlayStrategy strategy = OverlayStrategy.replaceExisting,
    bool bindToRoute = true,
    BuildContext? context,
    VoidCallback? onBuild,
  }) {
    final facade = scoped ? SuperOverlay.of(context ?? ownerContext) : null;
    Widget builder(BuildContext context, OverlayHandle<String> handle) {
      onBuild?.call();
      return Text(label);
    }

    if (surface == 'dialog') {
      final options = OverlayDialogOptions(
        tag: 'queued-owner',
        strategy: strategy,
        bindToRoute: bindToRoute,
      );
      return facade?.dialog.show<String>(builder: builder, options: options) ??
          SuperOverlay.dialog.show<String>(builder: builder, options: options);
    }
    final options = OverlayPopupOptions(
      tag: 'queued-owner',
      strategy: strategy,
      bindToRoute: bindToRoute,
      targetPointBuilder: (_, _) => const Offset(200, 200),
    );
    return facade?.popup.show<String>(builder: builder, options: options) ??
        SuperOverlay.popup.show<String>(builder: builder, options: options);
  }

  void detachObserver() {
    if (scoped) {
      nestedObserver!.dispose();
    } else {
      integration.dispose();
    }
  }
}

Future<void> _expectCancelled(
  WidgetTester tester,
  OverlayHandle<String> handle,
  Future<void> rejectedVisible,
) async {
  await tester.pumpAndSettle();
  await rejectedVisible;
  // Intentionally first observe closed after cancellation. Disposal must not
  // produce an unhandled asynchronous error when no close observer is present.
  expect(await handle.closed, isNull);
  expect(handle.closed, same(handle.closed));
  expect(handle.isVisible, isFalse);
  handle.refresh();
  await handle.close('late result');
  expect(await handle.closed, isNull);
  expect(tester.takeException(), isNull);
}

void main() {
  setUp(() {
    final custom = overlayConfig.custom;
    final attach = overlayConfig.attach;
    addTearDown(() {
      overlayConfig.custom = custom;
      overlayConfig.attach = attach;
    });
    // Make replacement waiting observable, independently of route transitions.
    overlayConfig.custom = const CustomDialogConfig(
      animationTime: Duration(milliseconds: 300),
      nonAnimationTypes: [],
    );
    overlayConfig.attach = const AttachDialogConfig(
      animationTime: Duration(milliseconds: 300),
      nonAnimationTypes: [],
    );
  });

  for (final surface in ['dialog', 'popup']) {
    for (final cancelled in [false, true]) {
      testWidgets(
        '$surface retained handle releases route, cancelled=$cancelled',
        (tester) async {
          final references = <WeakReference<_RoutePayload>>[];
          final handle = await _closedHandleAfterRouteRemoval(
            tester,
            surface,
            cancelled,
            references,
          );
          await tester.runAsync(collectHeapCounts);
          expect(references.single.target, isNull);
          expect(handle.isVisible, isFalse);
          expect(await handle.closed, isNull);
        },
      );
    }
    for (final scoped in [false, true]) {
      final name = '$surface ${scoped ? 'scoped' : 'root'}';
      testWidgets('$name cancels before replacement without closing a match', (
        tester,
      ) async {
        final harness = _Harness(scoped);
        await harness.mount(tester);
        final previous = harness.show(
          surface,
          'Previous survives',
          strategy: OverlayStrategy.stack,
          bindToRoute: false,
          context: harness.firstContext,
        );
        await tester.pumpAndSettle();
        final owner = await harness.pushOwner(tester);
        var builds = 0;
        final pending = harness.show(
          surface,
          'Cancelled content',
          onBuild: () => builds++,
        );
        final visible = expectLater(pending.visible, throwsStateError);
        harness.navigator.removeRoute(owner);
        await _expectCancelled(tester, pending, visible);
        expect(builds, 0);
        expect(previous.isVisible, isTrue);
        expect(find.text('Previous survives'), findsOneWidget);
        final close = previous.close('preserved');
        await tester.pumpAndSettle();
        await close;
        expect(await previous.closed, 'preserved');
      });

      for (final removeObserver in [false, true]) {
        testWidgets(
          '$name cancels during close animation, observer=$removeObserver',
          (tester) async {
            final harness = _Harness(scoped);
            await harness.mount(tester);
            final previous = harness.show(
              surface,
              'Closing original',
              strategy: OverlayStrategy.stack,
              bindToRoute: false,
              context: harness.firstContext,
            );
            await tester.pumpAndSettle();
            var originalClosed = false;
            previous.closed.then((_) => originalClosed = true);
            final owner = await harness.pushOwner(tester);
            var builds = 0;
            final pending = harness.show(
              surface,
              'Never rendered replacement',
              onBuild: () => builds++,
            );
            final visible = expectLater(pending.visible, throwsStateError);
            await tester.pump();
            expect(originalClosed, isFalse);
            if (removeObserver) {
              harness.detachObserver();
            } else {
              harness.navigator.removeRoute(owner);
            }
            await _expectCancelled(tester, pending, visible);
            expect(originalClosed, isTrue);
            expect(builds, 0);
            if (!removeObserver) {
              final next = harness.show(
                surface,
                'Queue recovered',
                context: harness.firstContext,
              );
              await tester.pumpAndSettle();
              await next.visible;
              expect(next.isVisible, isTrue);
              final close = next.close('next result');
              await tester.pumpAndSettle();
              await close;
              expect(await next.closed, 'next result');
            }
          },
        );
      }

      testWidgets(
        '$name removed owner behind a queued winner cannot replace it',
        (tester) async {
          final harness = _Harness(scoped);
          await harness.mount(tester);
          harness.show(
            surface,
            'Original queue item',
            strategy: OverlayStrategy.stack,
            bindToRoute: false,
            context: harness.firstContext,
          );
          await tester.pumpAndSettle();
          final owner = await harness.pushOwner(tester);
          final winner = harness.show(
            surface,
            'Current queue winner',
            bindToRoute: false,
            context: harness.firstContext,
          );
          var builds = 0;
          final cancelled = harness.show(
            surface,
            'Removed queue successor',
            onBuild: () => builds++,
          );
          final visible = expectLater(cancelled.visible, throwsStateError);
          await tester.pump();
          harness.navigator.removeRoute(owner);
          await _expectCancelled(tester, cancelled, visible);
          await winner.visible;
          expect(winner.isVisible, isTrue);
          expect(builds, 0);
          expect(find.text('Current queue winner'), findsOneWidget);
        },
      );

      testWidgets('$name observer removed before queue activation cancels', (
        tester,
      ) async {
        final harness = _Harness(scoped);
        await harness.mount(tester);
        await harness.pushOwner(tester);
        final pending = harness.show(surface, 'Detached observer command');
        final visible = expectLater(pending.visible, throwsStateError);
        harness.detachObserver();
        await _expectCancelled(tester, pending, visible);
        expect(find.text('Detached observer command'), findsNothing);
      });

      testWidgets('$name covered owner still activates and resumes normally', (
        tester,
      ) async {
        final harness = _Harness(scoped);
        await harness.mount(tester);
        await harness.pushOwner(tester);
        final pending = harness.show(surface, 'Suspended replacement');
        var rendered = false;
        pending.visible.then((_) => rendered = true);
        harness.navigator.push<void>(
          MaterialPageRoute<void>(builder: (_) => const Scaffold()),
        );
        await tester.pumpAndSettle();
        expect(rendered, isFalse);
        expect(pending.isVisible, isFalse);
        harness.navigator.pop();
        await tester.pumpAndSettle();
        await pending.visible;
        expect(pending.isVisible, isTrue);
        final close = pending.close('resumed');
        await tester.pumpAndSettle();
        await close;
        expect(await pending.closed, 'resumed');
      });

      testWidgets('$name host teardown before activation cancels harmlessly', (
        tester,
      ) async {
        final harness = _Harness(scoped);
        await harness.mount(tester);
        await harness.pushOwner(tester);
        final pending = harness.show(surface, 'Retired host command');
        final visible = expectLater(pending.visible, throwsStateError);
        await tester.pumpWidget(const SizedBox.shrink());
        await _expectCancelled(tester, pending, visible);
        expect(find.text('Retired host command'), findsNothing);
      });

      testWidgets('$name stale facade still fails synchronously at show', (
        tester,
      ) async {
        final harness = _Harness(scoped);
        await harness.mount(tester);
        final owner = await harness.pushOwner(tester);
        final facade = SuperOverlay.of(harness.ownerContext);
        harness.navigator.removeRoute(owner);
        await tester.pumpAndSettle();
        expect(
          () =>
              surface == 'dialog'
                  ? facade.dialog.show<void>(
                    builder: (_, _) => const Text('Invalid call'),
                    options: const OverlayDialogOptions(
                      strategy: OverlayStrategy.replaceExisting,
                    ),
                  )
                  : facade.popup.show<void>(
                    builder: (_, _) => const Text('Invalid call'),
                    options: const OverlayPopupOptions(
                      strategy: OverlayStrategy.replaceExisting,
                      targetPointBuilder: _target,
                    ),
                  ),
          throwsStateError,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Offset _target(Offset target, Size overlay) => const Offset(200, 200);
