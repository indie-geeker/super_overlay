import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

Future<void> _dispose(
  WidgetTester tester,
  SuperOverlayIntegration integration,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  integration.dispose();
}

Future<void> _mount(
  WidgetTester tester,
  SuperOverlayIntegration integration,
) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: integration.builder,
      navigatorObservers: [integration.observer],
      home: const Scaffold(),
    ),
  );
}

OverlayHandle<void> _notify(
  OverlayNotificationType type, {
  WidgetBuilder? builder,
  OverlayStrategy strategy = OverlayStrategy.stack,
}) {
  final options = OverlayNotifyOptions(
    tag: 'notice',
    strategy: strategy,
    displayDuration: null,
  );
  return switch (type) {
    OverlayNotificationType.success => SuperOverlay.notify.success(
      'message',
      builder: builder,
      options: options,
    ),
    OverlayNotificationType.failure => SuperOverlay.notify.failure(
      'message',
      builder: builder,
      options: options,
    ),
    OverlayNotificationType.warning => SuperOverlay.notify.warning(
      'message',
      builder: builder,
      options: options,
    ),
    OverlayNotificationType.error => SuperOverlay.notify.error(
      'message',
      builder: builder,
      options: options,
    ),
    OverlayNotificationType.alert => SuperOverlay.notify.alert(
      'message',
      builder: builder,
      options: options,
    ),
  };
}

void main() {
  for (final surface in ['dialog', 'popup']) {
    for (final beforeFirstFrame in [false, true]) {
      testWidgets(
        '$surface unmount closes while suspended, pre-frame=$beforeFirstFrame',
        (tester) async {
          final integration = SuperOverlay.integration();
          final navigator = GlobalKey<NavigatorState>();
          final showTarget = ValueNotifier(true);
          late BuildContext target;
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navigator,
              builder: integration.builder,
              navigatorObservers: [integration.observer],
              home: Scaffold(
                body: ValueListenableBuilder<bool>(
                  valueListenable: showTarget,
                  builder:
                      (_, show, __) =>
                          show
                              ? Builder(
                                builder: (context) {
                                  target = context;
                                  return const SizedBox(width: 100, height: 40);
                                },
                              )
                              : const SizedBox.shrink(),
                ),
              ),
            ),
          );
          var builds = 0;
          Widget content(BuildContext _) {
            builds++;
            return const Text('owned content');
          }

          final scoped = SuperOverlay.of(target);
          final handle =
              surface == 'dialog'
                  ? scoped.dialog.show<void>(
                    builder: (context, _) => (content)(context),
                    options: OverlayDialogOptions(
                      tag: 'owned',
                      bindToWidget: target,
                    ),
                  )
                  : scoped.popup.show<void>(
                    targetContext: target,
                    builder: (context, _) => (content)(context),
                    options: const OverlayPopupOptions(tag: 'owned'),
                  );
          var completions = 0;
          Object? visibleError;
          handle.closed.then((_) => completions++);
          handle.visible.then<void>(
            (_) {},
            onError: (Object error, StackTrace _) => visibleError = error,
          );
          if (!beforeFirstFrame) {
            await tester.pumpAndSettle();
            await handle.visible;
          }
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('cover')),
            ),
          );
          await tester.pumpAndSettle();
          expect(handle.isVisible, isFalse);
          showTarget.value = false;
          await tester.pumpAndSettle();
          final completedAfterUnmount = completions;
          final existsAfterUnmount = SuperOverlay.exists(tag: 'owned');
          final preFrameError = visibleError;
          final buildsAfterUnmount = builds;
          expect(target.mounted, isFalse);
          await _dispose(tester, integration);
          showTarget.dispose();
          expect(completedAfterUnmount, 1);
          expect(existsAfterUnmount, isFalse);
          expect(completions, 1);
          if (beforeFirstFrame) {
            expect(preFrameError, isA<StateError>());
            expect(buildsAfterUnmount, 0);
          }
        },
      );
    }
  }

  for (final type in OverlayNotificationType.values) {
    testWidgets('${type.name} host style refreshes through kept handle', (
      tester,
    ) async {
      var progress = 0;
      Widget style(String message) => Text('$message progress=$progress');
      final integration = SuperOverlay.integration(
        notifyStyle: NotifyStyle(
          successBuilder: style,
          failureBuilder: style,
          warningBuilder: style,
          errorBuilder: style,
          alertBuilder: style,
        ),
      );
      await _mount(tester, integration);
      final original = _notify(type);
      await tester.pumpAndSettle();
      expect(find.text('message progress=0'), findsOneWidget);
      var unusedBuilds = 0;
      final kept = _notify(
        type,
        strategy: OverlayStrategy.keepExisting,
        builder: (_) {
          unusedBuilds++;
          return const Text('unused');
        },
      );
      progress = 1;
      kept.refresh();
      await tester.pump();
      final updated = find.text('message progress=1').evaluate().length;
      final closing = kept.close();
      await tester.pumpAndSettle();
      await closing;
      await original.closed;
      await _dispose(tester, integration);
      expect(updated, 1);
      expect(unusedBuilds, 0);
    });
  }

  testWidgets('explicit notify builder bypasses the host factory', (
    tester,
  ) async {
    var hostCalls = 0;
    final integration = SuperOverlay.integration(
      notifyStyle: NotifyStyle(
        successBuilder: (_) {
          hostCalls++;
          return const Text('host');
        },
      ),
    );
    await _mount(tester, integration);
    final handle = _notify(
      OverlayNotificationType.success,
      builder: (_) => const Text('explicit'),
    );
    await tester.pumpAndSettle();
    expect(find.text('explicit'), findsOneWidget);
    await _dispose(tester, integration);
    await handle.closed;
    expect(hostCalls, 0);
  });

  testWidgets('missing notify style falls back to package content', (
    tester,
  ) async {
    final integration = SuperOverlay.integration(
      notifyStyle: const NotifyStyle(),
    );
    await _mount(tester, integration);
    final handle = _notify(OverlayNotificationType.success);
    await tester.pumpAndSettle();
    expect(find.text('message'), findsOneWidget);
    await _dispose(tester, integration);
    await handle.closed;
  });

  for (final surface in ['dialog', 'loading']) {
    testWidgets('$surface names its semantic route with an explicit label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final integration = SuperOverlay.integration();
      await _mount(tester, integration);
      final handle =
          surface == 'dialog'
              ? SuperOverlay.dialog.show<void>(
                builder: (_, _) => const Text('body'),
                options: const OverlayDialogOptions(
                  semanticsLabel: 'explicit route',
                ),
              )
              : SuperOverlay.loading.show(
                builder: (_) => const Text('body'),
                options: const OverlayLoadingOptions(
                  semanticsLabel: 'explicit route',
                ),
              );
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.bySemanticsLabel('explicit route'));
      // Flutter 3.29 only exposes this flag lookup.
      // ignore: deprecated_member_use
      final named = node.getSemanticsData().hasFlag(SemanticsFlag.namesRoute);
      await _dispose(tester, integration);
      await handle.closed;
      semantics.dispose();
      expect(named, isTrue);
    });
  }

  testWidgets('unlabelled modal preserves the content route name', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final integration = SuperOverlay.integration();
    await _mount(tester, integration);
    final handle = SuperOverlay.dialog.show<void>(
      builder:
          (_, _) => const AlertDialog(
            semanticLabel: 'content route',
            content: Text('body'),
          ),
    );
    await tester.pumpAndSettle();
    final node = tester.getSemantics(find.bySemanticsLabel('content route'));
    // ignore: deprecated_member_use
    expect(node.getSemanticsData().hasFlag(SemanticsFlag.namesRoute), isTrue);
    await _dispose(tester, integration);
    await handle.closed;
    semantics.dispose();
  });

  testWidgets('explicit modal route name takes precedence over AlertDialog', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final integration = SuperOverlay.integration();
    await _mount(tester, integration);
    final handle = SuperOverlay.dialog.show<void>(
      builder:
          (_, _) => const AlertDialog(
            semanticLabel: 'inner route',
            content: Text('body'),
          ),
      options: const OverlayDialogOptions(semanticsLabel: 'outer route'),
    );
    await tester.pumpAndSettle();
    final node = tester.getSemantics(find.bySemanticsLabel('outer route'));
    // Flutter chooses the first named node within the scoped route.
    // ignore: deprecated_member_use
    expect(node.getSemanticsData().hasFlag(SemanticsFlag.namesRoute), isTrue);
    expect(node.getSemanticsData().label, 'outer route');
    await _dispose(tester, integration);
    await handle.closed;
    semantics.dispose();
  });
}
