import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

Future<void> _mount(
  WidgetTester tester, {
  Widget? home,
  ThemeData? theme,
}) async {
  final integration = SuperOverlay.integration();
  addTearDown(integration.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: integration.builder,
      navigatorObservers: [integration.observer],
      home: home ?? const Scaffold(body: SizedBox.shrink()),
    ),
  );
}

void main() {
  for (final surface in [
    'loading',
    'notification',
    'dialog',
    'popup',
    'toast',
  ]) {
    testWidgets('$surface handle refresh rebuilds visible content', (
      tester,
    ) async {
      await _mount(tester);
      var progress = 0;
      Widget content(BuildContext context) => Text('progress=$progress');
      final OverlayHandle<void> handle = switch (surface) {
        'loading' => SuperOverlay.loading.show(builder: content),
        'notification' => SuperOverlay.notify.success(
          'progress',
          builder: content,
          options: const OverlayNotifyOptions(
            displayDuration: Duration(minutes: 1),
          ),
        ),
        'dialog' => SuperOverlay.dialog.show<void>(builder: content),
        'popup' => SuperOverlay.popup.show<void>(
          builder: content,
          options: OverlayPopupOptions(
            targetPointBuilder: (_, _) => const Offset(100, 100),
          ),
        ),
        _ => SuperOverlay.toast(
          'progress',
          builder: content,
          options: const OverlayToastOptions(
            displayDuration: Duration(minutes: 1),
          ),
        ),
      };
      await tester.pumpAndSettle();
      expect(find.text('progress=0'), findsOneWidget);
      progress = 1;
      handle.refresh();
      await tester.pump();
      final refreshed = find.text('progress=1').evaluate().length;
      final closing = handle.close();
      await tester.pumpAndSettle();
      await closing;
      expect(
        refreshed,
        1,
        reason: 'handle.refresh must invoke the original content builder',
      );
    });
  }

  testWidgets('null notification duration disables automatic dismissal', (
    tester,
  ) async {
    await _mount(tester);
    final handle = SuperOverlay.notify.success(
      'persistent',
      options: const OverlayNotifyOptions(displayDuration: null),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    final visibleAfterThreeSeconds = handle.isVisible;
    final closing = handle.close();
    await tester.pumpAndSettle();
    await closing;
    expect(visibleAfterThreeSeconds, isTrue);
  });

  testWidgets('popup stays above keyboard by default', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    late BuildContext target;
    await _mount(
      tester,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Builder(
            builder: (context) {
              target = context;
              return const SizedBox(width: 100, height: 40);
            },
          ),
        ),
      ),
    );
    final handle = SuperOverlay.popup.show<void>(
      targetContext: target,
      builder:
          (_) =>
              const SizedBox(key: ValueKey('popup'), width: 180, height: 160),
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byKey(const ValueKey('popup')));
    final closing = handle.close();
    await tester.pumpAndSettle();
    await closing;
    expect(
      rect.bottom,
      lessThanOrEqualTo(500),
      reason: 'keyboard covers y=500..800, popup rect=$rect',
    );
  });

  for (final surface in ['dialog', 'popup']) {
    testWidgets('suspended $surface preserves form state on resume', (
      tester,
    ) async {
      late BuildContext caller;
      await _mount(
        tester,
        home: Builder(
          builder: (context) {
            caller = context;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      );
      final navigator = Navigator.of(caller);
      Widget content(BuildContext context) => const SizedBox(
        width: 200,
        height: 100,
        child: TextField(key: ValueKey('draft')),
      );
      final scoped = SuperOverlay.of(caller);
      final handle =
          surface == 'dialog'
              ? scoped.dialog.show<void>(builder: content)
              : scoped.popup.show<void>(
                builder: content,
                options: OverlayPopupOptions(
                  targetPointBuilder: (_, _) => const Offset(100, 100),
                ),
              );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('draft')),
        'unsaved draft',
      );
      navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
      await tester.pumpAndSettle();
      expect(handle.isVisible, isFalse);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(handle.isVisible, isTrue);
      final draftPresent = find.text('unsaved draft').evaluate().isNotEmpty;
      final closing = handle.close();
      await tester.pumpAndSettle();
      await closing;
      expect(
        draftPresent,
        isTrue,
        reason: 'Suspension must not discard the form draft',
      );
    });
  }

  testWidgets('toast returns to original position after keyboard hides', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _mount(tester);
    final handle = SuperOverlay.toast(
      'position',
      builder:
          (_) => const SizedBox(key: ValueKey('toast'), width: 100, height: 40),
      options: const OverlayToastOptions(displayDuration: Duration(minutes: 1)),
    );
    await tester.pumpAndSettle();
    final initial = tester.getRect(find.byKey(const ValueKey('toast')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    final withKeyboard = tester.getRect(find.byKey(const ValueKey('toast')));
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    final after = tester.getRect(find.byKey(const ValueKey('toast')));
    final closing = handle.close();
    await tester.pumpAndSettle();
    await closing;
    expect(withKeyboard.bottom, lessThanOrEqualTo(500));
    expect(
      after,
      initial,
      reason: 'initial=$initial keyboard=$withKeyboard after=$after',
    );
  });

  for (final surface in ['dialog', 'popup', 'replacement', 'adjustment']) {
    testWidgets('scoped $surface inherits caller local theme', (tester) async {
      late BuildContext caller;
      final rootTheme = ThemeData.light();
      await _mount(
        tester,
        theme: rootTheme,
        home: Theme(
          data: ThemeData.dark(),
          child: Builder(
            builder: (context) {
              caller = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      Brightness? actual;
      Widget content(BuildContext context) {
        actual = Theme.of(context).brightness;
        return const SizedBox(width: 100, height: 100);
      }

      final scoped = SuperOverlay.of(caller);
      final handle =
          surface == 'dialog'
              ? scoped.dialog.show<void>(builder: content)
              : scoped.popup.show<void>(
                builder:
                    surface == 'popup'
                        ? content
                        : (_) => const SizedBox(width: 100, height: 100),
                options: OverlayPopupOptions(
                  targetPointBuilder: (_, _) => const Offset(100, 100),
                  replacementBuilder:
                      surface == 'replacement'
                          ? (_) => Builder(builder: content)
                          : null,
                  adjustmentBuilder:
                      surface == 'adjustment'
                          ? (_) => PopupAdjustment(builder: content)
                          : null,
                ),
              );
      await tester.pumpAndSettle();
      final closing = handle.close();
      await tester.pumpAndSettle();
      await closing;
      expect(actual, Brightness.dark);
    });
  }
}
