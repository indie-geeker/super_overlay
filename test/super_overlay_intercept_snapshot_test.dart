import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

enum _Boundary { overlay, child, ancestor }

class _DispatchValue {
  const _DispatchValue(this.result);

  final KeyEventResult result;
}

class _ApplicationDismiss extends ContextAction<DismissIntent> {
  Object? value;
  int calls = 0;
  final converted = <Object?>[];

  @override
  Object? invoke(DismissIntent intent, [BuildContext? context]) {
    calls++;
    return value;
  }

  @override
  KeyEventResult toKeyEventResult(DismissIntent intent, Object? invokeResult) {
    converted.add(invokeResult);
    return invokeResult is _DispatchValue
        ? invokeResult.result
        : KeyEventResult.ignored;
  }
}

class _InterceptDispatcher extends ActionDispatcher {
  bool intercept = true;
  VoidCallback? onDispatch;
  Object? returnedValue = const _DispatchValue(KeyEventResult.ignored);
  int calls = 0;
  int _depth = 0;

  @override
  (bool, Object?) invokeActionIfEnabled(
    Action<Intent> action,
    Intent intent, [
    BuildContext? context,
  ]) {
    if (intent is! DismissIntent || _depth != 0) {
      return super.invokeActionIfEnabled(action, intent, context);
    }
    calls++;
    _depth++;
    try {
      onDispatch?.call();
      if (intercept) return (true, returnedValue);
      final (enabled, _) = super.invokeActionIfEnabled(action, intent, context);
      return (enabled, returnedValue);
    } finally {
      _depth--;
    }
  }
}

class _Harness {
  _Harness(this.boundary);

  final _Boundary boundary;
  final integration = SuperOverlay.integration();
  final focus = FocusNode();
  final pageFocus = FocusNode();
  final application = _ApplicationDismiss();
  final dispatcher = _InterceptDispatcher();
  int rawEscapes = 0;

  Future<void> mount(
    WidgetTester tester, {
    bool applicationAction = true,
  }) async {
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
          actions: {if (applicationAction) DismissIntent: application},
          child: MaterialApp(
            shortcuts: {
              if (boundary == _Boundary.ancestor)
                const SingleActivator(LogicalKeyboardKey.escape):
                    const DismissIntent(),
            },
            builder: integration.builder,
            navigatorObservers: [integration.observer],
            home: Scaffold(
              body: Focus(focusNode: pageFocus, child: const Text('page')),
            ),
          ),
        ),
      ),
    );
  }

  Widget content({bool directApplication = false}) {
    Widget result = Actions(
      dispatcher: dispatcher,
      actions: {if (directApplication) DismissIntent: application},
      child: Focus(focusNode: focus, child: const Text('focused content')),
    );
    if (boundary == _Boundary.child) {
      // Catch an ignored native key before the package's own shortcut retries.
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

  OverlayHandle<void> show(
    String surface,
    OverlayBackBehavior behavior, {
    bool directApplication = false,
  }) {
    final child = content(directApplication: directApplication);
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

  OverlayHandle<void> addConsumer(OverlayBackBehavior behavior) =>
      SuperOverlay.dialog.show<void>(
        builder: (_, _) => const Text('added consumer'),
        options: OverlayDialogOptions(
          requestFocus: false,
          backBehavior: behavior,
        ),
      );

  Future<void> focusContent(WidgetTester tester) async {
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  }

  void expectConversion(Object? returnedValue) {
    expect(application.calls, 0);
    expect(application.converted, hasLength(dispatcher.calls));
    for (final value in application.converted) {
      expect(value, same(returnedValue));
    }
  }
}

void _dispatchBatch(List<KeyEvent> events) {
  // Both supported SDKs can deliver synthesized and native events together.
  // ignore: deprecated_member_use
  final message = KeyMessage(events, null);
  // ignore: deprecated_member_use
  ServicesBinding.instance.keyEventManager.keyMessageHandler!(message);
}

void main() {
  for (final surface in ['dialog', 'popup', 'loading']) {
    for (final boundary in _Boundary.values) {
      for (final addedBehavior in OverlayBackBehavior.values) {
        testWidgets(
          '$surface ${boundary.name} interception does not consume a newly added $addedBehavior overlay',
          (tester) async {
            final harness = _Harness(boundary);
            await harness.mount(tester);
            harness.show(surface, OverlayBackBehavior.passThrough);
            await harness.focusContent(tester);
            OverlayHandle<void>? added;
            harness.dispatcher.onDispatch = () {
              added ??= harness.addConsumer(addedBehavior);
            };
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            expect(harness.rawEscapes, 1);
            harness.expectConversion(harness.dispatcher.returnedValue);
            await tester.pumpAndSettle();
            expect(added?.isVisible, isTrue);
          },
        );
      }
    }
  }

  for (final boundary in _Boundary.values) {
    testWidgets(
      '${boundary.name} interception without an application keeps default key consumption',
      (tester) async {
        final harness = _Harness(boundary);
        await harness.mount(tester, applicationAction: false);
        harness.show('dialog', OverlayBackBehavior.passThrough);
        await harness.focusContent(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(harness.rawEscapes, 0);
        expect(harness.application.calls, 0);
        expect(harness.application.converted, isEmpty);
      },
    );

    for (final behavior in [
      OverlayBackBehavior.block,
      OverlayBackBehavior.dismiss,
    ]) {
      for (final disposition in KeyEventResult.values) {
        testWidgets(
          '${boundary.name} interception owns the final $disposition value with a stable $behavior consumer',
          (tester) async {
            final harness = _Harness(boundary);
            final returnedValue = _DispatchValue(disposition);
            harness.dispatcher.returnedValue = returnedValue;
            await harness.mount(tester);
            final handle = harness.show('dialog', behavior);
            await harness.focusContent(tester);
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            expect(
              harness.rawEscapes,
              disposition == KeyEventResult.ignored ? 1 : 0,
            );
            harness.expectConversion(returnedValue);
            expect(handle.isVisible, isTrue);
          },
        );
      }

      testWidgets(
        '${boundary.name} delegated $behavior back dominates a rewritten ignored value',
        (tester) async {
          final harness = _Harness(boundary);
          harness.dispatcher.intercept = false;
          await harness.mount(tester);
          final handle = harness.show('dialog', behavior);
          await harness.focusContent(tester);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(harness.rawEscapes, 0);
          expect(harness.application.calls, 0);
          expect(harness.application.converted, isEmpty);
          expect(handle.isVisible, behavior == OverlayBackBehavior.block);
        },
      );
    }

    for (final replacementBehavior in OverlayBackBehavior.values) {
      testWidgets(
        '${boundary.name} loading replacement to $replacementBehavior cannot change an intercepted key',
        (tester) async {
          final harness = _Harness(boundary);
          await harness.mount(tester);
          final old = harness.show('loading', OverlayBackBehavior.block);
          await harness.focusContent(tester);
          OverlayHandle<void>? replacement;
          harness.dispatcher.onDispatch = () {
            replacement ??= SuperOverlay.loading.show(
              builder: (_) => const Text('replacement loading'),
              options: OverlayLoadingOptions(
                requestFocus: false,
                backBehavior: replacementBehavior,
              ),
            );
          };
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          expect(harness.rawEscapes, 1);
          harness.expectConversion(harness.dispatcher.returnedValue);
          await tester.pumpAndSettle();
          await old.closed;
          expect(replacement?.isVisible, isTrue);
        },
      );
    }

    testWidgets(
      '${boundary.name} programmatic dispatch keeps its Future and does not taint interception',
      (tester) async {
        final harness = _Harness(boundary);
        final original = Future<Object>.value(Object());
        harness.application.value = original;
        harness.dispatcher.intercept = false;
        await harness.mount(tester);
        harness.show('dialog', OverlayBackBehavior.passThrough);
        await harness.focusContent(tester);
        // Programmatic dispatch has no key-result rewriting contract.
        harness.dispatcher.returnedValue = original;
        final result = Actions.invoke(
          harness.focus.context!,
          const DismissIntent(),
        );
        expect(result, same(original));
        await original;
        expect(harness.application.calls, 1);
        expect(harness.application.converted, isEmpty);
        harness.dispatcher
          ..intercept = true
          ..returnedValue = const _DispatchValue(KeyEventResult.ignored);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(harness.rawEscapes, 1);
        expect(harness.application.calls, 1);
        expect(
          harness.application.converted.last,
          same(harness.dispatcher.returnedValue),
        );
      },
    );

    testWidgets(
      '${boundary.name} a throwing interceptor cannot consume the next ignored key',
      (tester) async {
        final harness = _Harness(boundary);
        await harness.mount(tester);
        harness.show('dialog', OverlayBackBehavior.passThrough);
        await harness.focusContent(tester);
        harness.dispatcher.onDispatch = () {
          harness.addConsumer(OverlayBackBehavior.block);
          throw StateError('interception failed after adding an overlay');
        };
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(tester.takeException(), isStateError);
        final rawBefore = harness.rawEscapes;
        harness.dispatcher.onDispatch = null;
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(harness.rawEscapes, rawBefore + 1);
        expect(tester.takeException(), isNull);
        expect(harness.application.calls, 0);
      },
    );
  }

  for (final boundary in [_Boundary.child, _Boundary.ancestor]) {
    for (final escapeFirst in [false, true]) {
      testWidgets(
        '${boundary.name} interception respects later early focus changes and a batched key, Escape first=$escapeFirst',
        (tester) async {
          final harness = _Harness(boundary);
          await harness.mount(tester);
          harness.show('dialog', OverlayBackBehavior.passThrough);
          await harness.focusContent(tester);
          harness.pageFocus.requestFocus();
          await tester.pump();
          expect(harness.pageFocus.hasFocus, isTrue);
          OverlayHandle<void>? added;
          KeyEventResult retarget(KeyEvent event) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              harness.focus.requestFocus();
              FocusManager.instance.applyFocusChangesIfNeeded();
            }
            return KeyEventResult.ignored;
          }

          FocusManager.instance.addEarlyKeyEventHandler(retarget);
          addTearDown(
            () => FocusManager.instance.removeEarlyKeyEventHandler(retarget),
          );
          harness.dispatcher.onDispatch = () {
            added ??= harness.addConsumer(OverlayBackBehavior.block);
          };
          const escape = KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.escape,
            logicalKey: LogicalKeyboardKey.escape,
            timeStamp: Duration.zero,
          );
          const other = KeyUpEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: LogicalKeyboardKey.keyA,
            timeStamp: Duration.zero,
            synthesized: true,
          );
          _dispatchBatch([
            if (escapeFirst) escape,
            other,
            if (!escapeFirst) escape,
          ]);
          expect(harness.focus.hasFocus, isTrue);
          expect(harness.rawEscapes, 1);
          harness.expectConversion(harness.dispatcher.returnedValue);
          await tester.pumpAndSettle();
          expect(added?.isVisible, isTrue);
        },
      );
    }
  }

  for (final disposition in KeyEventResult.values) {
    testWidgets(
      'native direct application action converts intercepted $disposition after adding a consumer',
      (tester) async {
        final harness = _Harness(_Boundary.child);
        final returnedValue = _DispatchValue(disposition);
        harness.dispatcher.returnedValue = returnedValue;
        await harness.mount(tester);
        harness.show(
          'dialog',
          OverlayBackBehavior.passThrough,
          directApplication: true,
        );
        await harness.focusContent(tester);
        harness.dispatcher.onDispatch = () {
          harness.addConsumer(OverlayBackBehavior.block);
        };
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(
          harness.rawEscapes,
          disposition == KeyEventResult.ignored ? 1 : 0,
        );
        harness.expectConversion(returnedValue);
      },
    );
  }
}
