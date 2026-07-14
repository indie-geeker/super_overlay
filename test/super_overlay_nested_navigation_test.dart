import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';
import 'package:super_overlay/src/helper/navigator_scope_registry.dart';

class _NestedHarness {
  _NestedHarness({
    required this.integration,
    required this.nestedObserver,
    required this.navigatorKey,
    required this.nestedContext,
    required this.rootRoute,
  });

  final SuperOverlayIntegration integration;
  final SuperOverlayNavigatorObserver? nestedObserver;
  final GlobalKey<NavigatorState> navigatorKey;
  final BuildContext nestedContext;
  final ModalRoute<Object?> rootRoute;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  }
}

Future<_NestedHarness> _pumpNestedApp(
  WidgetTester tester, {
  bool installNestedObserver = true,
}) async {
  final integration = SuperOverlay.integration();
  final nestedObserver =
      installNestedObserver ? integration.navigatorObserver() : null;
  final navigatorKey = GlobalKey<NavigatorState>();
  late BuildContext nestedContext;
  late ModalRoute<Object?> rootRoute;

  await tester.pumpWidget(
    MaterialApp(
      builder: integration.builder,
      navigatorObservers: <NavigatorObserver>[integration.observer],
      home: Builder(
        builder: (context) {
          rootRoute = ModalRoute.of<Object?>(context)!;
          return Scaffold(
            body: Navigator(
              key: navigatorKey,
              observers: <NavigatorObserver>[
                if (nestedObserver != null) nestedObserver,
              ],
              onGenerateRoute:
                  (_) => MaterialPageRoute<void>(
                    builder:
                        (context) => Builder(
                          builder: (context) {
                            nestedContext = context;
                            return const Scaffold(
                              body: Text('Nested first page'),
                            );
                          },
                        ),
                  ),
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();

  return _NestedHarness(
    integration: integration,
    nestedObserver: nestedObserver,
    navigatorKey: navigatorKey,
    nestedContext: nestedContext,
    rootRoute: rootRoute,
  );
}

void main() {
  testWidgets('root static dialog called from nested page stays root-bound', (
    tester,
  ) async {
    final harness = await _pumpNestedApp(tester);
    final handle = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Root-bound dialog'),
    );
    await tester.pumpAndSettle();

    harness.navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Nested second page')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nested second page'), findsOneWidget);
    expect(find.text('Root-bound dialog'), findsOneWidget);
    expect(handle.isVisible, isTrue);

    await handle.close();
    await tester.pumpAndSettle();
    await harness.dispose(tester);
  });

  testWidgets('scoped nested dialog suspends on push and resumes on pop', (
    tester,
  ) async {
    final harness = await _pumpNestedApp(tester);
    final handle = SuperOverlay.of(
      harness.nestedContext,
    ).dialog.show<void>(builder: (_) => const Text('Scoped nested dialog'));
    await tester.pumpAndSettle();
    await handle.visible;

    expect(find.text('Scoped nested dialog'), findsOneWidget);
    expect(handle.isVisible, isTrue);

    harness.navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Nested covering page')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nested covering page'), findsOneWidget);
    expect(find.text('Scoped nested dialog'), findsNothing);
    expect(handle.isVisible, isFalse);

    harness.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.text('Scoped nested dialog'), findsOneWidget);
    expect(handle.isVisible, isTrue);

    await handle.close();
    await tester.pumpAndSettle();
    await harness.dispose(tester);
  });

  testWidgets('removing a nested owner route closes its scoped dialog', (
    tester,
  ) async {
    final harness = await _pumpNestedApp(tester);
    late BuildContext ownerContext;
    final ownerRoute = MaterialPageRoute<void>(
      builder:
          (context) => Builder(
            builder: (context) {
              ownerContext = context;
              return const Scaffold(body: Text('Nested removable page'));
            },
          ),
    );
    harness.navigatorKey.currentState!.push<void>(ownerRoute);
    await tester.pumpAndSettle();

    final handle = SuperOverlay.of(
      ownerContext,
    ).dialog.show<void>(builder: (_) => const Text('Removed scoped dialog'));
    await tester.pumpAndSettle();

    harness.navigatorKey.currentState!.removeRoute(ownerRoute);
    await tester.pumpAndSettle();
    await handle.closed;

    expect(find.text('Removed scoped dialog'), findsNothing);
    expect(handle.isVisible, isFalse);
    await harness.dispose(tester);
  });

  testWidgets('missing nested observer fails synchronously', (tester) async {
    final harness = await _pumpNestedApp(tester, installNestedObserver: false);

    expect(
      () => SuperOverlay.of(harness.nestedContext),
      throwsA(isA<StateError>()),
    );

    await harness.dispose(tester);
  });

  testWidgets('sibling Navigator route events do not affect scoped owner', (
    tester,
  ) async {
    final integration = SuperOverlay.integration();
    final observerA = integration.navigatorObserver();
    final observerB = integration.navigatorObserver();
    final navigatorA = GlobalKey<NavigatorState>();
    final navigatorB = GlobalKey<NavigatorState>();
    late BuildContext contextA;
    late ModalRoute<Object?> routeB;

    Widget branch(
      String name,
      GlobalKey<NavigatorState> key,
      SuperOverlayNavigatorObserver observer,
      void Function(BuildContext) capture,
    ) {
      return Expanded(
        child: Navigator(
          key: key,
          observers: <NavigatorObserver>[observer],
          onGenerateRoute:
              (_) => MaterialPageRoute<void>(
                builder:
                    (context) => Builder(
                      builder: (context) {
                        capture(context);
                        return Scaffold(body: Text('$name first page'));
                      },
                    ),
              ),
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: <NavigatorObserver>[integration.observer],
        home: Row(
          children: <Widget>[
            branch('A', navigatorA, observerA, (context) => contextA = context),
            branch('B', navigatorB, observerB, (_) {}),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final handle = SuperOverlay.of(
      contextA,
    ).dialog.show<void>(builder: (_) => const Text('A scoped dialog'));
    await tester.pumpAndSettle();

    navigatorB.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder:
            (context) => Builder(
              builder: (context) {
                routeB = ModalRoute.of<Object?>(context)!;
                return const Scaffold(body: Text('B second page'));
              },
            ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A scoped dialog'), findsOneWidget);
    expect(handle.isVisible, isTrue);
    expect(routeB.popDisposition, RoutePopDisposition.doNotPop);

    navigatorA.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('A second page')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A scoped dialog'), findsNothing);
    expect(handle.isVisible, isFalse);
    expect(routeB.popDisposition, isNot(RoutePopDisposition.doNotPop));

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  });

  testWidgets('bindToRoute false remains visible across nested push', (
    tester,
  ) async {
    final harness = await _pumpNestedApp(tester);
    final handle = SuperOverlay.of(harness.nestedContext).dialog.show<void>(
      builder: (_) => const Text('Unbound scoped dialog'),
      options: const OverlayDialogOptions(bindToRoute: false),
    );
    await tester.pumpAndSettle();

    harness.navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Nested pushed page')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unbound scoped dialog'), findsOneWidget);
    expect(handle.isVisible, isTrue);

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    await harness.dispose(tester);
  });

  testWidgets(
    'push before first rendered frame suspends without building or completing visible',
    (tester) async {
      final harness = await _pumpNestedApp(tester);
      var builds = 0;
      var visibleCompleted = false;
      final handle = SuperOverlay.of(harness.nestedContext).dialog.show<void>(
        builder: (_) {
          builds++;
          return const Text('Deferred scoped dialog');
        },
      );
      handle.visible.then((_) => visibleCompleted = true);

      harness.navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Immediate covering page')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(builds, 0);
      expect(visibleCompleted, isFalse);
      expect(find.text('Deferred scoped dialog'), findsNothing);
      expect(handle.isVisible, isFalse);

      harness.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await handle.visible;

      expect(builds, greaterThan(0));
      expect(visibleCompleted, isTrue);
      expect(find.text('Deferred scoped dialog'), findsOneWidget);

      final close = handle.close();
      await tester.pumpAndSettle();
      await close;
      await harness.dispose(tester);
    },
  );

  testWidgets('closing while suspended before first frame fails visible once', (
    tester,
  ) async {
    final harness = await _pumpNestedApp(tester);
    final handle = SuperOverlay.of(harness.nestedContext).dialog.show<void>(
      builder: (_) => const Text('Never rendered scoped dialog'),
    );
    Object? visibleError;
    var closedCount = 0;
    handle.visible.then<void>(
      (_) {},
      onError: (Object error, StackTrace _) => visibleError = error,
    );
    handle.closed.then((_) => closedCount++);

    harness.navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Cover before render')),
      ),
    );
    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    await handle.closed;

    expect(visibleError, isA<StateError>());
    expect(closedCount, 1);
    expect(find.text('Never rendered scoped dialog'), findsNothing);
    await harness.dispose(tester);
  });

  testWidgets('suspended scoped dialog does not veto covering route back', (
    tester,
  ) async {
    final harness = await _pumpNestedApp(tester);
    late ModalRoute<Object?> coveringRoute;
    final handle = SuperOverlay.of(
      harness.nestedContext,
    ).dialog.show<void>(builder: (_) => const Text('Suspended back dialog'));
    await tester.pumpAndSettle();

    harness.navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder:
            (context) => Builder(
              builder: (context) {
                coveringRoute = ModalRoute.of<Object?>(context)!;
                return const Scaffold(body: Text('Back-capable covering page'));
              },
            ),
      ),
    );
    await tester.pumpAndSettle();

    expect(coveringRoute.popDisposition, isNot(RoutePopDisposition.doNotPop));
    expect(
      harness.rootRoute.popDisposition,
      isNot(RoutePopDisposition.doNotPop),
    );
    expect(handle.isVisible, isFalse);

    harness.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    await harness.dispose(tester);
  });

  testWidgets('replacement keeps owner captured before awaiting close', (
    tester,
  ) async {
    final harness = await _pumpNestedApp(tester);
    final scoped = SuperOverlay.of(harness.nestedContext);
    final first = scoped.dialog.show<void>(
      builder: (_) => const Text('First replaceable dialog'),
      options: const OverlayDialogOptions(tag: 'scoped-replacement'),
    );
    await tester.pumpAndSettle();

    final replacement = scoped.dialog.show<void>(
      builder: (_) => const Text('Replacement scoped dialog'),
      options: const OverlayDialogOptions(
        tag: 'scoped-replacement',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );
    harness.navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Replacement covering page')),
      ),
    );
    await tester.pumpAndSettle();
    await first.closed;

    expect(find.text('Replacement scoped dialog'), findsNothing);
    expect(replacement.isVisible, isFalse);

    harness.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await replacement.visible;

    expect(find.text('Replacement scoped dialog'), findsOneWidget);
    final close = replacement.close();
    await tester.pumpAndSettle();
    await close;
    await harness.dispose(tester);
  });

  testWidgets('removal before first frame fails visible and closes once', (
    tester,
  ) async {
    final harness = await _pumpNestedApp(tester);
    late BuildContext ownerContext;
    final ownerRoute = MaterialPageRoute<void>(
      builder:
          (context) => Builder(
            builder: (context) {
              ownerContext = context;
              return const Scaffold(body: Text('Immediate removable page'));
            },
          ),
    );
    harness.navigatorKey.currentState!.push<void>(ownerRoute);
    await tester.pumpAndSettle();

    final handle = SuperOverlay.of(
      ownerContext,
    ).dialog.show<void>(builder: (_) => const Text('Immediate removed dialog'));
    Object? visibleError;
    var closedCount = 0;
    handle.visible.then<void>(
      (_) {},
      onError: (Object error, StackTrace _) => visibleError = error,
    );
    handle.closed.then((_) => closedCount++);
    harness.navigatorKey.currentState!.removeRoute(ownerRoute);
    await tester.pumpAndSettle();
    await handle.closed;

    expect(visibleError, isA<StateError>());
    expect(closedCount, 1);
    expect(handle.isVisible, isFalse);
    await harness.dispose(tester);
  });

  testWidgets('scoped observer dispose is idempotent and closes its overlays', (
    tester,
  ) async {
    final harness = await _pumpNestedApp(tester);
    final observer = harness.nestedObserver!;
    final handle = SuperOverlay.of(
      harness.nestedContext,
    ).dialog.show<void>(builder: (_) => const Text('Observer-owned dialog'));
    await tester.pumpAndSettle();

    observer.dispose();
    observer.dispose();
    await tester.pumpAndSettle();
    await handle.closed;

    expect(find.text('Observer-owned dialog'), findsNothing);
    expect(
      () => SuperOverlay.of(harness.nestedContext),
      throwsA(isA<StateError>()),
    );
    await harness.dispose(tester);
  });

  testWidgets('shell chrome context resolves root route instead of a branch', (
    tester,
  ) async {
    final integration = SuperOverlay.integration();
    final nestedObserver = integration.navigatorObserver();
    final nestedKey = GlobalKey<NavigatorState>();
    late BuildContext shellContext;

    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: <NavigatorObserver>[integration.observer],
        home: Builder(
          builder: (context) {
            shellContext = context;
            return Scaffold(
              body: Navigator(
                key: nestedKey,
                observers: <NavigatorObserver>[nestedObserver],
                onGenerateRoute:
                    (_) => MaterialPageRoute<void>(
                      builder:
                          (_) => const Scaffold(body: Text('Shell branch')),
                    ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final handle = SuperOverlay.of(
      shellContext,
    ).dialog.show<void>(builder: (_) => const Text('Shell root dialog'));
    await tester.pumpAndSettle();
    nestedKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Shell branch second')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shell root dialog'), findsOneWidget);
    expect(handle.isVisible, isTrue);

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  });

  testWidgets('detached scoped Navigator closes overlays after frame grace', (
    tester,
  ) async {
    final initialScopeCount =
        NavigatorScopeRegistry.instance.debugRegisteredScopeCount;
    final integration = SuperOverlay.integration();
    final scopedObserver = integration.navigatorObserver();
    late StateSetter updateHost;
    late BuildContext nestedContext;
    var showNested = true;

    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: <NavigatorObserver>[integration.observer],
        home: StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            if (!showNested) {
              return const Scaffold(body: Text('Nested detached'));
            }
            return Navigator(
              observers: <NavigatorObserver>[scopedObserver],
              onGenerateRoute:
                  (_) => MaterialPageRoute<void>(
                    builder:
                        (context) => Builder(
                          builder: (context) {
                            nestedContext = context;
                            return const Scaffold(
                              body: Text('Detach owner page'),
                            );
                          },
                        ),
                  ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final handle = SuperOverlay.of(
      nestedContext,
    ).dialog.show<void>(builder: (_) => const Text('Detached owner dialog'));
    await tester.pumpAndSettle();
    var closed = false;
    handle.closed.then((_) => closed = true);

    updateHost(() => showNested = false);
    await tester.pump();
    expect(closed, isFalse);
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(find.text('Detached owner dialog'), findsNothing);
    expect(
      NavigatorScopeRegistry.instance.debugTrackedRouteCount,
      lessThanOrEqualTo(1),
    );
    expect(
      NavigatorScopeRegistry.instance.debugRegisteredScopeCount,
      initialScopeCount + 1,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  });

  testWidgets('idle detached scoped Navigator is pruned after route lookup', (
    tester,
  ) async {
    final initialScopeCount =
        NavigatorScopeRegistry.instance.debugRegisteredScopeCount;
    final integration = SuperOverlay.integration();
    final scopedObserver = integration.navigatorObserver();
    late StateSetter updateHost;
    late BuildContext rootContext;
    var showNested = true;

    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: <NavigatorObserver>[integration.observer],
        home: StatefulBuilder(
          builder: (context, setState) {
            rootContext = context;
            updateHost = setState;
            if (!showNested) {
              return const Scaffold(body: Text('Idle nested detached'));
            }
            return Navigator(
              observers: <NavigatorObserver>[scopedObserver],
              onGenerateRoute:
                  (_) => MaterialPageRoute<void>(
                    builder:
                        (_) => const Scaffold(
                          body: Text('Idle nested owner page'),
                        ),
                  ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      NavigatorScopeRegistry.instance.debugRegisteredScopeCount,
      initialScopeCount + 2,
    );

    updateHost(() => showNested = false);
    await tester.pump();
    expect(
      NavigatorScopeRegistry.instance.debugRegisteredScopeCount,
      initialScopeCount + 2,
    );

    expect(() => SuperOverlay.of(rootContext), returnsNormally);
    expect(
      NavigatorScopeRegistry.instance.debugRegisteredScopeCount,
      initialScopeCount + 2,
    );

    await tester.pump();
    expect(
      NavigatorScopeRegistry.instance.debugRegisteredScopeCount,
      initialScopeCount + 1,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  });

  testWidgets('idle scope reattached in prune frame is retained', (
    tester,
  ) async {
    final initialScopeCount =
        NavigatorScopeRegistry.instance.debugRegisteredScopeCount;
    final integration = SuperOverlay.integration();
    final scopedObserver = integration.navigatorObserver();
    late StateSetter updateHost;
    late BuildContext rootContext;
    late BuildContext nestedContext;
    var showNested = true;

    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: <NavigatorObserver>[integration.observer],
        home: StatefulBuilder(
          builder: (context, setState) {
            rootContext = context;
            updateHost = setState;
            if (!showNested) {
              return const Scaffold(body: Text('Idle nested gap'));
            }
            return Navigator(
              observers: <NavigatorObserver>[scopedObserver],
              onGenerateRoute:
                  (_) => MaterialPageRoute<void>(
                    builder:
                        (context) => Builder(
                          builder: (context) {
                            nestedContext = context;
                            return const Scaffold(
                              body: Text('Reattached nested owner page'),
                            );
                          },
                        ),
                  ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    updateHost(() => showNested = false);
    await tester.pump();
    expect(
      NavigatorScopeRegistry.instance.debugRegisteredScopeCount,
      initialScopeCount + 2,
    );

    expect(() => SuperOverlay.of(rootContext), returnsNormally);
    updateHost(() => showNested = true);
    await tester.pumpAndSettle();

    expect(
      NavigatorScopeRegistry.instance.debugRegisteredScopeCount,
      initialScopeCount + 2,
    );
    expect(() => SuperOverlay.of(nestedContext), returnsNormally);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  });

  testWidgets('host retirement prunes idle detached scoped observers', (
    tester,
  ) async {
    final initialScopeCount =
        NavigatorScopeRegistry.instance.debugRegisteredScopeCount;
    final integration = SuperOverlay.integration();
    final scopedObserver = integration.navigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: <NavigatorObserver>[integration.observer],
        home: Navigator(
          observers: <NavigatorObserver>[scopedObserver],
          onGenerateRoute:
              (_) => MaterialPageRoute<void>(
                builder:
                    (_) => const Scaffold(
                      body: Text('Host retirement nested page'),
                    ),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      NavigatorScopeRegistry.instance.debugRegisteredScopeCount,
      initialScopeCount + 2,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(
      NavigatorScopeRegistry.instance.debugRegisteredScopeCount,
      initialScopeCount + 1,
    );

    integration.dispose();
    expect(
      NavigatorScopeRegistry.instance.debugRegisteredScopeCount,
      initialScopeCount,
    );
  });

  testWidgets('scoped popup follows nested route suspension', (tester) async {
    final integration = SuperOverlay.integration();
    final scopedObserver = integration.navigatorObserver();
    final nestedKey = GlobalKey<NavigatorState>();
    late BuildContext routeContext;

    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: <NavigatorObserver>[integration.observer],
        home: Navigator(
          key: nestedKey,
          observers: <NavigatorObserver>[scopedObserver],
          onGenerateRoute:
              (_) => MaterialPageRoute<void>(
                builder:
                    (context) => Builder(
                      builder: (context) {
                        routeContext = context;
                        return const Scaffold(
                          body: Center(child: Text('Popup target')),
                        );
                      },
                    ),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final targetContext = tester.element(find.text('Popup target'));

    final handle = SuperOverlay.of(routeContext).popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Scoped nested popup'),
    );
    await tester.pumpAndSettle();
    await handle.visible;

    nestedKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Popup covering page')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scoped nested popup'), findsNothing);
    expect(handle.isVisible, isFalse);

    nestedKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Scoped nested popup'), findsOneWidget);

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  });

  testWidgets('display timer continues while scoped dialog is suspended', (
    tester,
  ) async {
    final harness = await _pumpNestedApp(tester);
    final handle = SuperOverlay.of(harness.nestedContext).dialog.show<void>(
      builder: (_) => const Text('Timed scoped dialog'),
      options: const OverlayDialogOptions(
        displayDuration: Duration(seconds: 2),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await handle.visible;

    harness.navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Timed covering page')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(handle.isVisible, isFalse);
    expect(SuperOverlay.exists(tag: null), isTrue);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 300));
    await handle.closed;

    expect(SuperOverlay.exists(tag: null), isFalse);
    await harness.dispose(tester);
  });

  testWidgets('observer dispose before first frame fails visible and closes', (
    tester,
  ) async {
    final harness = await _pumpNestedApp(tester);
    final handle = SuperOverlay.of(harness.nestedContext).dialog.show<void>(
      builder: (_) => const Text('Pre-frame observer dialog'),
    );
    Object? visibleError;
    handle.visible.then<void>(
      (_) {},
      onError: (Object error, StackTrace _) => visibleError = error,
    );

    harness.nestedObserver!.dispose();
    await tester.pumpAndSettle();
    await handle.closed;

    expect(visibleError, isA<StateError>());
    expect(handle.isVisible, isFalse);
    await harness.dispose(tester);
  });

  testWidgets('root back closes a visible nested-scoped dialog first', (
    tester,
  ) async {
    final harness = await _pumpNestedApp(tester);
    final handle = SuperOverlay.of(harness.nestedContext).dialog.show<void>(
      builder: (_) => const Text('Nested dialog from root back'),
    );
    await tester.pumpAndSettle();

    expect(harness.rootRoute.popDisposition, RoutePopDisposition.doNotPop);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    await handle.closed;

    expect(find.text('Nested dialog from root back'), findsNothing);
    expect(find.text('Nested first page'), findsOneWidget);
    expect(
      harness.rootRoute.popDisposition,
      isNot(RoutePopDisposition.doNotPop),
    );
    await harness.dispose(tester);
  });

  testWidgets('unmounted invocation context closes its scoped overlay', (
    tester,
  ) async {
    final integration = SuperOverlay.integration();
    final scopedObserver = integration.navigatorObserver();
    late StateSetter updateRoute;
    late BuildContext invocationContext;
    var showInvocation = true;

    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: <NavigatorObserver>[integration.observer],
        home: Navigator(
          observers: <NavigatorObserver>[scopedObserver],
          onGenerateRoute:
              (_) => MaterialPageRoute<void>(
                builder:
                    (_) => StatefulBuilder(
                      builder: (context, setState) {
                        updateRoute = setState;
                        return Scaffold(
                          body:
                              showInvocation
                                  ? Builder(
                                    builder: (context) {
                                      invocationContext = context;
                                      return const Text('Invocation owner');
                                    },
                                  )
                                  : const Text('Invocation removed'),
                        );
                      },
                    ),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final handle = SuperOverlay.of(
      invocationContext,
    ).dialog.show<void>(builder: (_) => const Text('Invocation-owned dialog'));
    await tester.pumpAndSettle();
    var closed = false;
    handle.closed.then((_) => closed = true);

    updateRoute(() => showInvocation = false);
    await tester.pump();
    expect((invocationContext as Element).mounted, isFalse);
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(find.text('Invocation-owned dialog'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  });

  testWidgets('keepExisting handle reports a suspended overlay as hidden', (
    tester,
  ) async {
    final harness = await _pumpNestedApp(tester);
    final scoped = SuperOverlay.of(harness.nestedContext);
    final first = scoped.dialog.show<void>(
      builder: (_) => const Text('Kept scoped dialog'),
      options: const OverlayDialogOptions(tag: 'kept-scoped'),
    );
    await tester.pumpAndSettle();

    harness.navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Keep covering page')),
      ),
    );
    await tester.pumpAndSettle();
    final reused = scoped.dialog.show<void>(
      builder: (_) => const Text('Unused replacement content'),
      options: const OverlayDialogOptions(
        tag: 'kept-scoped',
        strategy: OverlayStrategy.keepExisting,
      ),
    );

    expect(first.isVisible, isFalse);
    expect(reused.isVisible, isFalse);

    final close = reused.close();
    await tester.pumpAndSettle();
    await close;
    await first.closed;
    await reused.closed;
    await harness.dispose(tester);
  });
}
