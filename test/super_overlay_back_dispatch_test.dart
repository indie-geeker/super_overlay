import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';
import 'package:super_overlay/src/config/enum_config.dart';
import 'package:super_overlay/src/data/show_param.dart';
import 'package:super_overlay/src/helper/overlay_manager.dart';

class _BackHarness {
  const _BackHarness({required this.integration, required this.navigatorKey});

  final SuperOverlayIntegration integration;
  final GlobalKey<NavigatorState> navigatorKey;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  }
}

class _NonModalOverlayRoute extends OverlayRoute<void> {
  @override
  Iterable<OverlayEntry> createOverlayEntries() {
    return <OverlayEntry>[
      OverlayEntry(
        builder:
            (_) => const IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: Text('Non-modal route'),
              ),
            ),
      ),
    ];
  }
}

Future<_BackHarness> _pumpApp(
  WidgetTester tester, {
  bool installObserver = true,
  WidgetBuilder? secondPageBuilder,
}) async {
  final integration = SuperOverlay.integration();
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      builder: integration.builder,
      navigatorObservers:
          installObserver
              ? <NavigatorObserver>[integration.observer]
              : const [],
      home: const Scaffold(body: Text('First page')),
      routes: {
        '/second':
            secondPageBuilder ??
            (_) => const Scaffold(body: Text('Second page')),
      },
    ),
  );
  return _BackHarness(integration: integration, navigatorKey: navigatorKey);
}

Future<void> _pushSecond(WidgetTester tester, _BackHarness harness) async {
  harness.navigatorKey.currentState!.pushNamed('/second');
  await tester.pumpAndSettle();
}

Future<bool> _dispatchBack(WidgetTester tester) async {
  final handled = await tester.binding.handlePopRoute();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  return handled;
}

({OverlayHandle<void>? handle, Object? error}) _captureOverlay(
  OverlayHandle<void> Function() show,
) {
  try {
    return (handle: show(), error: null);
  } catch (error) {
    return (handle: null, error: error);
  }
}

Future<void> _closeCaptured(
  WidgetTester tester,
  Iterable<OverlayHandle<void>?> handles,
) async {
  final closes = <Future<void>>[
    for (final handle in handles)
      if (handle != null) handle.close(),
  ];
  await tester.pumpAndSettle();
  await Future.wait(closes);
}

void main() {
  testWidgets('cold start dismiss closes overlay before page', (tester) async {
    final integration = SuperOverlay.integration();

    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: [integration.observer],
        home: const Scaffold(body: Text('First page')),
        routes: {
          '/second':
              (_) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    SuperOverlay.dialog.show<void>(
                      builder: (_) => const Text('Back dialog'),
                      options: const OverlayDialogOptions(
                        backBehavior: OverlayBackBehavior.dismiss,
                      ),
                    );
                  },
                  child: const Text('Show dialog'),
                ),
              ),
        },
      ),
    );

    Navigator.of(tester.element(find.text('First page'))).pushNamed('/second');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show dialog'));
    await tester.pumpAndSettle();

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.text('Back dialog'), findsNothing);
    expect(find.text('Show dialog'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  });

  testWidgets('block keeps the overlay and current route', (tester) async {
    final harness = await _pumpApp(tester);
    await _pushSecond(tester, harness);
    final handle = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Blocking dialog'),
      options: const OverlayDialogOptions(
        backBehavior: OverlayBackBehavior.block,
      ),
    );
    await tester.pumpAndSettle();

    expect(await _dispatchBack(tester), isTrue);

    expect(find.text('Blocking dialog'), findsOneWidget);
    expect(find.text('Second page'), findsOneWidget);

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    await harness.dispose(tester);
  });

  testWidgets('passThrough lets the route pop', (tester) async {
    final harness = await _pumpApp(tester);
    await _pushSecond(tester, harness);
    final handle = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Pass-through dialog'),
      options: const OverlayDialogOptions(
        backBehavior: OverlayBackBehavior.passThrough,
      ),
    );
    await tester.pumpAndSettle();

    expect(await _dispatchBack(tester), isTrue);

    expect(find.text('First page'), findsOneWidget);
    expect(find.text('Pass-through dialog'), findsNothing);
    await handle.closed;
    await harness.dispose(tester);
  });

  testWidgets('back dispatch honors loading notify and surface priority', (
    tester,
  ) async {
    final harness = await _pumpApp(tester);
    await _pushSecond(tester, harness);
    final targetContext = tester.element(find.text('Second page'));
    final dialog = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Priority dialog'),
    );
    final popup = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Priority popup'),
    );
    final notify = SuperOverlay.notify.alert(
      'Priority notify',
      options: const OverlayNotifyOptions(
        displayDuration: null,
        backBehavior: OverlayBackBehavior.dismiss,
      ),
    );
    final loading = SuperOverlay.loading.show(message: 'Priority loading');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(await _dispatchBack(tester), isTrue);
    expect(find.text('Priority loading'), findsNothing);
    expect(find.text('Priority notify'), findsOneWidget);
    expect(find.text('Priority popup'), findsOneWidget);
    expect(find.text('Priority dialog'), findsOneWidget);

    expect(await _dispatchBack(tester), isTrue);
    expect(find.text('Priority notify'), findsNothing);
    expect(find.text('Priority popup'), findsOneWidget);
    expect(find.text('Priority dialog'), findsOneWidget);

    expect(await _dispatchBack(tester), isTrue);
    expect(find.text('Priority popup'), findsNothing);
    expect(find.text('Priority dialog'), findsOneWidget);

    expect(await _dispatchBack(tester), isTrue);
    expect(find.text('Priority dialog'), findsNothing);
    expect(find.text('Second page'), findsOneWidget);

    await Future.wait<void>([
      dialog.closed.then<void>((_) {}),
      popup.closed.then<void>((_) {}),
      notify.closed.then<void>((_) {}),
      loading.closed.then<void>((_) {}),
    ]);
    await harness.dispose(tester);
  });

  testWidgets('closing overlay blocks a rapid second back until settled', (
    tester,
  ) async {
    final harness = await _pumpApp(tester);
    await _pushSecond(tester, harness);
    var backAttempts = 0;
    final closed = OverlayManager.instance.show<void>(
      param: ShowCustomParam(
        builder: (_) => const Text('Closing dialog'),
        alignment: Alignment.center,
        clickMaskDismiss: true,
        animationType: AnimationType.fade,
        nonAnimationTypes: const [],
        animationBuilder: null,
        usePenetrate: false,
        useAnimation: true,
        animationTime: const Duration(milliseconds: 200),
        maskColor: Colors.black45,
        maskWidget: null,
        onDismiss: null,
        onMask: null,
        awaitCompletion: AwaitCompletion.dismiss,
        debounce: false,
        debounceTime: Duration.zero,
        displayTime: null,
        tag: 'rapid-second-back',
        keepSingle: false,
        permanent: false,
        bindPage: true,
        bindWidget: null,
        ignoreArea: null,
        maskTriggerType: MaskTriggerType.up,
        controller: null,
        backType: BackType.normal,
        onBack: () {
          backAttempts++;
          return false;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump(const Duration(milliseconds: 50));
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Second page'), findsOneWidget);
    expect(backAttempts, 1);

    await tester.pumpAndSettle();
    await closed;
    expect(find.text('Closing dialog'), findsNothing);
    expect(find.text('Second page'), findsOneWidget);
    expect(backAttempts, 1);

    harness.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('First page'), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('missing matching observer rejects route-aware commands', (
    tester,
  ) async {
    final harness = await _pumpApp(tester, installObserver: false);
    final routeBound = _captureOverlay(
      () => SuperOverlay.dialog.show<void>(
        builder: (_) => const Text('Unexpected route-bound dialog'),
        options: const OverlayDialogOptions(
          backBehavior: OverlayBackBehavior.passThrough,
        ),
      ),
    );
    final consuming = _captureOverlay(
      () => SuperOverlay.dialog.show<void>(
        builder: (_) => const Text('Unexpected consuming dialog'),
        options: const OverlayDialogOptions(bindToRoute: false),
      ),
    );
    final routeNeutral = _captureOverlay(
      () => SuperOverlay.dialog.show<void>(
        builder: (_) => const Text('Allowed route-neutral dialog'),
        options: const OverlayDialogOptions(
          bindToRoute: false,
          backBehavior: OverlayBackBehavior.passThrough,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _closeCaptured(tester, [
      routeBound.handle,
      consuming.handle,
      routeNeutral.handle,
    ]);

    expect(
      routeBound.error,
      isA<StateError>().having(
        (error) => error.toString(),
        'message',
        contains('Navigator'),
      ),
    );
    expect(
      consuming.error,
      isA<StateError>().having(
        (error) => error.toString(),
        'message',
        contains('Navigator'),
      ),
    );
    expect(routeNeutral.error, isNull);
    expect(routeNeutral.handle, isNotNull);
    await harness.dispose(tester);
  });

  testWidgets('removing the matching observer invalidates route capability', (
    tester,
  ) async {
    final integration = SuperOverlay.integration();
    final navigatorKey = GlobalKey<NavigatorState>();

    Widget app({required bool installObserver}) {
      return MaterialApp(
        navigatorKey: navigatorKey,
        builder: integration.builder,
        navigatorObservers:
            installObserver
                ? <NavigatorObserver>[integration.observer]
                : const [],
        home: const Scaffold(body: Text('Observer removal page')),
      );
    }

    await tester.pumpWidget(app(installObserver: true));
    await tester.pumpWidget(app(installObserver: false));

    final routeBound = _captureOverlay(
      () => SuperOverlay.dialog.show<void>(
        builder: (_) => const Text('Unexpected detached observer dialog'),
        options: const OverlayDialogOptions(
          backBehavior: OverlayBackBehavior.passThrough,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _closeCaptured(tester, [routeBound.handle]);

    expect(
      routeBound.error,
      isA<StateError>().having(
        (error) => error.toString(),
        'message',
        contains('NavigatorObserver'),
      ),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  });

  testWidgets('non-ModalRoute rejects route binding and consuming back', (
    tester,
  ) async {
    final harness = await _pumpApp(tester);
    harness.navigatorKey.currentState!.push(_NonModalOverlayRoute());
    await tester.pumpAndSettle();
    expect(find.text('Non-modal route'), findsOneWidget);

    final routeBound = _captureOverlay(
      () => SuperOverlay.dialog.show<void>(
        builder: (_) => const Text('Unexpected non-modal route binding'),
        options: const OverlayDialogOptions(
          backBehavior: OverlayBackBehavior.passThrough,
        ),
      ),
    );
    final consuming = _captureOverlay(
      () => SuperOverlay.dialog.show<void>(
        builder: (_) => const Text('Unexpected non-modal back consumer'),
        options: const OverlayDialogOptions(bindToRoute: false),
      ),
    );
    final routeNeutral = _captureOverlay(
      () => SuperOverlay.dialog.show<void>(
        builder: (_) => const Text('Allowed non-modal route-neutral dialog'),
        options: const OverlayDialogOptions(
          bindToRoute: false,
          backBehavior: OverlayBackBehavior.passThrough,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _closeCaptured(tester, [
      routeBound.handle,
      consuming.handle,
      routeNeutral.handle,
    ]);

    expect(
      routeBound.error,
      isA<StateError>().having(
        (error) => error.toString(),
        'message',
        contains('ModalRoute'),
      ),
    );
    expect(
      consuming.error,
      isA<StateError>().having(
        (error) => error.toString(),
        'message',
        contains('ModalRoute'),
      ),
    );
    expect(routeNeutral.error, isNull);
    expect(routeNeutral.handle, isNotNull);
    harness.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await harness.dispose(tester);
  });

  testWidgets('PopScope and Form receive failed-pop callbacks', (tester) async {
    final popScopeResults = <bool>[];
    final formResults = <bool>[];
    final harness = await _pumpApp(
      tester,
      secondPageBuilder:
          (_) => PopScope<Object?>(
            canPop: true,
            onPopInvokedWithResult: (didPop, _) => popScopeResults.add(didPop),
            child: Form(
              canPop: true,
              onPopInvokedWithResult: (didPop, _) => formResults.add(didPop),
              child: const Scaffold(body: Text('Scoped form page')),
            ),
          ),
    );
    await _pushSecond(tester, harness);
    final handle = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Form blocking dialog'),
      options: const OverlayDialogOptions(
        backBehavior: OverlayBackBehavior.block,
      ),
    );
    await tester.pumpAndSettle();

    expect(await _dispatchBack(tester), isTrue);

    expect(find.text('Scoped form page'), findsOneWidget);
    expect(popScopeResults, <bool>[false]);
    expect(formResults, <bool>[false]);

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    await harness.dispose(tester);
  });

  testWidgets('back disposition is mirrored to current nested routes', (
    tester,
  ) async {
    final integration = SuperOverlay.integration();
    final nestedObserver = integration.navigatorObserver();
    final nestedNavigatorKey = GlobalKey<NavigatorState>();
    late ModalRoute<Object?> rootRoute;
    late ModalRoute<Object?> nestedRoute;

    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: [integration.observer],
        home: Builder(
          builder: (rootContext) {
            rootRoute = ModalRoute.of<Object?>(rootContext)!;
            return Scaffold(
              body: Navigator(
                key: nestedNavigatorKey,
                observers: [nestedObserver],
                onGenerateRoute:
                    (_) => MaterialPageRoute<void>(
                      builder:
                          (nestedContext) => Builder(
                            builder: (context) {
                              nestedRoute = ModalRoute.of<Object?>(context)!;
                              return const Text('Nested current page');
                            },
                          ),
                    ),
              ),
            );
          },
        ),
      ),
    );
    final handle = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Nested-dispatched dialog'),
    );
    await tester.pumpAndSettle();

    expect(rootRoute.popDisposition, RoutePopDisposition.doNotPop);
    expect(nestedRoute.popDisposition, RoutePopDisposition.doNotPop);

    expect(await nestedNavigatorKey.currentState!.maybePop(), isTrue);
    await tester.pumpAndSettle();
    await handle.closed;

    expect(find.text('Nested-dispatched dialog'), findsNothing);
    expect(find.text('Nested current page'), findsOneWidget);
    expect(rootRoute.popDisposition, isNot(RoutePopDisposition.doNotPop));
    expect(nestedRoute.popDisposition, isNot(RoutePopDisposition.doNotPop));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  });

  testWidgets('observer teardown unregisters its route PopEntry', (
    tester,
  ) async {
    late ModalRoute<Object?> secondRoute;
    final harness = await _pumpApp(
      tester,
      secondPageBuilder:
          (_) => Builder(
            builder: (context) {
              secondRoute = ModalRoute.of<Object?>(context)!;
              return const Scaffold(body: Text('Observer teardown page'));
            },
          ),
    );
    await _pushSecond(tester, harness);
    SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Observer teardown dialog'),
      options: const OverlayDialogOptions(
        backBehavior: OverlayBackBehavior.block,
      ),
    );
    await tester.pumpAndSettle();

    expect(secondRoute.popDisposition, RoutePopDisposition.doNotPop);

    harness.integration.dispose();

    expect(secondRoute.popDisposition, isNot(RoutePopDisposition.doNotPop));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('host teardown unregisters route PopEntries', (tester) async {
    late ModalRoute<Object?> secondRoute;
    final harness = await _pumpApp(
      tester,
      secondPageBuilder:
          (_) => Builder(
            builder: (context) {
              secondRoute = ModalRoute.of<Object?>(context)!;
              return const Scaffold(body: Text('Host teardown page'));
            },
          ),
    );
    await _pushSecond(tester, harness);
    final handle = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Host teardown dialog'),
      options: const OverlayDialogOptions(
        backBehavior: OverlayBackBehavior.block,
      ),
    );
    await tester.pumpAndSettle();

    expect(secondRoute.popDisposition, RoutePopDisposition.doNotPop);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(secondRoute.popDisposition, isNot(RoutePopDisposition.doNotPop));
    await handle.closed;
    harness.integration.dispose();
  });

  testWidgets('unkeyed integration replacement transfers the route PopEntry', (
    tester,
  ) async {
    final first = SuperOverlay.integration();
    final second = SuperOverlay.integration();
    final navigatorKey = GlobalKey<NavigatorState>();

    Widget app(SuperOverlayIntegration integration) {
      return MaterialApp(
        navigatorKey: navigatorKey,
        builder: integration.builder,
        navigatorObservers: [integration.observer],
        home: const Scaffold(body: Text('Shared first page')),
        routes: {
          '/second': (_) => const Scaffold(body: Text('Shared second page')),
        },
      );
    }

    await tester.pumpWidget(app(first));
    navigatorKey.currentState!.pushNamed('/second');
    await tester.pumpAndSettle();
    final retired = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Retired blocking dialog'),
      options: const OverlayDialogOptions(
        backBehavior: OverlayBackBehavior.block,
      ),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(app(second));
    await tester.pump();
    await tester.idle();
    await retired.closed;

    final active = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Replacement dialog'),
    );
    await tester.pumpAndSettle();

    expect(await _dispatchBack(tester), isTrue);
    await active.closed;
    expect(find.text('Replacement dialog'), findsNothing);
    expect(find.text('Shared second page'), findsOneWidget);

    expect(await _dispatchBack(tester), isTrue);
    expect(find.text('Shared first page'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    first.dispose();
    second.dispose();
  });
}
