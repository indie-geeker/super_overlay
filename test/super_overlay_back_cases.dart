part of 'super_overlay_test.dart';

void registerBackOverlayTests() {
  testWidgets('BackType.normal dismisses overlay and blocks page pop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlayInit.init(),
        navigatorObservers: [SuperOverlayInit.observer],
        home: const Scaffold(body: Text('First Page')),
        routes: {
          '/second':
              (_) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    SuperOverlay.show(
                      builder: (_) => const Text('Back Normal Dialog'),
                    ).withBack(type: BackType.normal).fire<void>();
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

  testWidgets('BackType.block blocks overlay dismiss and page pop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlayInit.init(),
        navigatorObservers: [SuperOverlayInit.observer],
        home: const Scaffold(body: Text('First Page')),
        routes: {
          '/second':
              (_) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    SuperOverlay.show(
                      builder: (_) => const Text('Back Block Dialog'),
                    ).withBack(type: BackType.block).fire<void>();
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

    await SuperOverlay.dismiss(status: DismissStatus.allDialog, force: true);
    await tester.pumpAndSettle();
  });

  testWidgets('BackType.ignore lets page pop proceed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlayInit.init(),
        navigatorObservers: [SuperOverlayInit.observer],
        home: const Scaffold(body: Text('First Page')),
        routes: {
          '/second':
              (_) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    SuperOverlay.show(
                      builder: (_) => const Text('Back Ignore Dialog'),
                    ).withBack(type: BackType.ignore).fire<void>();
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

  testWidgets('onBack returning true intercepts the event', (tester) async {
    var backCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlayInit.init(),
        navigatorObservers: [SuperOverlayInit.observer],
        home: const Scaffold(body: Text('First Page')),
        routes: {
          '/second':
              (_) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    SuperOverlay.show(
                          builder: (_) => const Text('Back Callback Dialog'),
                        )
                        .withBack(
                          type: BackType.normal,
                          onBack: () {
                            backCalls++;
                            return true;
                          },
                        )
                        .fire<void>();
                  },
                  child: const Text('Show Back Callback'),
                ),
              ),
        },
      ),
    );

    Navigator.of(tester.element(find.text('First Page'))).pushNamed('/second');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Back Callback'));
    await tester.pumpAndSettle();

    final handled = await dispatchSystemBack(tester);

    expect(handled, isTrue);
    expect(backCalls, 1);
    expect(find.text('Back Callback Dialog'), findsOneWidget);
    expect(find.text('Show Back Callback'), findsOneWidget);

    await SuperOverlay.dismiss(status: DismissStatus.allDialog, force: true);
    await tester.pumpAndSettle();
  });

  testWidgets('loading back handling dismisses loading before page pop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlayInit.init(),
        navigatorObservers: [SuperOverlayInit.observer],
        home: const Scaffold(body: Text('First Page')),
        routes: {
          '/second':
              (_) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    SuperOverlay.showLoading(
                      msg: 'Back Loading',
                    ).withBack(type: BackType.normal).fire<void>();
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
        builder: SuperOverlayInit.init(),
        navigatorObservers: [SuperOverlayInit.observer],
        home: const Scaffold(body: Text('First Page')),
        routes: {
          '/second':
              (_) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    SuperOverlay.showNotify(
                          msg: 'Back Notify',
                          type: NotifyType.alert,
                        )
                        .withDisplayTime(const Duration(seconds: 1))
                        .withBack(type: BackType.normal)
                        .fire<void>();
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
