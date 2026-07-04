part of 'super_overlay_test.dart';

void registerRouteOverlayTests() {
  testWidgets('popping a route removes route-bound dialogs from that route', (
    tester,
  ) async {
    late OverlayHandle<void> routeHandle;

    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlay.init(),
        navigatorObservers: [SuperOverlay.observer],
        home: Scaffold(
          body: Builder(
            builder: (homeContext) {
              return ElevatedButton(
                onPressed: () {
                  Navigator.of(homeContext).push<void>(
                    MaterialPageRoute<void>(
                      builder: (routeContext) {
                        return Scaffold(
                          body: Column(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  routeHandle = SuperOverlay.dialog.show<void>(
                                    builder:
                                        (_) => const Text('Route Bound Dialog'),
                                    options: const OverlayDialogOptions(
                                      tag: 'route-bound',
                                      bindToRoute: true,
                                    ),
                                  );
                                },
                                child: const Text('Show Route Dialog'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(routeContext).pop();
                                },
                                child: const Text('Pop Route'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
                child: const Text('Open Route'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Route'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Route Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Route Bound Dialog'), findsOneWidget);
    expect(SuperOverlay.exists(tag: 'route-bound'), isTrue);

    Navigator.of(tester.element(find.text('Show Route Dialog'))).pop();
    await tester.pumpAndSettle();
    await routeHandle.closed;

    expect(find.text('Route Bound Dialog'), findsNothing);
    expect(SuperOverlay.exists(tag: 'route-bound'), isFalse);
  });

  testWidgets('pushing a new route hides bound dialogs and pop restores them', (
    tester,
  ) async {
    late OverlayHandle<void> homeHandle;

    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlay.init(),
        navigatorObservers: [SuperOverlay.observer],
        home: Scaffold(
          body: Builder(
            builder: (homeContext) {
              return Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      homeHandle = SuperOverlay.dialog.show<void>(
                        builder: (_) => const Text('Home Bound Dialog'),
                        options: const OverlayDialogOptions(
                          tag: 'home-bound',
                          bindToRoute: true,
                        ),
                      );
                    },
                    child: const Text('Show Home Dialog'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(homeContext).push<void>(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => const Scaffold(
                                body: Center(child: Text('Second Route')),
                              ),
                        ),
                      );
                    },
                    child: const Text('Push Route'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Home Dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Home Bound Dialog'), findsOneWidget);

    Navigator.of(tester.element(find.text('Show Home Dialog'))).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => const Scaffold(body: Center(child: Text('Second Route'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Second Route'), findsOneWidget);
    expect(find.text('Home Bound Dialog'), findsNothing);
    expect(SuperOverlay.exists(tag: 'home-bound'), isTrue);

    Navigator.of(tester.element(find.text('Second Route'))).pop();
    await tester.pumpAndSettle();

    expect(find.text('Home Bound Dialog'), findsOneWidget);
    await homeHandle.close();
    await tester.pumpAndSettle();
  });

  testWidgets('replacing a route closes route-bound dialogs from old route', (
    tester,
  ) async {
    late OverlayHandle<void> routeHandle;
    late BuildContext routeContext;

    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlay.init(),
        navigatorObservers: [SuperOverlay.observer],
        home: Scaffold(
          body: Builder(
            builder: (homeContext) {
              return ElevatedButton(
                onPressed: () {
                  Navigator.of(homeContext).push<void>(
                    MaterialPageRoute<void>(
                      builder: (context) {
                        routeContext = context;
                        return Scaffold(
                          body: ElevatedButton(
                            onPressed: () {
                              routeHandle = SuperOverlay.dialog.show<void>(
                                builder:
                                    (_) =>
                                        const Text('Replacement Bound Dialog'),
                                options: const OverlayDialogOptions(
                                  tag: 'replacement-bound',
                                  bindToRoute: true,
                                ),
                              );
                            },
                            child: const Text('Show Replacement Dialog'),
                          ),
                        );
                      },
                    ),
                  );
                },
                child: const Text('Open Replacement Source'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Replacement Source'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Replacement Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Replacement Bound Dialog'), findsOneWidget);
    expect(SuperOverlay.exists(tag: 'replacement-bound'), isTrue);

    Navigator.of(routeContext).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder:
            (_) => const Scaffold(
              body: Center(child: Text('Route Replacement Target')),
            ),
      ),
    );
    await tester.pumpAndSettle();
    await routeHandle.closed;

    expect(find.text('Route Replacement Target'), findsOneWidget);
    expect(find.text('Replacement Bound Dialog'), findsNothing);
    expect(SuperOverlay.exists(tag: 'replacement-bound'), isFalse);
    expect(routeHandle.isVisible, isFalse);
  });

  testWidgets('removing a route closes route-bound dialogs from that route', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    late OverlayHandle<void> routeHandle;
    late MaterialPageRoute<void> removableRoute;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: SuperOverlay.init(),
        navigatorObservers: [SuperOverlay.observer],
        home: Scaffold(
          body: Builder(
            builder: (homeContext) {
              return ElevatedButton(
                onPressed: () {
                  removableRoute = MaterialPageRoute<void>(
                    builder:
                        (_) => Scaffold(
                          body: ElevatedButton(
                            onPressed: () {
                              routeHandle = SuperOverlay.dialog.show<void>(
                                builder:
                                    (_) => const Text('Removed Bound Dialog'),
                                options: const OverlayDialogOptions(
                                  tag: 'removed-bound',
                                  bindToRoute: true,
                                ),
                              );
                            },
                            child: const Text('Show Removed Dialog'),
                          ),
                        ),
                  );
                  Navigator.of(homeContext).push<void>(removableRoute);
                },
                child: const Text('Open Removable Route'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Removable Route'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Removed Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Removed Bound Dialog'), findsOneWidget);
    expect(SuperOverlay.exists(tag: 'removed-bound'), isTrue);

    navigatorKey.currentState!.removeRoute(removableRoute);
    await tester.pumpAndSettle();
    await routeHandle.closed;

    expect(find.text('Removed Bound Dialog'), findsNothing);
    expect(SuperOverlay.exists(tag: 'removed-bound'), isFalse);
    expect(routeHandle.isVisible, isFalse);
  });

  testWidgets(
    'nested Navigator without an observer keeps route-bound overlays on the root route',
    (tester) async {
      final nestedNavigatorKey = GlobalKey<NavigatorState>();
      late OverlayHandle<void> nestedHandle;

      await tester.pumpWidget(
        MaterialApp(
          builder: SuperOverlay.init(),
          navigatorObservers: [SuperOverlay.observer],
          home: Navigator(
            key: nestedNavigatorKey,
            onGenerateRoute: (settings) {
              return MaterialPageRoute<void>(
                settings: settings,
                builder:
                    (_) => Scaffold(
                      body: ElevatedButton(
                        onPressed: () {
                          nestedHandle = SuperOverlay.dialog.show<void>(
                            builder:
                                (_) => const Text('Nested Root Bound Dialog'),
                            options: const OverlayDialogOptions(
                              tag: 'nested-root-bound',
                              bindToRoute: true,
                            ),
                          );
                        },
                        child: const Text('Show Nested Dialog'),
                      ),
                    ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Nested Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Nested Root Bound Dialog'), findsOneWidget);

      nestedNavigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder:
              (_) => const Scaffold(
                body: Center(child: Text('Nested Second Route')),
              ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nested Second Route'), findsOneWidget);
      expect(find.text('Nested Root Bound Dialog'), findsOneWidget);
      expect(SuperOverlay.exists(tag: 'nested-root-bound'), isTrue);

      await nestedHandle.close();
      await tester.pumpAndSettle();
    },
  );
}
