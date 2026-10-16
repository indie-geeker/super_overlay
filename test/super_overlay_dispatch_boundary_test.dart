import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

enum _Boundary { overlay, content, application }

enum _Rewrite { discard, wrap }

class _WrappedValue {
  const _WrappedValue(this.value);
  final Object? value;
}

Object? _unwrap(Object? value) {
  while (value is _WrappedValue) {
    value = value.value;
  }
  return value;
}

class _ApplicationAction extends ContextAction<DismissIntent> {
  Object? value = KeyEventResult.ignored;
  bool enabled = true;
  int calls = 0;
  VoidCallback? onInvoke;
  final converted = <Object?>[];

  @override
  bool isEnabled(DismissIntent intent, [BuildContext? context]) => enabled;

  @override
  Object? invoke(DismissIntent intent, [BuildContext? context]) {
    calls++;
    onInvoke?.call();
    return value;
  }

  @override
  KeyEventResult toKeyEventResult(DismissIntent intent, Object? invokeResult) {
    converted.add(invokeResult);
    final value = _unwrap(invokeResult);
    return value is KeyEventResult ? value : KeyEventResult.ignored;
  }
}

class _BoundaryDispatcher extends ActionDispatcher {
  _Rewrite? rewrite;
  bool intercept = false;
  bool refuse = false;
  bool throwBeforeOnce = false;
  bool throwAfterOnce = false;
  Object? interceptionValue;
  VoidCallback? before;
  VoidCallback? after;
  int _depth = 0;
  int outerCalls = 0;
  Object? lastReturnedValue;

  @override
  (bool, Object?) invokeActionIfEnabled(
    Action<Intent> action,
    Intent intent, [
    BuildContext? context,
  ]) {
    if (intent is! DismissIntent) {
      return super.invokeActionIfEnabled(action, intent, context);
    }
    _depth++;
    try {
      if (_depth != 1) {
        return super.invokeActionIfEnabled(action, intent, context);
      }
      outerCalls++;
      if (throwBeforeOnce) {
        throwBeforeOnce = false;
        throw StateError('before dispatcher invocation');
      }
      if (intercept || refuse) {
        lastReturnedValue = interceptionValue;
        return (!refuse, interceptionValue);
      }
      before?.call();
      final result = super.invokeActionIfEnabled(action, intent, context);
      after?.call();
      if (throwAfterOnce) {
        throwAfterOnce = false;
        throw StateError('after dispatcher invocation');
      }
      lastReturnedValue = switch (rewrite) {
        _Rewrite.discard => null,
        _Rewrite.wrap => _WrappedValue(result.$2),
        null => result.$2,
      };
      return (result.$1, lastReturnedValue);
    } finally {
      _depth--;
    }
  }
}

class _Harness {
  _Harness(this.boundary);

  final _Boundary boundary;
  final integration = SuperOverlay.integration();
  final navigator = GlobalKey<NavigatorState>();
  final focus = FocusNode();
  final pageFocus = FocusNode();
  final application = _ApplicationAction();
  final dispatcher = _BoundaryDispatcher();
  int rawEscapes = 0;

  Future<void> mount(WidgetTester tester) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      integration.dispose();
      focus.dispose();
      pageFocus.dispose();
    });
    await tester.pumpWidget(
      CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => rawEscapes++,
        },
        child: Actions(
          actions: {DismissIntent: application},
          child: MaterialApp(
            navigatorKey: navigator,
            shortcuts: {
              if (boundary == _Boundary.application)
                const SingleActivator(LogicalKeyboardKey.escape):
                    const DismissIntent(),
            },
            builder: integration.builder,
            navigatorObservers: [integration.observer],
            home: Scaffold(
              body: Focus(focusNode: pageFocus, child: const Text('base page')),
            ),
          ),
        ),
      ),
    );
  }

  Widget content() {
    Widget result = Actions(
      dispatcher: dispatcher,
      actions: const <Type, Action<Intent>>{},
      child: Focus(focusNode: focus, child: const Text('focused content')),
    );
    if (boundary == _Boundary.content) {
      // Observe leakage before SuperOverlay's own shortcut can retry the key.
      result = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () => rawEscapes++,
        },
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
          },
          child: result,
        ),
      );
    }
    return result;
  }

  OverlayHandle<void> show(String surface, OverlayBackBehavior behavior) {
    final child = content();
    return switch (surface) {
      'popup' => SuperOverlay.popup.show<void>(
        builder: (_, _) => child,
        options: OverlayPopupOptions(
          requestFocus: true,
          backBehavior: behavior,
          targetPointBuilder: (_, _) => const Offset(240, 180),
        ),
      ),
      'loading' => SuperOverlay.loading.show(
        builder: (_) => child,
        options: OverlayLoadingOptions(backBehavior: behavior),
      ),
      _ => SuperOverlay.dialog.show<void>(
        builder: (_, _) => child,
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

  OverlayHandle<void> addBlocker() => SuperOverlay.dialog.show<void>(
    builder: (_, _) => const Text('new back consumer'),
    options: const OverlayDialogOptions(
      requestFocus: false,
      backBehavior: OverlayBackBehavior.block,
    ),
  );

  Object? invokeDismissal() =>
      Actions.invoke(focus.context!, const DismissIntent());
}

void _dispatchKeyBatch(List<KeyEvent> events) {
  // These SDKs deliver multiple modern key events in one legacy KeyMessage.
  // Exercise that supported batching directly without changing keyboard state.
  // ignore: deprecated_member_use
  final message = KeyMessage(events, null);
  // ignore: deprecated_member_use
  ServicesBinding.instance.keyEventManager.keyMessageHandler!(message);
}

void main() {
  for (final surface in ['dialog', 'popup', 'loading']) {
    for (final behavior in [
      OverlayBackBehavior.block,
      OverlayBackBehavior.dismiss,
    ]) {
      for (final rewrite in _Rewrite.values) {
        testWidgets(
          '$surface native content shortcuts retain ${behavior.name} after ${rewrite.name}',
          (tester) async {
            final harness = _Harness(_Boundary.content);
            harness.dispatcher.rewrite = rewrite;
            await harness.mount(tester);
            final handle = harness.show(surface, behavior);
            await harness.focusContent(tester);
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            expect(harness.rawEscapes, 0);
            expect(harness.application.calls, 0);
            expect(harness.dispatcher.outerCalls, 1);
            expect(handle.isVisible, behavior == OverlayBackBehavior.block);
          },
        );
      }
    }

    for (final boundary in [_Boundary.overlay, _Boundary.content]) {
      for (final reenterBefore in [true, false]) {
        testWidgets(
          '$surface ${boundary.name} consumes a changing back target, reenter before=$reenterBefore',
          (tester) async {
            final harness = _Harness(boundary);
            await harness.mount(tester);
            harness.show(surface, OverlayBackBehavior.passThrough);
            await harness.focusContent(tester);
            OverlayHandle<void>? blocker;
            harness.application.onInvoke = () {
              blocker ??= harness.addBlocker();
            };
            if (reenterBefore) {
              harness.dispatcher.before = harness.invokeDismissal;
            } else {
              harness.dispatcher.after = harness.invokeDismissal;
            }
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            expect(harness.application.calls, 1);
            expect(blocker?.isVisible, isTrue);
            // Either the originating invocation or the dispatcher's explicit
            // nested invocation has consumed back during this same key.
            expect(harness.rawEscapes, 0);
          },
        );
      }
    }
  }

  for (final boundary in _Boundary.values) {
    for (final result in KeyEventResult.values) {
      testWidgets(
        '${boundary.name} converts the final dispatcher value for ${result.name}',
        (tester) async {
          final harness = _Harness(boundary);
          harness.application.value = result;
          harness.dispatcher.rewrite = _Rewrite.wrap;
          await harness.mount(tester);
          harness.show('dialog', OverlayBackBehavior.passThrough);
          await harness.focusContent(tester);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          expect(harness.rawEscapes, result == KeyEventResult.ignored ? 1 : 0);
          final expectedCalls =
              boundary == _Boundary.application &&
                      result == KeyEventResult.ignored
                  ? 2
                  : 1;
          expect(harness.application.calls, expectedCalls);
          expect(harness.application.converted, hasLength(expectedCalls));
          expect(
            harness.application.converted.last,
            same(harness.dispatcher.lastReturnedValue),
          );
        },
      );
    }

    for (final before in [true, false]) {
      testWidgets(
        '${boundary.name} nested pure app action preserves final dispatcher value, before=$before',
        (tester) async {
          final harness = _Harness(boundary);
          harness.application.value = KeyEventResult.handled;
          harness.dispatcher.rewrite = _Rewrite.wrap;
          await harness.mount(tester);
          harness.show('dialog', OverlayBackBehavior.passThrough);
          await harness.focusContent(tester);
          if (before) {
            harness.dispatcher.before = harness.invokeDismissal;
          } else {
            harness.dispatcher.after = harness.invokeDismissal;
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          expect(harness.application.calls, 2);
          expect(harness.rawEscapes, 0);
          expect(
            harness.application.converted.single,
            same(harness.dispatcher.lastReturnedValue),
          );
        },
      );
    }

    for (final refuse in [false, true]) {
      testWidgets(
        '${boundary.name} disabled application permits dispatcher interception, refuse=$refuse',
        (tester) async {
          final harness = _Harness(boundary);
          harness.application.enabled = false;
          harness.dispatcher
            ..intercept = !refuse
            ..refuse = refuse
            ..interceptionValue = KeyEventResult.handled;
          await harness.mount(tester);
          harness.show('dialog', OverlayBackBehavior.passThrough);
          await harness.focusContent(tester);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          expect(harness.application.calls, 0);
          expect(harness.rawEscapes, refuse ? 1 : 0);
          expect(
            harness.dispatcher.outerCalls,
            boundary == _Boundary.application && refuse ? 2 : 1,
          );
        },
      );
    }

    testWidgets(
      '${boundary.name} programmatic calls preserve original Future values',
      (tester) async {
        final harness = _Harness(boundary);
        final original = Future<Object>.value(Object());
        harness.application.value = original;
        await harness.mount(tester);
        harness.show('dialog', OverlayBackBehavior.passThrough);
        await harness.focusContent(tester);
        expect(harness.invokeDismissal(), same(original));
        await original;
        expect(harness.application.converted, isEmpty);
      },
    );

    for (final rewrite in _Rewrite.values) {
      testWidgets(
        '${boundary.name} earlier programmatic back cannot consume next intercepted key, ${rewrite.name}',
        (tester) async {
          final harness = _Harness(boundary);
          await harness.mount(tester);
          final first = harness.show('dialog', OverlayBackBehavior.block);
          await harness.focusContent(tester);
          final back = harness.invokeDismissal();
          expect(back, isA<Future<bool>>());
          await (back as Future<bool>);
          final close = first.close();
          await tester.pumpAndSettle();
          await close;
          harness.show('dialog', OverlayBackBehavior.passThrough);
          await harness.focusContent(tester);
          harness.dispatcher
            ..intercept = true
            ..interceptionValue =
                rewrite == _Rewrite.wrap
                    ? const _WrappedValue(KeyEventResult.ignored)
                    : null;
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          expect(harness.rawEscapes, 1);
          expect(harness.application.calls, 0);
        },
      );
    }

    for (final throwBefore in [true, false]) {
      testWidgets(
        '${boundary.name} dispatcher failure cannot pollute the following key, before=$throwBefore',
        (tester) async {
          final harness = _Harness(boundary);
          await harness.mount(tester);
          harness.show('dialog', OverlayBackBehavior.passThrough);
          await harness.focusContent(tester);
          harness.dispatcher
            ..throwBeforeOnce = throwBefore
            ..throwAfterOnce = !throwBefore;
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          expect(tester.takeException(), isStateError);
          final rawBeforeNextKey = harness.rawEscapes;
          harness.dispatcher.intercept = true;
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          expect(harness.rawEscapes, rawBeforeNextKey + 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final boundary in [_Boundary.overlay, _Boundary.content]) {
    testWidgets(
      '${boundary.name} a failure after consuming back does not taint a later key',
      (tester) async {
        final harness = _Harness(boundary);
        await harness.mount(tester);
        final first = harness.show('dialog', OverlayBackBehavior.block);
        await harness.focusContent(tester);
        harness.dispatcher.throwAfterOnce = true;
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(tester.takeException(), isStateError);
        final close = first.close();
        await tester.pumpAndSettle();
        await close;
        harness.show('dialog', OverlayBackBehavior.passThrough);
        await harness.focusContent(tester);
        harness.dispatcher
          ..intercept = true
          ..interceptionValue = const _WrappedValue(KeyEventResult.ignored);
        final rawBeforeNextKey = harness.rawEscapes;
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(harness.rawEscapes, rawBeforeNextKey + 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final escapeFirst in [true, false]) {
    testWidgets(
      'native shortcut handles batched Escape, escape first=$escapeFirst',
      (tester) async {
        final harness = _Harness(_Boundary.content);
        harness.dispatcher.rewrite = _Rewrite.wrap;
        await harness.mount(tester);
        final handle = harness.show('dialog', OverlayBackBehavior.block);
        await harness.focusContent(tester);
        const escape = KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.escape,
          logicalKey: LogicalKeyboardKey.escape,
          timeStamp: Duration.zero,
        );
        _dispatchKeyBatch([
          if (escapeFirst) escape,
          if (escapeFirst)
            const KeyUpEvent(
              physicalKey: PhysicalKeyboardKey.keyA,
              logicalKey: LogicalKeyboardKey.keyA,
              timeStamp: Duration.zero,
              synthesized: true,
            )
          else
            const KeyDownEvent(
              physicalKey: PhysicalKeyboardKey.keyA,
              logicalKey: LogicalKeyboardKey.keyA,
              timeStamp: Duration.zero,
              synthesized: true,
            ),
          if (!escapeFirst) escape,
        ]);
        expect(harness.rawEscapes, 0);
        expect(harness.dispatcher.outerCalls, 1);
        expect(harness.application.calls, 0);
        expect(handle.isVisible, isTrue);
      },
    );
  }

  testWidgets(
    'native key batches do not retain consumption in the next batch',
    (tester) async {
      final harness = _Harness(_Boundary.content);
      harness.dispatcher.rewrite = _Rewrite.wrap;
      await harness.mount(tester);
      final first = harness.show('dialog', OverlayBackBehavior.block);
      await harness.focusContent(tester);
      const escapeDown = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.escape,
        timeStamp: Duration.zero,
      );
      const escapeUp = KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.escape,
        timeStamp: Duration.zero,
      );
      _dispatchKeyBatch([escapeDown, escapeUp]);
      expect(harness.rawEscapes, 0);
      final close = first.close();
      await tester.pumpAndSettle();
      await close;
      harness.show('dialog', OverlayBackBehavior.passThrough);
      await harness.focusContent(tester);
      harness.dispatcher
        ..intercept = true
        ..interceptionValue = null;
      final callsBeforeUnrelatedBatch = harness.dispatcher.outerCalls;
      _dispatchKeyBatch(const [
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.keyA,
          timeStamp: Duration.zero,
        ),
        KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.keyA,
          timeStamp: Duration.zero,
        ),
      ]);
      expect(harness.dispatcher.outerCalls, callsBeforeUnrelatedBatch);
      expect(harness.rawEscapes, 0);
      _dispatchKeyBatch([escapeDown, escapeUp]);
      expect(harness.dispatcher.outerCalls, callsBeforeUnrelatedBatch + 1);
      expect(harness.rawEscapes, 1);
      expect(harness.application.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final retargetInEarlyHandler in [false, true]) {
    testWidgets(
      'native shortcut respects focus chosen later in the key event, retarget=$retargetInEarlyHandler',
      (tester) async {
        final harness = _Harness(_Boundary.content);
        harness.dispatcher.rewrite = _Rewrite.wrap;
        await harness.mount(tester);
        final handle = harness.show('dialog', OverlayBackBehavior.block);
        await harness.focusContent(tester);
        if (retargetInEarlyHandler) {
          harness.pageFocus.requestFocus();
          await tester.pump();
          expect(harness.pageFocus.hasFocus, isTrue);
          KeyEventResult retarget(KeyEvent event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              harness.focus.requestFocus();
              FocusManager.instance.applyFocusChangesIfNeeded();
            }
            return KeyEventResult.ignored;
          }

          FocusManager.instance.addEarlyKeyEventHandler(retarget);
          addTearDown(
            () => FocusManager.instance.removeEarlyKeyEventHandler(retarget),
          );
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(harness.focus.hasFocus, isTrue);
        expect(handle.isVisible, isTrue);
        expect(harness.rawEscapes, 0);
        expect(harness.application.calls, 0);
        expect(harness.dispatcher.outerCalls, 1);
      },
    );
  }

  testWidgets('focus outside the overlay leaves Escape with the page', (
    tester,
  ) async {
    final harness = _Harness(_Boundary.content);
    await harness.mount(tester);
    final handle = harness.show('dialog', OverlayBackBehavior.block);
    await harness.focusContent(tester);
    harness.pageFocus.requestFocus();
    await tester.pump();
    expect(harness.pageFocus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(harness.rawEscapes, 1);
    expect(harness.dispatcher.outerCalls, 0);
    expect(handle.isVisible, isTrue);
    await harness.focusContent(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(harness.rawEscapes, 1);
    expect(handle.isVisible, isTrue);
  });

  testWidgets(
    'removing an overlay host leaves subsequent key delivery intact',
    (tester) async {
      final harness = _Harness(_Boundary.content);
      final replacementFocus = FocusNode();
      addTearDown(replacementFocus.dispose);
      await harness.mount(tester);
      harness.show('dialog', OverlayBackBehavior.block);
      await harness.focusContent(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(harness.rawEscapes, 0);
      var replacementKeys = 0;
      await tester.pumpWidget(
        MaterialApp(
          shortcuts: const <ShortcutActivator, Intent>{},
          home: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape):
                  () => replacementKeys++,
            },
            child: Focus(
              focusNode: replacementFocus,
              child: const Text('replacement host'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      replacementFocus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(replacementKeys, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native ancestor shortcut retains a new consumer after the local app branch',
    (tester) async {
      final harness = _Harness(_Boundary.application);
      await harness.mount(tester);
      harness.show('dialog', OverlayBackBehavior.passThrough);
      await harness.focusContent(tester);
      OverlayHandle<void>? blocker;
      harness.application.onInvoke = () => blocker ??= harness.addBlocker();
      harness.dispatcher.rewrite = _Rewrite.discard;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(harness.application.calls, 1);
      expect(blocker?.isVisible, isTrue);
      expect(harness.rawEscapes, 0);
      expect(harness.dispatcher.outerCalls, 2);
    },
  );

  for (final rewrite in _Rewrite.values) {
    testWidgets('native Dialog consumes Escape after ${rewrite.name}', (
      tester,
    ) async {
      final harness = _Harness(_Boundary.content);
      harness.dispatcher.rewrite = rewrite;
      await harness.mount(tester);
      // Native Flutter supplies its own route dismissal action, so this is an
      // independent control of the public dispatcher/ShortcutManager protocol.
      showDialog<void>(
        context: harness.navigator.currentContext!,
        builder: (_) => harness.content(),
      );
      await harness.focusContent(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(harness.rawEscapes, 0);
      expect(harness.application.calls, 0);
      expect(find.text('focused content'), findsNothing);
    });
  }
}
