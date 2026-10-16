import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

class _Harness {
  final integration = SuperOverlay.integration();
  final focus = FocusNode();
  int applicationDismissals = 0;
  int rawEscapes = 0;
  int shiftedEscapes = 0;

  Future<void> mount(
    WidgetTester tester, {
    bool applicationAction = true,
  }) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      integration.dispose();
      focus.dispose();
    });
    Widget app = MaterialApp(
      builder: integration.builder,
      navigatorObservers: [integration.observer],
      home: const Scaffold(body: Text('base page')),
    );
    if (applicationAction) {
      app = Actions(
        actions: <Type, Action<Intent>>{
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              applicationDismissals++;
              return null;
            },
          ),
        },
        child: app,
      );
    }
    await tester.pumpWidget(
      CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => rawEscapes++,
          const SingleActivator(LogicalKeyboardKey.escape, shift: true):
              () => shiftedEscapes++,
        },
        child: app,
      ),
    );
    await tester.pumpAndSettle();
  }

  OverlayHandle<void> show(
    String surface,
    OverlayBackBehavior behavior,
    Widget content,
  ) => switch (surface) {
    'popup' => SuperOverlay.popup.show<void>(
      builder: (_, _) => content,
      options: OverlayPopupOptions(
        requestFocus: true,
        targetPointBuilder: (_, _) => const Offset(240, 180),
        backBehavior: behavior,
      ),
    ),
    'loading' => SuperOverlay.loading.show(
      builder: (_) => content,
      options: OverlayLoadingOptions(backBehavior: behavior),
    ),
    _ => SuperOverlay.dialog.show<void>(
      builder: (_, _) => content,
      options: OverlayDialogOptions(backBehavior: behavior),
    ),
  };

  Widget menu() => MenuAnchor(
    childFocusNode: focus,
    menuChildren: [
      MenuItemButton(onPressed: () {}, child: const Text('menu choice')),
    ],
    builder:
        (_, controller, _) => TextButton(
          focusNode: focus,
          onPressed: controller.open,
          child: const Text('menu trigger'),
        ),
  );

  Widget actionContent(Action<DismissIntent> action) => Actions(
    actions: <Type, Action<Intent>>{DismissIntent: action},
    child: Focus(focusNode: focus, child: const Text('content action')),
  );

  Future<void> focusContent(WidgetTester tester) async {
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  }
}

class _ContentDismissAction extends ContextAction<DismissIntent> {
  _ContentDismissAction({
    this.enabled = true,
    this.result = KeyEventResult.handled,
  });
  bool enabled;
  final KeyEventResult result;
  int calls = 0;
  BuildContext? invokedContext;

  @override
  bool isEnabled(DismissIntent intent, [BuildContext? context]) => enabled;

  @override
  Object? invoke(DismissIntent intent, [BuildContext? context]) {
    calls++;
    invokedContext = context;
    return null;
  }

  @override
  KeyEventResult toKeyEventResult(DismissIntent intent, Object? invokeResult) =>
      result;
}

void main() {
  for (final surface in ['dialog', 'popup', 'loading']) {
    for (final behavior in OverlayBackBehavior.values) {
      for (final openFirst in [false, true]) {
        testWidgets(
          '$surface ${behavior.name} after native menu closes, open first=$openFirst',
          (tester) async {
            final harness = _Harness();
            await harness.mount(tester);
            final handle = harness.show(surface, behavior, harness.menu());
            await harness.focusContent(tester);
            if (openFirst) {
              await tester.tap(find.text('menu trigger'));
              await tester.pumpAndSettle();
              harness.focus.requestFocus();
              await tester.pump();
              expect(find.text('menu choice'), findsOneWidget);
              await tester.sendKeyEvent(LogicalKeyboardKey.escape);
              await tester.pumpAndSettle();
              expect(handle.isVisible, isTrue);
              expect(harness.applicationDismissals, 0);
            }
            expect(find.text('menu choice'), findsNothing);
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            expect(handle.isVisible, behavior != OverlayBackBehavior.dismiss);
            expect(
              harness.applicationDismissals,
              behavior == OverlayBackBehavior.passThrough ? 1 : 0,
            );
            expect(harness.rawEscapes, 0);
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant({
            TargetPlatform.android,
            TargetPlatform.macOS,
          }),
        );
      }

      testWidgets(
        '$surface ${behavior.name} falls back from disabled content action',
        (tester) async {
          final harness = _Harness();
          final action = _ContentDismissAction(enabled: false);
          await harness.mount(tester);
          final handle = harness.show(
            surface,
            behavior,
            harness.actionContent(action),
          );
          await harness.focusContent(tester);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(action.calls, 0);
          expect(handle.isVisible, behavior != OverlayBackBehavior.dismiss);
          expect(
            harness.applicationDismissals,
            behavior == OverlayBackBehavior.passThrough ? 1 : 0,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      '$surface passes raw Escape to app when content is disabled and no consumer exists',
      (tester) async {
        final harness = _Harness();
        await harness.mount(tester, applicationAction: false);
        final action = _ContentDismissAction(enabled: false);
        final handle = harness.show(
          surface,
          OverlayBackBehavior.passThrough,
          harness.actionContent(action),
        );
        await harness.focusContent(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(action.calls, 0);
        expect(harness.rawEscapes, 1);
        expect(handle.isVisible, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final result in KeyEventResult.values) {
    for (final behavior in OverlayBackBehavior.values) {
      testWidgets(
        'content result ${result.name} preserves context and ${behavior.name} fallback',
        (tester) async {
          final harness = _Harness();
          final action = _ContentDismissAction(result: result);
          await harness.mount(tester);
          final handle = harness.show(
            'dialog',
            behavior,
            harness.actionContent(action),
          );
          await harness.focusContent(tester);
          final expectedContext = harness.focus.context;
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(action.calls, 1);
          expect(action.invokedContext, same(expectedContext));
          final fallback = result == KeyEventResult.ignored;
          expect(
            handle.isVisible,
            !(fallback && behavior == OverlayBackBehavior.dismiss),
          );
          expect(
            harness.applicationDismissals,
            fallback && behavior == OverlayBackBehavior.passThrough ? 1 : 0,
          );
          expect(harness.rawEscapes, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('modifier Escape is not claimed by overlay fallback', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.mount(tester);
    final handle = harness.show(
      'dialog',
      OverlayBackBehavior.dismiss,
      harness.menu(),
    );
    await harness.focusContent(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(harness.shiftedEscapes, 1);
    expect(handle.isVisible, isTrue);
    expect(tester.takeException(), isNull);
  });
}
