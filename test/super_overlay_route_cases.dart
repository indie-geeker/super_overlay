part of 'super_overlay_test.dart';

void registerRouteOverlayTests() {
  testWidgets('popping a route removes bindPage dialogs from that route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlayInit.init(),
        navigatorObservers: [SuperOverlayInit.observer],
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
                                  SuperOverlay.show(
                                    builder: (_) =>
                                        const Text('Route Bound Dialog'),
                                  ).withTag('route-bound').fire<void>();
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

    expect(find.text('Route Bound Dialog'), findsNothing);
    expect(SuperOverlay.checkExist(tag: 'route-bound'), isFalse);
  });

  testWidgets('pushing a new route hides bound dialogs and pop shows them', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlayInit.init(),
        navigatorObservers: [SuperOverlayInit.observer],
        home: Scaffold(
          body: Builder(
            builder: (homeContext) {
              return Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      SuperOverlay.show(
                        builder: (_) => const Text('Home Bound Dialog'),
                      ).withTag('home-bound').fire<void>();
                    },
                    child: const Text('Show Home Dialog'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(homeContext).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const Scaffold(
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
        builder: (_) =>
            const Scaffold(body: Center(child: Text('Second Route'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Second Route'), findsOneWidget);
    expect(find.text('Home Bound Dialog'), findsNothing);
    expect(SuperOverlay.checkExist(tag: 'home-bound'), isTrue);

    Navigator.of(tester.element(find.text('Second Route'))).pop();
    await tester.pumpAndSettle();

    expect(find.text('Home Bound Dialog'), findsOneWidget);
    await SuperOverlay.dismiss(tag: 'home-bound');
    await tester.pumpAndSettle();
  });
}
