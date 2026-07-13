import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

void main() {
  test('integrations own stable and distinct root observers', () {
    final first = SuperOverlay.integration();
    final second = SuperOverlay.integration();

    expect(first.observer, same(first.observer));
    expect(first.observer, isNot(same(second.observer)));

    first.dispose();
    first.dispose();
    second.dispose();
  });

  testWidgets('integration builder installs its configured host', (
    tester,
  ) async {
    final integration = SuperOverlay.integration(
      toastBuilder: (message) => Text('owned: $message'),
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: [integration.observer],
        home: const Scaffold(),
      ),
    );

    final handle = SuperOverlay.toast(
      'hello',
      options: const OverlayToastOptions(displayDuration: Duration(minutes: 1)),
    );
    await tester.pump();

    expect(find.text('owned: hello'), findsOneWidget);

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    await tester.pumpWidget(const SizedBox.shrink());
    integration.dispose();
  });

  testWidgets('legacy init and observer use the stable default integration', (
    tester,
  ) async {
    final observer = SuperOverlay.observer;
    final builder = SuperOverlay.init(
      toastBuilder: (message) => Text('legacy: $message'),
    );

    expect(SuperOverlay.observer, same(observer));

    await tester.pumpWidget(
      MaterialApp(
        builder: builder,
        navigatorObservers: [observer],
        home: const Scaffold(),
      ),
    );

    final handle = SuperOverlay.toast(
      'hello',
      options: const OverlayToastOptions(displayDuration: Duration(minutes: 1)),
    );
    await tester.pump();

    expect(find.text('legacy: hello'), findsOneWidget);

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('scoped navigator observers are distinct and disposable', () {
    final integration = SuperOverlay.integration();

    final first = integration.navigatorObserver();
    final second = integration.navigatorObserver();

    expect(first, isA<SuperOverlayNavigatorObserver>());
    expect(first, isNot(same(second)));

    first.dispose();
    first.dispose();
    integration.dispose();
    integration.dispose();
    second.dispose();
  });

  test('disposed integration rejects builder access', () {
    final integration = SuperOverlay.integration();
    integration.dispose();

    expect(
      () => integration.builder,
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('disposed'),
        ),
      ),
    );
  });

  test('disposed integration rejects root observer access', () {
    final integration = SuperOverlay.integration();
    integration.dispose();

    expect(
      () => integration.observer,
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('disposed'),
        ),
      ),
    );
  });

  test('disposed integration rejects scoped observer creation', () {
    final integration = SuperOverlay.integration();
    integration.dispose();

    expect(() => integration.navigatorObserver(), throwsStateError);
  });

  testWidgets('cached builder rejects use after integration disposal', (
    tester,
  ) async {
    final integration = SuperOverlay.integration();
    final cachedBuilder = integration.builder;
    late BuildContext context;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (buildContext) {
            context = buildContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    integration.dispose();

    expect(
      () => cachedBuilder(context, const SizedBox.shrink()),
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('disposed'),
        ),
      ),
    );
  });

  test('root observer rejects direct disposal', () {
    final integration = SuperOverlay.integration();
    final observer = integration.observer;

    expect(
      observer.dispose,
      throwsA(
        isA<StateError>().having(
          (error) => error.toString(),
          'message',
          contains('root observer'),
        ),
      ),
    );

    expect(integration.observer, same(observer));
    integration.dispose();
  });

  testWidgets(
    'legacy root observer rejects direct disposal and keeps tracking routes',
    (tester) async {
      final observer = SuperOverlay.observer;

      expect(
        observer.dispose,
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('root observer'),
          ),
        ),
      );

      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          builder: SuperOverlay.init(),
          navigatorObservers: [observer],
          home: const Scaffold(),
        ),
      );

      final handle = SuperOverlay.dialog.show<void>(
        builder: (_) => const Text('Legacy observer dialog'),
        options: const OverlayDialogOptions(
          tag: 'legacy-observer-dialog',
          bindToRoute: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Legacy observer dialog'), findsOneWidget);

      navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Second route')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Legacy observer dialog'), findsNothing);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Legacy observer dialog'), findsOneWidget);

      final close = handle.close();
      await tester.pumpAndSettle();
      await close;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
