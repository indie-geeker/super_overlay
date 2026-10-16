import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';
import 'package:super_overlay/src/data/show_param.dart';
import 'package:super_overlay/src/helper/overlay_manager.dart';

import 'overlay_test_support.dart';

Future<void> _mount(WidgetTester tester, {bool animated = false}) async {
  final integration = SuperOverlay.integration();
  final original = overlayConfig.loading;
  if (animated) {
    overlayConfig.loading = const LoadingConfig(nonAnimationTypes: []);
  }
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
    overlayConfig.loading = original;
  });
  await tester.pumpWidget(
    MaterialApp(
      builder: integration.builder,
      navigatorObservers: [integration.observer],
      home: const Scaffold(),
    ),
  );
}

String _identity() {
  for (var i = 0; i < 100000; i++) {
    final value = '_super_overlay_command_loading_$i';
    if (SuperOverlay.exists(
      tag: value,
      surfaces: const {OverlaySurface.loading},
    )) {
      return value;
    }
  }
  throw StateError('missing identity');
}

OverlayHandle<void> _show(
  String text, {
  String? tag,
  Duration minimum = Duration.zero,
  OverlayBackBehavior back = OverlayBackBehavior.dismiss,
}) => SuperOverlay.loading.show(
  builder: (_) => Text(text),
  options: OverlayLoadingOptions(
    tag: tag,
    minimumVisibleDuration: minimum,
    backBehavior: back,
  ),
);

Future<void> _showInternal({
  required SuperOverlayOnBack onBack,
  bool animated = false,
  Duration minimum = Duration.zero,
}) {
  return OverlayManager.instance.showLoading<void>(
    param: ShowLoadingParam(
      builder: (_) => const Text('internal loading'),
      alignment: Alignment.center,
      clickMaskDismiss: false,
      animationType: AnimationType.fade,
      nonAnimationTypes: animated ? const [] : const [NonAnimationType.close],
      animationBuilder: null,
      usePenetrate: false,
      useAnimation: animated,
      animationTime: const Duration(milliseconds: 200),
      maskColor: Colors.black54,
      maskWidget: null,
      onDismiss: null,
      onMask: null,
      awaitCompletion: AwaitCompletion.dismiss,
      displayTime: null,
      leastLoadingTime: minimum,
      tag: null,
      backType: BackType.normal,
      onBack: onBack,
    ),
  );
}

void main() {
  for (final fail in [false, true]) {
    testWidgets(
      'run cleanup remains isolated after action synchronously replaces loading, fail=$fail',
      (tester) async {
        await _mount(tester);
        late OverlayHandle<void> replacement;
        final error = StateError('business');
        final task = SuperOverlay.loading.run<int>(() {
          final oldId = _identity();
          replacement = _show(
            'replacement',
            tag: oldId,
            minimum: const Duration(seconds: 1),
          );
          if (fail) throw error;
          return 7;
        }, builder: (_) => const Text('old'));
        Object? failure;
        int? value;
        final observed = task.then<void>(
          (result) => value = result,
          onError: (Object e, StackTrace s) => failure = e,
        );
        await tester.pump();
        await observed;
        expect(value, fail ? null : 7);
        expect(failure, fail ? same(error) : isNull);
        expect(replacement.isVisible, isTrue);
        expect(find.text('replacement'), findsOneWidget);
        final close = replacement.close();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        await close;
      },
    );
  }

  testWidgets(
    'global business close cancels latest deferred only without joining other pending close',
    (tester) async {
      await _mount(tester, animated: true);
      final first = _show('first', tag: 'old');
      await tester.pumpAndSettle();
      var oldClosed = false;
      final oldClosing = first.close().then((_) => oldClosed = true);
      final second = _show('second', tag: 'new');
      final cancelled = SuperOverlay.close(
        target: OverlayCloseTarget.loading,
        tag: 'new',
      );
      await tester.pump(const Duration(milliseconds: 1));
      await cancelled;
      expect(oldClosed, isFalse);
      await second.closed;
      await expectLater(second.visible, throwsStateError);
      final third = _show('third', tag: 'third');
      await tester.pumpAndSettle();
      await oldClosing;
      expect(third.isVisible, isTrue);
      expect(find.text('third'), findsOneWidget);
      final end = third.close();
      await tester.pumpAndSettle();
      await end;
    },
  );

  testWidgets(
    'multiple deferred replacements settle superseded requests and keep newest identity',
    (tester) async {
      await _mount(tester, animated: true);
      final first = _show('first');
      await tester.pumpAndSettle();
      final firstId = _identity();
      final closing = first.close();
      final second = _show('second', tag: firstId);
      final third = _show('third', tag: firstId);
      final secondClosing = second.close();
      await tester.pump(const Duration(milliseconds: 1));
      await second.closed;
      await secondClosing;
      await expectLater(second.visible, throwsStateError);
      await tester.pumpAndSettle();
      await closing;
      await first.closed;
      await third.visible;
      expect(third.isVisible, isTrue);
      expect(find.text('third'), findsOneWidget);
      final end = third.close();
      await tester.pumpAndSettle();
      await end;
    },
  );

  testWidgets(
    'back during first-frame minimum owns close; replacement invalidates old budget',
    (tester) async {
      await _mount(tester);
      final first = _show('first', minimum: const Duration(seconds: 2));
      final firstId = _identity();
      var backDone = false;
      final back = OverlayManager.instance.handleBackEvent().then((value) {
        backDone = true;
        return value;
      });
      await tester.pump();
      expect(backDone, isFalse);
      final second = _show(
        'second',
        tag: firstId,
        minimum: const Duration(seconds: 1),
      );
      await tester.pump();
      expect(await back, isTrue);
      expect(second.isVisible, isTrue);
      await first.closed;
      final close = second.close();
      await tester.pump(const Duration(milliseconds: 999));
      expect(second.isVisible, isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      await close;
      expect(second.isVisible, isFalse);
    },
  );

  testWidgets(
    'host teardown settles active pending and superseded deferred handles once',
    (tester) async {
      await _mount(tester, animated: true);
      final first = _show('first');
      await tester.pumpAndSettle();
      final closing = first.close();
      final second = _show('second', minimum: const Duration(seconds: 2));
      final third = _show('third', minimum: const Duration(seconds: 2));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await Future.wait([closing, first.closed, second.closed, third.closed]);
      await expectLater(second.visible, throwsStateError);
      await expectLater(third.visible, throwsStateError);
      expect(first.isVisible || second.isVisible || third.isVisible, isFalse);
      await first.close();
      await second.close();
      await third.close();
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    },
  );

  for (final policy in OverlayBackBehavior.values) {
    testWidgets(
      'public Escape during old close preserves deferred $policy replacement',
      (tester) async {
        await _mount(tester, animated: true);
        final first = _show('first');
        await tester.pumpAndSettle();
        final oldIdentity = _identity();
        final closing = first.close();
        final second = _show('second', tag: oldIdentity, back: policy);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await closing;
        expect(second.isVisible, isTrue);
        final end = second.close();
        await tester.pumpAndSettle();
        await end;
      },
    );

    testWidgets(
      'back selection cannot retarget a same-turn $policy replacement',
      (tester) async {
        await _mount(tester);
        final first = _show('first');
        await tester.pumpAndSettle();
        final oldIdentity = _identity();
        final back = OverlayManager.instance.handleBackEvent();
        final second = _show('second', tag: oldIdentity, back: policy);
        await tester.pumpAndSettle();
        await first.closed;
        expect(await back, isTrue);
        expect(
          second.isVisible,
          isTrue,
          reason:
              'The selected old Loading must not transfer close ownership to its replacement.',
        );
        final end = second.close();
        await tester.pumpAndSettle();
        await end;
      },
    );

    testWidgets(
      'back joins old in-flight close without cancelling a deferred $policy replacement',
      (tester) async {
        await _mount(tester, animated: true);
        final first = _show('first');
        await tester.pumpAndSettle();
        final oldIdentity = _identity();
        final closing = first.close();
        final second = _show('second', tag: oldIdentity, back: policy);
        final back = OverlayManager.instance.handleBackEvent();
        final duplicate = OverlayManager.instance.handleBackEvent();
        expect(await duplicate, isTrue);
        await tester.pumpAndSettle();
        await closing;
        expect(await back, isTrue);
        expect(
          second.isVisible,
          isTrue,
          reason:
              'The in-flight old surface owns this back event; the deferred surface must retain its own policy.',
        );
        await second.visible;
        final end = second.close();
        await tester.pumpAndSettle();
        await end;
      },
    );
  }

  for (final consumed in [false, true]) {
    testWidgets(
      'async old onBack cannot close replacement, consumed=$consumed',
      (tester) async {
        await _mount(tester);
        final decision = Completer<bool>();
        var calls = 0;
        final oldClosed = _showInternal(
          onBack: () {
            calls++;
            return decision.future;
          },
        );
        await tester.pumpAndSettle();
        final back = OverlayManager.instance.handleBackEvent();
        expect(calls, 1);
        final current = _show(
          'new protected loading',
          back: OverlayBackBehavior.block,
        );
        decision.complete(consumed);
        await tester.pumpAndSettle();
        expect(await back, isTrue);
        await oldClosed;
        expect(current.isVisible, isTrue);
        final close = current.close();
        await tester.pumpAndSettle();
        await close;
      },
    );
  }

  testWidgets('async old onBack preserves a new untagged internal lifecycle', (
    tester,
  ) async {
    await _mount(tester);
    final decision = Completer<bool>();
    final oldClosed = _showInternal(onBack: () => decision.future);
    await tester.pumpAndSettle();
    final back = OverlayManager.instance.handleBackEvent();
    final currentClosed = _showInternal(onBack: () => true);
    var closed = false;
    currentClosed.then((_) => closed = true);
    decision.complete(false);
    await tester.pumpAndSettle();
    expect(await back, isTrue);
    await oldClosed;
    expect(closed, isFalse);
    expect(find.text('internal loading'), findsOneWidget);
    final close = SuperOverlay.loading.close();
    await tester.pumpAndSettle();
    await close;
    await currentClosed;
  });

  for (final afterClose in [false, true]) {
    testWidgets(
      'async old onBack resumes across a deferred replacement, after close=$afterClose',
      (tester) async {
        await _mount(tester);
        final decision = Completer<bool>();
        final oldClosed = _showInternal(
          onBack: () => decision.future,
          animated: true,
        );
        await tester.pumpAndSettle();
        final back = OverlayManager.instance.handleBackEvent();
        final oldClose = SuperOverlay.loading.close();
        final current = _show(
          'deferred replacement',
          back: OverlayBackBehavior.block,
        );
        if (afterClose) await tester.pumpAndSettle();
        decision.complete(false);
        await tester.pumpAndSettle();
        expect(await back, isTrue);
        await Future.wait([oldClose, oldClosed]);
        expect(current.isVisible, isTrue);
        final close = current.close();
        await tester.pumpAndSettle();
        await close;
      },
    );
  }

  testWidgets(
    'async old onBack settles after host teardown without closing new host',
    (tester) async {
      await _mount(tester);
      final decision = Completer<bool>();
      final oldClosed = _showInternal(onBack: () => decision.future);
      await tester.pumpAndSettle();
      final back = OverlayManager.instance.handleBackEvent();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _mount(tester);
      final current = _show('new host');
      decision.complete(false);
      await tester.pumpAndSettle();
      expect(await back, isFalse);
      await oldClosed;
      expect(current.isVisible, isTrue);
      final close = current.close();
      await tester.pumpAndSettle();
      await close;
    },
  );

  testWidgets(
    'captured close joins minimum wait without changing its deadline',
    (tester) async {
      await _mount(tester);
      final handle = _show('minimum', minimum: const Duration(seconds: 1));
      await tester.pump();
      final close = handle.close();
      var backSettled = false;
      final back = OverlayManager.instance.handleBackEvent().then((value) {
        backSettled = true;
        return value;
      });
      final repeated = OverlayManager.instance.handleBackEvent();
      expect(await repeated, isTrue);
      await tester.pump(const Duration(milliseconds: 999));
      expect(backSettled, isFalse);
      expect(handle.isVisible, isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      await close;
      expect(await back, isTrue);
      expect(handle.isVisible, isFalse);
    },
  );

  for (final tagged in [false, true]) {
    testWidgets(
      'global close still cancels deferred and joins old close, tagged=$tagged',
      (tester) async {
        await _mount(tester, animated: true);
        final first = _show('first', tag: 'global');
        await tester.pumpAndSettle();
        final oldClose = first.close();
        final second = _show(
          'second',
          tag: 'global',
          back: OverlayBackBehavior.block,
        );
        var globalSettled = false;
        final global = SuperOverlay.close(
          target: OverlayCloseTarget.loading,
          tag: tagged ? 'global' : null,
        ).then((_) => globalSettled = true);
        await tester.pump(const Duration(milliseconds: 1));
        expect(globalSettled, isFalse);
        await second.closed;
        await expectLater(second.visible, throwsStateError);
        await tester.pumpAndSettle();
        await Future.wait([oldClose, global]);
        expect(
          SuperOverlay.exists(surfaces: const {OverlaySurface.loading}),
          isFalse,
        );
      },
    );
  }

  testWidgets('in-flight close skips old onBack and releases the route gate', (
    tester,
  ) async {
    await _mount(tester);
    final route = ModalRoute.of(tester.element(find.byType(Scaffold)))!;
    final decision = Completer<bool>();
    addTearDown(() {
      if (!decision.isCompleted) decision.complete(false);
    });
    var calls = 0;
    final oldClosed = _showInternal(
      animated: true,
      onBack: () {
        calls++;
        return decision.future;
      },
    );
    await tester.pumpAndSettle();
    final oldClose = SuperOverlay.loading.close();
    final current = _show(
      'pass-through replacement',
      back: OverlayBackBehavior.passThrough,
    );
    var backSettled = false;
    final back = OverlayManager.instance.handleBackEvent().then((value) {
      backSettled = true;
      return value;
    });
    expect(calls, 0);
    await tester.pumpAndSettle();
    await Future.wait([oldClosed, oldClose]);
    expect(backSettled, isTrue);
    expect(await back, isTrue);
    expect(current.isVisible, isTrue);
    expect(OverlayManager.instance.hasConsumingBackTarget, isFalse);
    expect(route.popDisposition, isNot(RoutePopDisposition.doNotPop));
    final close = current.close();
    await tester.pumpAndSettle();
    await close;
  });

  testWidgets('deferred handoff skips old onBack and releases the route gate', (
    tester,
  ) async {
    await _mount(tester);
    final route = ModalRoute.of(tester.element(find.byType(Scaffold)))!;
    final decision = Completer<bool>();
    addTearDown(() {
      if (!decision.isCompleted) decision.complete(false);
    });
    var calls = 0;
    final oldClosed = _showInternal(
      animated: true,
      onBack: () {
        calls++;
        return decision.future;
      },
    );
    await tester.pumpAndSettle();
    final oldClose = OverlayManager.instance.loadingOverlay.dismiss();
    var backSettled = false;
    Future<bool>? back;
    // Register before deferred activation's listener to exercise their handoff.
    oldClose.then((_) {
      back = OverlayManager.instance.handleBackEvent().then((value) {
        backSettled = true;
        return value;
      });
    });
    final current = _show(
      'pass-through after handoff',
      back: OverlayBackBehavior.passThrough,
    );
    await tester.pumpAndSettle();
    await Future.wait([oldClosed, oldClose]);
    expect(calls, 0);
    expect(backSettled, isTrue);
    expect(await back!, isTrue);
    expect(current.isVisible, isTrue);
    expect(route.popDisposition, isNot(RoutePopDisposition.doNotPop));
    final close = current.close();
    await tester.pumpAndSettle();
    await close;
  });

  testWidgets('minimum wait retains active onBack before closing starts', (
    tester,
  ) async {
    await _mount(tester);
    var calls = 0;
    final closed = _showInternal(
      minimum: const Duration(seconds: 1),
      onBack: () {
        calls++;
        return false;
      },
    );
    await tester.pump();
    final close = SuperOverlay.loading.close();
    final back = OverlayManager.instance.handleBackEvent();
    expect(calls, 1);
    await tester.pump(const Duration(milliseconds: 999));
    expect(find.text('internal loading'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    await Future.wait([close, closed]);
    expect(await back, isTrue);
    expect(calls, 1);
  });
}
