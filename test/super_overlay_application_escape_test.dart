import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

class _FocusValue extends InheritedWidget {
  const _FocusValue({required super.child});

  @override
  bool updateShouldNotify(_FocusValue oldWidget) => false;
}

class _ApplicationDismiss extends ContextAction<DismissIntent> {
  _ApplicationDismiss(this.result);

  final KeyEventResult result;
  final value = Object();
  bool enabled = true;
  int calls = 0;
  BuildContext? invokedContext;
  Object? convertedValue;
  VoidCallback? onInvoke;
  final enabledContexts = <BuildContext?>[];

  @override
  bool isEnabled(DismissIntent intent, [BuildContext? context]) {
    enabledContexts.add(context);
    return enabled &&
        context?.getInheritedWidgetOfExactType<_FocusValue>() != null;
  }

  @override
  Object? invoke(DismissIntent intent, [BuildContext? context]) {
    calls++;
    invokedContext = context;
    onInvoke?.call();
    return value;
  }

  @override
  KeyEventResult toKeyEventResult(DismissIntent intent, Object? invokeResult) {
    convertedValue = invokeResult;
    return result;
  }
}

class _DisabledContent extends ContextAction<DismissIntent> {
  @override
  bool isEnabled(DismissIntent intent, [BuildContext? context]) => false;

  @override
  Object? invoke(DismissIntent intent, [BuildContext? context]) =>
      throw StateError('Disabled content must not be invoked.');
}

class _PlainApplicationDismiss extends DismissAction {
  _PlainApplicationDismiss(this.result);

  final KeyEventResult result;
  int calls = 0;

  @override
  Object? invoke(DismissIntent intent) {
    calls++;
    return null;
  }

  @override
  KeyEventResult toKeyEventResult(DismissIntent intent, Object? invokeResult) =>
      result;
}

class _RecordingDispatcher extends ActionDispatcher {
  _RecordingDispatcher(this.application);

  final Action<DismissIntent> application;
  final contexts = <BuildContext?>[];

  @override
  (bool, Object?) invokeActionIfEnabled(
    Action<Intent> action,
    Intent intent, [
    BuildContext? context,
  ]) {
    if (identical(action, application)) contexts.add(context);
    return super.invokeActionIfEnabled(action, intent, context);
  }
}

class _ControlledDispatcher extends ActionDispatcher {
  bool intercept = false;
  bool refuse = false;
  Object? interceptionValue;
  int interceptions = 0;
  int depth = 0;
  bool reenterAfterInvoke = false;
  bool throwOnce = false;
  KeyEventResult? replaceResult;

  @override
  (bool, Object?) invokeActionIfEnabled(
    Action<Intent> action,
    Intent intent, [
    BuildContext? context,
  ]) {
    if (throwOnce) {
      throwOnce = false;
      throw StateError('dispatcher failure');
    }
    if (intent is DismissIntent && (intercept || refuse)) {
      interceptions++;
      return (!refuse, interceptionValue);
    }
    depth++;
    try {
      final result = super.invokeActionIfEnabled(action, intent, context);
      if (depth == 1 && result.$1) {
        if (reenterAfterInvoke) {
          super.invokeActionIfEnabled(action, intent, context);
        }
        if (replaceResult != null) return (true, replaceResult);
      }
      return result;
    } finally {
      depth--;
    }
  }
}

class _ResultDismiss extends ContextAction<DismissIntent> {
  int calls = 0;
  Object? value;
  VoidCallback? onInvoke;
  bool changeResultOnReentry = false;

  @override
  Object? invoke(DismissIntent intent, [BuildContext? context]) {
    calls++;
    final result =
        changeResultOnReentry
            ? (calls == 1 ? KeyEventResult.handled : KeyEventResult.ignored)
            : value;
    onInvoke?.call();
    return result;
  }

  @override
  KeyEventResult toKeyEventResult(DismissIntent intent, Object? invokeResult) =>
      invokeResult is KeyEventResult ? invokeResult : KeyEventResult.ignored;
}

class _Harness {
  final integration = SuperOverlay.integration();
  final focus = FocusNode();
  int rawEscapes = 0;

  Future<void> mount(WidgetTester tester, Action<DismissIntent> action) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      integration.dispose();
      focus.dispose();
    });
    await tester.pumpWidget(
      CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => rawEscapes++,
        },
        child: Actions(
          actions: {DismissIntent: action},
          child: MaterialApp(
            // Isolate this shortcut boundary from WidgetsApp's own Escape map.
            shortcuts: const <ShortcutActivator, Intent>{},
            builder: integration.builder,
            navigatorObservers: [integration.observer],
            home: const Scaffold(body: Text('base page')),
          ),
        ),
      ),
    );
  }

  OverlayHandle<void> show(
    String surface,
    OverlayBackBehavior behavior, {
    bool disabledContent = false,
    ActionDispatcher? dispatcher,
    bool contentShortcuts = false,
  }) {
    Widget content = _FocusValue(
      child: Focus(focusNode: focus, child: const Text('focused value')),
    );
    if (disabledContent || dispatcher != null) {
      content = Actions(
        dispatcher: dispatcher,
        actions: {if (disabledContent) DismissIntent: _DisabledContent()},
        child: content,
      );
    }
    if (contentShortcuts) {
      content = Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        },
        child: content,
      );
    }
    return switch (surface) {
      'popup' => SuperOverlay.popup.show<void>(
        builder: (_, _) => content,
        options: OverlayPopupOptions(
          requestFocus: true,
          backBehavior: behavior,
          targetPointBuilder: (_, _) => const Offset(240, 180),
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
  }

  Future<void> focusContent(WidgetTester tester) async {
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  }
}

void main() {
  for (final surface in ['dialog', 'popup', 'loading']) {
    testWidgets('$surface does not retry a dispatcher-disabled bridge', (
      tester,
    ) async {
      final harness = _Harness();
      final action = _PlainApplicationDismiss(KeyEventResult.handled);
      final dispatcher = _ControlledDispatcher()..refuse = true;
      await harness.mount(tester, action);
      harness.show(
        surface,
        OverlayBackBehavior.passThrough,
        dispatcher: dispatcher,
      );
      await harness.focusContent(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(dispatcher.interceptions, 1);
      expect(action.calls, 0);
      expect(harness.rawEscapes, 1);
    });
    for (final result in KeyEventResult.values) {
      testWidgets('$surface nested native shortcuts preserve ${result.name}', (
        tester,
      ) async {
        final harness = _Harness();
        final action = _PlainApplicationDismiss(result);
        await harness.mount(tester, action);
        harness.show(
          surface,
          OverlayBackBehavior.passThrough,
          contentShortcuts: true,
        );
        await harness.focusContent(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(action.calls, result == KeyEventResult.ignored ? 2 : 1);
        expect(harness.rawEscapes, result == KeyEventResult.ignored ? 1 : 0);
      });
    }
    for (final behavior in [
      OverlayBackBehavior.dismiss,
      OverlayBackBehavior.block,
    ]) {
      testWidgets(
        '$surface nested native shortcuts retain $behavior priority',
        (tester) async {
          final harness = _Harness();
          final action = _PlainApplicationDismiss(KeyEventResult.ignored);
          await harness.mount(tester, action);
          final handle = harness.show(
            surface,
            behavior,
            contentShortcuts: true,
          );
          await harness.focusContent(tester);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(action.calls, 0);
          expect(harness.rawEscapes, 0);
          expect(handle.isVisible, behavior == OverlayBackBehavior.block);
        },
      );
    }
    for (final behavior in OverlayBackBehavior.values) {
      for (final disabledContent in [false, true]) {
        testWidgets(
          '$surface $behavior honors dispatcher interception, disabled content=$disabledContent',
          (tester) async {
            final harness = _Harness();
            final action = _PlainApplicationDismiss(KeyEventResult.handled);
            final dispatcher = _ControlledDispatcher()..intercept = true;
            await harness.mount(tester, action);
            final handle = harness.show(
              surface,
              behavior,
              disabledContent: disabledContent,
              dispatcher: dispatcher,
            );
            await harness.focusContent(tester);
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            expect(dispatcher.interceptions, 1);
            expect(action.calls, 0);
            expect(harness.rawEscapes, 0);
            expect(handle.isVisible, isTrue);
          },
        );
      }
    }
    testWidgets(
      '$surface interception does not reuse the previous ignored key',
      (tester) async {
        final harness = _Harness();
        final action = _PlainApplicationDismiss(KeyEventResult.ignored);
        final dispatcher = _ControlledDispatcher();
        await harness.mount(tester, action);
        harness.show(
          surface,
          OverlayBackBehavior.passThrough,
          dispatcher: dispatcher,
        );
        await harness.focusContent(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(harness.rawEscapes, 1);
        dispatcher.intercept = true;
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(dispatcher.interceptions, 1);
        expect(action.calls, 1);
        expect(harness.rawEscapes, 2);
      },
    );

    for (final reenter in [false, true]) {
      testWidgets(
        '$surface converts the outer dispatcher result, reenter=$reenter',
        (tester) async {
          final harness = _Harness();
          final action = _ResultDismiss()..changeResultOnReentry = reenter;
          final dispatcher =
              _ControlledDispatcher()
                ..reenterAfterInvoke = reenter
                ..replaceResult =
                    reenter ? null : KeyEventResult.skipRemainingHandlers;
          await harness.mount(tester, action);
          harness.show(
            surface,
            OverlayBackBehavior.passThrough,
            dispatcher: dispatcher,
          );
          await harness.focusContent(tester);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          expect(action.calls, reenter ? 2 : 1);
          expect(harness.rawEscapes, 0);
        },
      );
    }

    testWidgets(
      '$surface app side effect cannot change the originating key result',
      (tester) async {
        final harness = _Harness();
        final action = _ResultDismiss()..value = KeyEventResult.ignored;
        await harness.mount(tester, action);
        harness.show(surface, OverlayBackBehavior.passThrough);
        await harness.focusContent(tester);
        action.onInvoke =
            () => SuperOverlay.dialog.show<void>(
              builder: (_, _) => const Text('new consumer'),
              options: const OverlayDialogOptions(requestFocus: false),
            );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(action.calls, 1);
        expect(harness.rawEscapes, 1);
      },
    );

    testWidgets('$surface programmatic dismissal retains a Future result', (
      tester,
    ) async {
      final harness = _Harness();
      final future = Future<Object>.value(Object());
      final action = _ResultDismiss()..value = future;
      await harness.mount(tester, action);
      harness.show(surface, OverlayBackBehavior.passThrough);
      await harness.focusContent(tester);
      expect(
        Actions.invoke(harness.focus.context!, const DismissIntent()),
        same(future),
      );
      await future;
    });
  }

  testWidgets(
    'a throwing dispatcher does not retain the previous key boundary',
    (tester) async {
      final harness = _Harness();
      final action = _PlainApplicationDismiss(KeyEventResult.ignored);
      final dispatcher = _ControlledDispatcher()..throwOnce = true;
      await harness.mount(tester, action);
      harness.show(
        'dialog',
        OverlayBackBehavior.passThrough,
        dispatcher: dispatcher,
      );
      await harness.focusContent(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(tester.takeException(), isStateError);
      final raw = harness.rawEscapes;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(action.calls, 1);
      expect(harness.rawEscapes, raw + 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final surface in ['dialog', 'popup', 'loading']) {
    for (final result in KeyEventResult.values) {
      testWidgets('$surface preserves plain app action ${result.name}', (
        tester,
      ) async {
        final harness = _Harness();
        final action = _PlainApplicationDismiss(result);
        await harness.mount(tester, action);
        final handle = harness.show(surface, OverlayBackBehavior.passThrough);
        await harness.focusContent(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(action.calls, 1);
        expect(harness.rawEscapes, result == KeyEventResult.ignored ? 1 : 0);
        expect(handle.isVisible, isTrue);
      });
    }

    for (final result in KeyEventResult.values) {
      for (final disabledContent in [false, true]) {
        testWidgets(
          '$surface forwards app ${result.name} with focus context, disabled content=$disabledContent',
          (tester) async {
            final harness = _Harness();
            final action = _ApplicationDismiss(result);
            final dispatcher = _RecordingDispatcher(action);
            await harness.mount(tester, action);
            final handle = harness.show(
              surface,
              OverlayBackBehavior.passThrough,
              disabledContent: disabledContent,
              dispatcher: dispatcher,
            );
            await harness.focusContent(tester);
            final target = harness.focus.context;
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            expect(action.calls, 1);
            expect(action.invokedContext, same(target));
            expect(action.enabledContexts, isNotEmpty);
            expect(action.enabledContexts, everyElement(same(target)));
            expect(action.convertedValue, same(action.value));
            expect(dispatcher.contexts, [same(target)]);
            expect(
              harness.rawEscapes,
              result == KeyEventResult.ignored ? 1 : 0,
            );
            expect(handle.isVisible, isTrue);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    for (final behavior in [
      OverlayBackBehavior.dismiss,
      OverlayBackBehavior.block,
    ]) {
      testWidgets('$surface $behavior takes precedence over app action', (
        tester,
      ) async {
        final harness = _Harness();
        final action = _ApplicationDismiss(KeyEventResult.ignored);
        await harness.mount(tester, action);
        final handle = harness.show(surface, behavior, disabledContent: true);
        await harness.focusContent(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(action.calls, 0);
        expect(harness.rawEscapes, 0);
        expect(handle.isVisible, behavior == OverlayBackBehavior.block);
      });
    }

    testWidgets(
      '$surface programmatic app dismissal preserves its return value',
      (tester) async {
        final harness = _Harness();
        final action = _ApplicationDismiss(KeyEventResult.ignored);
        await harness.mount(tester, action);
        harness.show(surface, OverlayBackBehavior.passThrough);
        await harness.focusContent(tester);
        final result = Actions.invoke(
          harness.focus.context!,
          const DismissIntent(),
        );
        expect(result, same(action.value));
        expect(action.calls, 1);
        expect(action.invokedContext, same(harness.focus.context));
      },
    );
  }

  testWidgets('reentrant app dismissal keeps the outer key disposition', (
    tester,
  ) async {
    final harness = _Harness();
    final action = _ApplicationDismiss(KeyEventResult.ignored);
    await harness.mount(tester, action);
    harness.show('dialog', OverlayBackBehavior.passThrough);
    await harness.focusContent(tester);
    action.onInvoke = () {
      if (action.calls == 1) {
        final nested = Actions.invoke(
          harness.focus.context!,
          const DismissIntent(),
        );
        expect(nested, same(action.value));
      }
    };
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(action.calls, 2);
    expect(harness.rawEscapes, 1);
  });

  testWidgets(
    'app ContextAction can change enabled state between Escape keys',
    (tester) async {
      final harness = _Harness();
      final action = _ApplicationDismiss(KeyEventResult.handled)
        ..enabled = false;
      await harness.mount(tester, action);
      harness.show('dialog', OverlayBackBehavior.passThrough);
      await harness.focusContent(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(action.calls, 0);
      expect(harness.rawEscapes, 1);
      action.enabled = true;
      action.notifyActionListeners();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(action.calls, 1);
      expect(harness.rawEscapes, 1);
      expect(action.invokedContext, same(harness.focus.context));
    },
  );

  for (final dropdown in [false, true]) {
    testWidgets(
      'editable menu content retains native Escape behavior, dropdown=$dropdown',
      (tester) async {
        Widget menu(FocusNode focus) =>
            dropdown
                ? DropdownMenu<String>(
                  focusNode: focus,
                  requestFocusOnTap: true,
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 'a', label: 'choice'),
                  ],
                )
                : SizedBox(
                  width: 240,
                  child: MenuAnchor(
                    menuChildren: const [MenuItemButton(child: Text('choice'))],
                    builder: (_, _, _) => TextField(focusNode: focus),
                  ),
                );
        final navigator = GlobalKey<NavigatorState>();
        final nativeFocus = FocusNode();
        final overlayFocus = FocusNode();
        final integration = SuperOverlay.integration();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          integration.dispose();
          nativeFocus.dispose();
          overlayFocus.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(navigatorKey: navigator, home: const Scaffold()),
        );
        showDialog<void>(
          context: navigator.currentContext!,
          builder: (_) => AlertDialog(content: menu(nativeFocus)),
        );
        await tester.pumpAndSettle();
        nativeFocus.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        final nativeClosed = find.byType(AlertDialog).evaluate().isEmpty;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          MaterialApp(
            builder: integration.builder,
            navigatorObservers: [integration.observer],
            home: const Scaffold(),
          ),
        );
        final handle = SuperOverlay.dialog.show<void>(
          builder: (_, _) => AlertDialog(content: menu(overlayFocus)),
        );
        await tester.pumpAndSettle();
        overlayFocus.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(handle.isVisible, !nativeClosed);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
