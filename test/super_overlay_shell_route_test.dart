import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:super_overlay/super_overlay.dart';

Future<void> _disposeRouterApp(
  WidgetTester tester,
  GoRouter router,
  SuperOverlayIntegration integration,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  router.dispose();
  integration.dispose();
}

void main() {
  testWidgets('ShellRoute scopes page overlays but not shell chrome', (
    tester,
  ) async {
    final integration = SuperOverlay.integration();
    final rootNavigatorKey = GlobalKey<NavigatorState>();
    final shellNavigatorKey = GlobalKey<NavigatorState>();
    final shellObserver = integration.navigatorObserver();
    late BuildContext shellChromeContext;
    late BuildContext pageContext;

    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      observers: <NavigatorObserver>[integration.observer],
      initialLocation: '/shell-a',
      routes: <RouteBase>[
        ShellRoute(
          navigatorKey: shellNavigatorKey,
          observers: <NavigatorObserver>[shellObserver],
          builder:
              (context, state, child) => Builder(
                builder: (context) {
                  shellChromeContext = context;
                  return Scaffold(
                    appBar: AppBar(title: const Text('Shell chrome')),
                    body: child,
                  );
                },
              ),
          routes: <RouteBase>[
            GoRoute(
              path: '/shell-a',
              builder:
                  (context, state) => Builder(
                    builder: (context) {
                      pageContext = context;
                      return const Scaffold(body: Text('Shell page A'));
                    },
                  ),
            ),
            GoRoute(
              path: '/shell-detail',
              builder:
                  (context, state) =>
                      const Scaffold(body: Text('Shell detail')),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(builder: integration.builder, routerConfig: router),
    );
    await tester.pumpAndSettle();

    final pageHandle = SuperOverlay.of(
      pageContext,
    ).dialog.show<void>(builder: (_) => const Text('Shell page overlay'));
    await tester.pumpAndSettle();

    router.push('/shell-detail');
    await tester.pumpAndSettle();

    expect(find.text('Shell detail'), findsOneWidget);
    expect(find.text('Shell page overlay'), findsNothing);
    expect(pageHandle.isVisible, isFalse);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('Shell page overlay'), findsOneWidget);
    expect(pageHandle.isVisible, isTrue);

    router.go('/shell-detail');
    await tester.pumpAndSettle();
    await pageHandle.closed;

    expect(find.text('Shell page overlay'), findsNothing);

    final chromeHandle = SuperOverlay.of(
      shellChromeContext,
    ).dialog.show<void>(builder: (_) => const Text('Shell chrome overlay'));
    await tester.pumpAndSettle();

    router.push('/shell-a');
    await tester.pumpAndSettle();

    expect(find.text('Shell chrome overlay'), findsOneWidget);
    expect(chromeHandle.isVisible, isTrue);

    final close = chromeHandle.close();
    await tester.pumpAndSettle();
    await close;
    await _disposeRouterApp(tester, router, integration);
  });

  testWidgets('indexed StatefulShellRoute suspends inactive branch overlay', (
    tester,
  ) async {
    final integration = SuperOverlay.integration();
    final rootNavigatorKey = GlobalKey<NavigatorState>();
    final branchANavigatorKey = GlobalKey<NavigatorState>();
    final branchBNavigatorKey = GlobalKey<NavigatorState>();
    final branchAObserver = integration.navigatorObserver();
    final branchBObserver = integration.navigatorObserver();
    late StatefulNavigationShell navigationShell;
    late BuildContext branchAContext;
    late ModalRoute<Object?> rootRoute;

    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      observers: <NavigatorObserver>[integration.observer],
      initialLocation: '/branch-a',
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              navigatorKey: branchANavigatorKey,
              observers: <NavigatorObserver>[branchAObserver],
              routes: <RouteBase>[
                GoRoute(
                  path: '/branch-a',
                  builder:
                      (context, state) => Builder(
                        builder: (context) {
                          branchAContext = context;
                          return const Scaffold(body: Text('Branch A'));
                        },
                      ),
                ),
                GoRoute(
                  path: '/branch-a-replacement',
                  builder:
                      (context, state) =>
                          const Scaffold(body: Text('Branch A replacement')),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: branchBNavigatorKey,
              observers: <NavigatorObserver>[branchBObserver],
              routes: <RouteBase>[
                GoRoute(
                  path: '/branch-b',
                  builder:
                      (context, state) =>
                          const Scaffold(body: Text('Branch B')),
                ),
              ],
            ),
          ],
          builder: (context, state, child) {
            rootRoute = ModalRoute.of<Object?>(context)!;
            navigationShell = child;
            return Scaffold(body: child);
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(builder: integration.builder, routerConfig: router),
    );
    await tester.pumpAndSettle();

    final handle = SuperOverlay.of(
      branchAContext,
    ).dialog.show<void>(builder: (_) => const Text('Branch A overlay'));
    await tester.pumpAndSettle();

    expect(rootRoute.popDisposition, RoutePopDisposition.doNotPop);
    expect(find.text('Branch A overlay'), findsOneWidget);

    navigationShell.goBranch(1);
    await tester.pumpAndSettle();

    expect(find.text('Branch B'), findsOneWidget);
    expect(find.text('Branch A overlay'), findsNothing);
    expect(handle.isVisible, isFalse);
    expect(rootRoute.popDisposition, isNot(RoutePopDisposition.doNotPop));

    navigationShell.goBranch(0);
    await tester.pumpAndSettle();

    expect(find.text('Branch A overlay'), findsOneWidget);
    expect(handle.isVisible, isTrue);

    router.go('/branch-a-replacement');
    await tester.pumpAndSettle();
    await handle.closed;

    expect(find.text('Branch A replacement'), findsOneWidget);
    expect(find.text('Branch A overlay'), findsNothing);
    await _disposeRouterApp(tester, router, integration);
  });

  testWidgets(
    'custom branch TickerMode ignores a page-local disabled TickerMode',
    (tester) async {
      final integration = SuperOverlay.integration();
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final branchANavigatorKey = GlobalKey<NavigatorState>();
      final branchBNavigatorKey = GlobalKey<NavigatorState>();
      final branchAObserver = integration.navigatorObserver();
      final branchBObserver = integration.navigatorObserver();
      late StatefulNavigationShell navigationShell;
      late BuildContext branchAContext;

      final router = GoRouter(
        navigatorKey: rootNavigatorKey,
        observers: <NavigatorObserver>[integration.observer],
        initialLocation: '/custom-a',
        routes: <RouteBase>[
          StatefulShellRoute(
            branches: <StatefulShellBranch>[
              StatefulShellBranch(
                navigatorKey: branchANavigatorKey,
                observers: <NavigatorObserver>[branchAObserver],
                routes: <RouteBase>[
                  GoRoute(
                    path: '/custom-a',
                    builder:
                        (context, state) => TickerMode(
                          enabled: false,
                          child: Builder(
                            builder: (context) {
                              branchAContext = context;
                              return const Scaffold(
                                body: Text('Custom branch A'),
                              );
                            },
                          ),
                        ),
                  ),
                ],
              ),
              StatefulShellBranch(
                navigatorKey: branchBNavigatorKey,
                observers: <NavigatorObserver>[branchBObserver],
                routes: <RouteBase>[
                  GoRoute(
                    path: '/custom-b',
                    builder:
                        (context, state) =>
                            const Scaffold(body: Text('Custom branch B')),
                  ),
                ],
              ),
            ],
            navigatorContainerBuilder: (context, child, children) {
              return IndexedStack(
                index: child.currentIndex,
                children: <Widget>[
                  for (var index = 0; index < children.length; index++)
                    TickerMode(
                      enabled: index == child.currentIndex,
                      child: children[index],
                    ),
                ],
              );
            },
            builder: (context, state, child) {
              navigationShell = child;
              return Scaffold(body: child);
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(builder: integration.builder, routerConfig: router),
      );
      await tester.pumpAndSettle();

      final handle = SuperOverlay.of(
        branchAContext,
      ).dialog.show<void>(builder: (_) => const Text('Custom branch overlay'));
      await tester.pumpAndSettle();

      expect(find.text('Custom branch overlay'), findsOneWidget);
      expect(handle.isVisible, isTrue);

      navigationShell.goBranch(1);
      await tester.pumpAndSettle();

      expect(find.text('Custom branch B'), findsOneWidget);
      expect(find.text('Custom branch overlay'), findsNothing);
      expect(handle.isVisible, isFalse);

      navigationShell.goBranch(0);
      await tester.pumpAndSettle();

      expect(find.text('Custom branch overlay'), findsOneWidget);
      expect(handle.isVisible, isTrue);

      final close = handle.close();
      await tester.pumpAndSettle();
      await close;
      await _disposeRouterApp(tester, router, integration);
    },
  );
}
