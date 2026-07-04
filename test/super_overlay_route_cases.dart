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
    expect(SuperOverlay.checkExist(tag: 'route-bound'), isTrue);

    Navigator.of(tester.element(find.text('Show Route Dialog'))).pop();
    await tester.pumpAndSettle();
    await routeHandle.closed;

    expect(find.text('Route Bound Dialog'), findsNothing);
    expect(SuperOverlay.checkExist(tag: 'route-bound'), isFalse);
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
    expect(SuperOverlay.checkExist(tag: 'home-bound'), isTrue);

    Navigator.of(tester.element(find.text('Second Route'))).pop();
    await tester.pumpAndSettle();

    expect(find.text('Home Bound Dialog'), findsOneWidget);
    await homeHandle.close();
    await tester.pumpAndSettle();
  });
}
