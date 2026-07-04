part of 'super_overlay_test.dart';

void registerBackOverlayTests() {
  testWidgets('dismiss back behavior closes overlay and blocks page pop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlay.init(),
        navigatorObservers: [SuperOverlay.observer],
        home: const Scaffold(body: Text('First Page')),
        routes: {
          '/second':
              (_) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    SuperOverlay.dialog.show<void>(
                      builder: (_) => const Text('Back Normal Dialog'),
                      options: const OverlayDialogOptions(
                        backBehavior: OverlayBackBehavior.dismiss,
                      ),
                    );
                  },
                  child: const Text('Show Back Normal'),
                ),
              ),
        },
      ),
    );

    Navigator.of(tester.element(find.text('First Page'))).pushNamed('/second');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Back Normal'));
    await tester.pumpAndSettle();

    final handled = await dispatchSystemBack(tester);

    expect(handled, isTrue);
    expect(find.text('Back Normal Dialog'), findsNothing);
    expect(find.text('Show Back Normal'), findsOneWidget);
  });

  testWidgets('block back behavior keeps overlay and blocks page pop', (
    tester,
  ) async {
    late OverlayHandle<void> handle;
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlay.init(),
        navigatorObservers: [SuperOverlay.observer],
        home: const Scaffold(body: Text('First Page')),
        routes: {
          '/second':
              (_) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    handle = SuperOverlay.dialog.show<void>(
                      builder: (_) => const Text('Back Block Dialog'),
                      options: const OverlayDialogOptions(
                        backBehavior: OverlayBackBehavior.block,
                      ),
                    );
                  },
                  child: const Text('Show Back Block'),
                ),
              ),
        },
      ),
    );

    Navigator.of(tester.element(find.text('First Page'))).pushNamed('/second');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Back Block'));
    await tester.pumpAndSettle();

    final handled = await dispatchSystemBack(tester);

    expect(handled, isTrue);
    expect(find.text('Back Block Dialog'), findsOneWidget);
    expect(find.text('Show Back Block'), findsOneWidget);

    await handle.close();
    await tester.pumpAndSettle();
  });

  testWidgets('passThrough back behavior lets page pop proceed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlay.init(),
        navigatorObservers: [SuperOverlay.observer],
        home: const Scaffold(body: Text('First Page')),
        routes: {
          '/second':
              (_) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    SuperOverlay.dialog.show<void>(
                      builder: (_) => const Text('Back Ignore Dialog'),
                      options: const OverlayDialogOptions(
                        backBehavior: OverlayBackBehavior.passThrough,
                      ),
                    );
                  },
                  child: const Text('Show Back Ignore'),
                ),
              ),
        },
      ),
    );

    Navigator.of(tester.element(find.text('First Page'))).pushNamed('/second');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Back Ignore'));
    await tester.pumpAndSettle();

    final handled = await dispatchSystemBack(tester);

    expect(handled, isTrue);
    expect(find.text('First Page'), findsOneWidget);
    expect(find.text('Back Ignore Dialog'), findsNothing);
  });

  testWidgets('loading back handling has priority before page pop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlay.init(),
        navigatorObservers: [SuperOverlay.observer],
        home: const Scaffold(body: Text('First Page')),
        routes: {
          '/second':
              (_) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    SuperOverlay.loading.show(
                      message: 'Back Loading',
                      options: const OverlayLoadingOptions(
                        backBehavior: OverlayBackBehavior.dismiss,
                      ),
                    );
                  },
                  child: const Text('Show Back Loading'),
                ),
              ),
        },
      ),
    );

    Navigator.of(tester.element(find.text('First Page'))).pushNamed('/second');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Back Loading'));
    await tester.pump(const Duration(milliseconds: 250));

    final handled = await dispatchSystemBack(tester);

    expect(handled, isTrue);
    expect(find.text('Back Loading'), findsNothing);
    expect(find.text('Show Back Loading'), findsOneWidget);
  });

  testWidgets('notify back handling dismisses notify before page pop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlay.init(),
        navigatorObservers: [SuperOverlay.observer],
        home: const Scaffold(body: Text('First Page')),
        routes: {
          '/second':
              (_) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    SuperOverlay.notify.alert(
                      'Back Notify',
                      options: const OverlayNotifyOptions(
                        displayDuration: Duration(seconds: 1),
                        backBehavior: OverlayBackBehavior.dismiss,
                      ),
                    );
                  },
                  child: const Text('Show Back Notify'),
                ),
              ),
        },
      ),
    );

    Navigator.of(tester.element(find.text('First Page'))).pushNamed('/second');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Back Notify'));
    await tester.pump(const Duration(milliseconds: 100));

    final handled = await dispatchSystemBack(tester);

    expect(handled, isTrue);
    expect(find.text('Back Notify'), findsNothing);
    expect(find.text('Show Back Notify'), findsOneWidget);
  });
}
