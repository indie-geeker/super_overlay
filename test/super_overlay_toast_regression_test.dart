import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

import 'overlay_test_support.dart';

Future<void> _mount(WidgetTester tester, [Widget? child]) async {
  final integration = SuperOverlay.integration();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      builder: integration.builder,
      navigatorObservers: [integration.observer],
      home: Scaffold(body: child ?? const SizedBox.shrink()),
    ),
  );
}

OverlayHandle<void> _stack(
  String name, {
  double height = 40,
  Alignment alignment = Alignment.bottomCenter,
  WidgetBuilder? builder,
  Duration duration = const Duration(minutes: 1),
}) => SuperOverlay.toast(
  name,
  builder:
      builder ??
      (_) => SizedBox(
        key: ValueKey(name),
        width: 120,
        height: height,
        child: Text(name),
      ),
  options: OverlayToastOptions(
    displayPolicy: OverlayToastDisplayPolicy.stack,
    displayDuration: duration,
    alignment: alignment,
    consumeEvents: true,
  ),
);

Rect _rect(WidgetTester tester, String name) =>
    tester.getRect(find.byKey(ValueKey(name)));

void _expectSeparate(WidgetTester tester, List<String> names) {
  for (var i = 0; i < names.length; i++) {
    for (var j = i + 1; j < names.length; j++) {
      expect(
        _rect(tester, names[i]).overlaps(_rect(tester, names[j])),
        isFalse,
        reason: '${names[i]} and ${names[j]} must not overlap',
      );
    }
  }
}

void main() {
  testWidgets(
    'center toast stays above keyboard after colliding with bottom toast',
    (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _mount(tester);
      var bottomTaps = 0;
      var centerTaps = 0;
      _stack(
        'bottom',
        builder:
            (_) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => bottomTaps++,
              child: const SizedBox(
                key: ValueKey('bottom'),
                width: 220,
                height: 40,
              ),
            ),
      );
      final center = _stack(
        'center',
        alignment: Alignment.center,
        builder:
            (_) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => centerTaps++,
              child: const SizedBox(
                key: ValueKey('center'),
                width: 220,
                height: 40,
              ),
            ),
      );
      await tester.pumpAndSettle();
      final originalBottom = _rect(tester, 'bottom');
      final originalCenter = _rect(tester, 'center');
      for (final inset in [300.0, 200.0, 350.0, 0.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pumpAndSettle();
        _expectSeparate(tester, ['bottom', 'center']);
        for (final name in ['bottom', 'center']) {
          expect(_rect(tester, name).top, greaterThanOrEqualTo(0));
          expect(_rect(tester, name).bottom, lessThanOrEqualTo(600 - inset));
          await tester.tapAt(_rect(tester, name).center);
        }
      }
      expect(bottomTaps, 4);
      expect(centerTaps, 4);
      expect(_rect(tester, 'bottom'), originalBottom);
      expect(_rect(tester, 'center'), originalCenter);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final closing = center.close();
      await tester.pumpAndSettle();
      await closing;
      expect(_rect(tester, 'bottom').bottom, 300);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tall bottom toast reflows the center toast without top clipping',
    (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _mount(tester);
      var centerTaps = 0;
      var tallTaps = 0;
      final center = _stack(
        'center',
        alignment: Alignment.center,
        builder:
            (_) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => centerTaps++,
              child: const SizedBox(
                key: ValueKey('center'),
                width: 220,
                height: 40,
              ),
            ),
      );
      var height = 320.0;
      final tall = _stack(
        'tall',
        builder:
            (_) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => tallTaps++,
              child: SizedBox(
                key: const ValueKey('tall'),
                width: 220,
                height: height,
              ),
            ),
      );
      await tester.pumpAndSettle();
      for (final currentHeight in [320.0, 400.0, 320.0]) {
        height = currentHeight;
        tall.refresh();
        await tester.pumpAndSettle();
        _expectSeparate(tester, ['center', 'tall']);
        for (final name in ['center', 'tall']) {
          expect(_rect(tester, name).top, greaterThanOrEqualTo(0));
          expect(_rect(tester, name).bottom, lessThanOrEqualTo(600));
          await tester.tapAt(_rect(tester, name).center);
        }
        expect(_rect(tester, 'tall').height, currentHeight);
      }
      expect(centerTaps, 3);
      expect(tallTaps, 3);
      final closing = tall.close();
      await tester.pumpAndSettle();
      await closing;
      await center.visible;
      expect(_rect(tester, 'center'), const Rect.fromLTWH(90, 280, 220, 40));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compacting empty gaps preserves toast state and original timer',
    (tester) async {
      await _mount(tester);
      _stack('A', height: 100, alignment: Alignment.topCenter);
      var builds = 0;
      final retained = _stack(
        'B',
        alignment: Alignment.center,
        duration: const Duration(seconds: 1),
        builder: (_) {
          builds++;
          return const SizedBox(key: ValueKey('B'), child: _CounterToast());
        },
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('count 0'));
      await tester.pump();
      _stack('C', height: 280);
      // Advance the toast animation without waiting for the button's ink
      // animation, which could run beyond the original toast deadline.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      _expectSeparate(tester, ['A', 'B', 'C']);
      for (final name in ['A', 'B', 'C']) {
        expect(_rect(tester, name).top, greaterThanOrEqualTo(0));
        expect(_rect(tester, name).bottom, lessThanOrEqualTo(600));
      }
      expect(builds, 1);
      expect(find.text('count 1'), findsOneWidget);
      await tester.tap(find.text('count 1'));
      await tester.pump();
      expect(find.text('count 2'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump();
      expect(find.byKey(const ValueKey('B')), findsNothing);
      await retained.closed;
      _expectSeparate(tester, ['A', 'C']);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('bounded stack honors safe area when keyboard changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 20);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
    addTearDown(tester.view.reset);
    await _mount(tester);
    _stack('top', alignment: Alignment.topCenter);
    _stack('bottom');
    _stack('center', alignment: Alignment.center);
    await tester.pumpAndSettle();
    final original = {
      for (final name in ['top', 'bottom', 'center']) name: _rect(tester, name),
    };
    for (final inset in [300.0, 350.0, 0.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      tester.view.padding = FakeViewPadding(
        top: 24,
        bottom: inset == 0 ? 20 : 0,
      );
      await tester.pumpAndSettle();
      _expectSeparate(tester, ['top', 'bottom', 'center']);
      for (final name in ['top', 'bottom', 'center']) {
        expect(_rect(tester, name).top, greaterThanOrEqualTo(24));
        expect(
          _rect(tester, name).bottom,
          lessThanOrEqualTo(inset == 0 ? 580 : 600 - inset),
        );
      }
    }
    for (final name in original.keys) {
      expect(_rect(tester, name), original[name]);
    }
    expect(tester.takeException(), isNull);
  });

  for (final alignment in [Alignment.topCenter, Alignment.bottomCenter]) {
    testWidgets('default stack excludes outer margins at $alignment', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      await _mount(tester);
      final handles = <OverlayHandle<void>>[];
      for (final name in ['A', 'B', 'C']) {
        handles.add(
          SuperOverlay.toast(
            name,
            options: OverlayToastOptions(
              displayPolicy: OverlayToastDisplayPolicy.stack,
              displayDuration: const Duration(minutes: 1),
              alignment: alignment,
            ),
          ),
        );
      }
      await tester.pumpAndSettle();
      Rect content(String name) => tester.getRect(find.text(name));
      final first = content('A');
      expect(
        alignment.y > 0 ? first.bottom : first.top,
        alignment.y > 0 ? 240 : 60,
      );
      for (final name in ['A', 'B', 'C']) {
        expect(content(name).top, greaterThanOrEqualTo(0));
        expect(content(name).bottom, lessThanOrEqualTo(300));
      }
      // The default bubble adds 10 px above/below its text. Adjacent bubbles
      // have an 8 px gap; their 50 px screen margins are not repeated.
      expect((content('B').top - first.top).abs(), first.height + 28);
      expect((content('C').top - content('B').top).abs(), first.height + 28);

      final closing = handles[1].close();
      await tester.pumpAndSettle();
      await closing;
      expect((content('C').top - first.top).abs(), first.height + 28);
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      expect(
        alignment.y > 0 ? content('A').bottom : content('A').top,
        alignment.y > 0 ? 540 : 60,
      );
      expect((content('C').top - content('A').top).abs(), first.height + 28);
    });
  }

  for (final y in [-1.0, 1.0]) {
    testWidgets(
      'wide left and right toasts avoid overlap and retain hits y=$y',
      (tester) async {
        tester.view.physicalSize = const Size(400, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await _mount(tester);
        var leftTaps = 0;
        var rightTaps = 0;
        final left = _stack(
          'left',
          alignment: Alignment(-1, y),
          builder:
              (_) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => leftTaps++,
                child: const SizedBox(
                  key: ValueKey('left'),
                  width: 240,
                  height: 40,
                ),
              ),
        );
        _stack(
          'right',
          alignment: Alignment(1, y),
          builder:
              (_) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => rightTaps++,
                child: const SizedBox(
                  key: ValueKey('right'),
                  width: 240,
                  height: 40,
                ),
              ),
        );
        await tester.pumpAndSettle();
        _expectSeparate(tester, ['left', 'right']);
        expect(
          (_rect(tester, 'left').top - _rect(tester, 'right').top).abs(),
          48,
        );
        await tester.tapAt(Offset(200, _rect(tester, 'left').center.dy));
        await tester.tapAt(Offset(200, _rect(tester, 'right').center.dy));
        expect(leftTaps, 1);
        expect(rightTaps, 1);
        final closing = left.close();
        await tester.pumpAndSettle();
        await closing;
        expect(_rect(tester, 'right').top, y > 0 ? 560 : 0);
        await tester.tapAt(_rect(tester, 'right').center);
        expect(rightTaps, 2);
      },
    );
  }

  testWidgets('horizontal collision changes with content and viewport width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _mount(tester);
    var width = 120.0;
    final left = _stack(
      'left',
      alignment: Alignment.bottomLeft,
      builder:
          (_) =>
              SizedBox(key: const ValueKey('left'), width: width, height: 40),
    );
    _stack(
      'right',
      alignment: Alignment.bottomRight,
      builder:
          (_) => const SizedBox(key: ValueKey('right'), width: 240, height: 40),
    );
    await tester.pumpAndSettle();
    expect(_rect(tester, 'left').bottom, _rect(tester, 'right').bottom);
    tester.view.physicalSize = const Size(400, 600);
    await tester.pumpAndSettle();
    expect(_rect(tester, 'left').bottom, _rect(tester, 'right').bottom);
    width = 240;
    left.refresh();
    await tester.pumpAndSettle();
    _expectSeparate(tester, ['left', 'right']);
    expect(_rect(tester, 'right').bottom, _rect(tester, 'left').top - 8);
    tester.view.physicalSize = const Size(600, 600);
    await tester.pumpAndSettle();
    expect(_rect(tester, 'left').bottom, _rect(tester, 'right').bottom);
  });

  for (final y in [-1.0, 1.0]) {
    testWidgets('collision walk clears every earlier body y=$y', (
      tester,
    ) async {
      await _mount(tester);
      // Insert in the opposite order to their positions on screen. A single
      // insertion-order pass would displace C into B after testing B already.
      _stack('B', alignment: Alignment(0, y / 2));
      _stack('A', alignment: Alignment(0, y));
      _stack('C', height: 160, alignment: Alignment(0, y));
      await tester.pumpAndSettle();
      _expectSeparate(tester, ['A', 'B', 'C']);
      expect(_rect(tester, 'C').top, greaterThanOrEqualTo(0));
      expect(_rect(tester, 'C').bottom, lessThanOrEqualTo(600));
      expect(
        y > 0 ? _rect(tester, 'C').bottom : _rect(tester, 'C').top,
        y > 0 ? _rect(tester, 'B').top - 8 : _rect(tester, 'B').bottom + 8,
      );
    });
  }

  testWidgets(
    'refreshActive updates default margins without moving custom padding',
    (tester) async {
      await _mount(tester);
      const options = OverlayToastOptions(
        displayPolicy: OverlayToastDisplayPolicy.refreshActive,
        displayDuration: Duration(minutes: 1),
      );
      SuperOverlay.toast('default first', options: options);
      _stack('B', height: 140);
      await tester.pumpAndSettle();
      final first = _rect(tester, 'B');
      expect(first.bottom, tester.getRect(find.text('default first')).top - 18);

      SuperOverlay.toast(
        'custom',
        options: options,
        builder:
            (_) => const Padding(
              key: ValueKey('custom'),
              padding: EdgeInsets.all(20),
              child: SizedBox(width: 80, height: 100),
            ),
      );
      await tester.pumpAndSettle();
      expect(_rect(tester, 'custom').height, 140);
      expect(_rect(tester, 'B').bottom, _rect(tester, 'custom').top - 8);
      expect(_rect(tester, 'B').top, first.top - 50);

      SuperOverlay.toast('default again', options: options);
      await tester.pumpAndSettle();
      expect(_rect(tester, 'B'), first);
      expect(tester.takeException(), isNull);
    },
  );

  for (final duringBuild in [false, true]) {
    testWidgets('same-frame refresh is idempotent, build=$duringBuild', (
      tester,
    ) async {
      final trigger = ValueNotifier(false);
      addTearDown(trigger.dispose);
      final handles = <OverlayHandle<void>>[];
      final rejectedVisibility = <Future<void>>[];
      void refresh() {
        for (var i = 0; i < 3; i++) {
          final handle = SuperOverlay.toast(
            'refresh $i',
            options: const OverlayToastOptions(
              displayPolicy: OverlayToastDisplayPolicy.refreshActive,
              displayDuration: Duration(seconds: 1),
            ),
          );
          handles.add(handle);
          if (i < 2) {
            rejectedVisibility.add(
              expectLater(handle.visible, throwsStateError),
            );
          }
        }
      }

      await _mount(
        tester,
        ValueListenableBuilder<bool>(
          valueListenable: trigger,
          builder: (_, value, _) {
            if (value && handles.isEmpty) refresh();
            return const SizedBox.shrink();
          },
        ),
      );
      if (duringBuild) {
        trigger.value = true;
      } else {
        refresh();
      }
      await tester.pumpAndSettle();
      await Future.wait(rejectedVisibility);
      await handles.last.visible;
      expect(find.text('refresh 2'), findsOneWidget);
      expect(find.text('refresh 0'), findsNothing);
      expect(handles.first.isVisible, isFalse);
      expect(handles.last.isVisible, isTrue);

      // A stale owner cannot dismiss the latest request, and its replacement
      // must still have a functioning auto-dismiss timer.
      await handles.first.close();
      expect(handles.last.isVisible, isTrue);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await Future.wait(handles.map((handle) => handle.closed));
      expect(find.text('refresh 2'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a toast removed during build never performs its queued insert', (
    tester,
  ) async {
    final trigger = ValueNotifier(false);
    addTearDown(trigger.dispose);
    OverlayHandle<void>? first;
    OverlayHandle<void>? last;
    Future<void>? rejectedVisibility;
    await _mount(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: trigger,
        builder: (_, value, _) {
          if (value && first == null) {
            first = SuperOverlay.toast('cancelled before insertion');
            rejectedVisibility = expectLater(first!.visible, throwsStateError);
            last = SuperOverlay.toast(
              'replacement',
              options: const OverlayToastOptions(
                displayPolicy: OverlayToastDisplayPolicy.replaceLatest,
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
    trigger.value = true;
    await tester.pumpAndSettle();
    await rejectedVisibility;
    await first!.closed;
    await last!.visible;
    expect(find.text('cancelled before insertion'), findsNothing);
    expect(find.text('replacement'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final alignment in [
    Alignment.topCenter,
    Alignment.center,
    Alignment.bottomCenter,
  ]) {
    testWidgets('stack reflows different sizes after removal at $alignment', (
      tester,
    ) async {
      await _mount(tester);
      _stack('A', alignment: alignment);
      final middle = _stack('B', height: 90, alignment: alignment);
      _stack('C', height: 65, alignment: alignment);
      await tester.pumpAndSettle();
      _expectSeparate(tester, ['A', 'B', 'C']);

      final closing = middle.close();
      await tester.pumpAndSettle();
      await closing;
      _stack('D', height: 100, alignment: alignment);
      await tester.pumpAndSettle();
      _expectSeparate(tester, ['A', 'C', 'D']);
      expect(find.byKey(const ValueKey('B')), findsNothing);
    });
  }

  testWidgets('stack reflow preserves content state, hit testing and timers', (
    tester,
  ) async {
    await _mount(tester);
    final first = _stack('A');
    var builds = 0;
    final retained = _stack(
      'retained',
      duration: const Duration(seconds: 1),
      builder: (_) {
        builds++;
        return const _CounterToast();
      },
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('count 0'));
    await tester.pump();
    expect(find.text('count 1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));

    final closing = first.close();
    await tester.pump();
    await closing;
    _stack('D');
    await tester.pump();
    expect(find.text('count 1'), findsOneWidget);
    expect(builds, 1);
    await tester.tap(find.text('count 1'));
    await tester.pump();
    expect(find.text('count 2'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await retained.closed;
    expect(find.byType(_CounterToast), findsNothing);
    expect(find.byKey(const ValueKey('D')), findsOneWidget);
  });

  testWidgets('stack refresh and keyboard layout update measured spacing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _mount(tester);
    var height = 40.0;
    final first = _stack(
      'A',
      builder:
          (_) => SizedBox(key: const ValueKey('A'), width: 120, height: height),
    );
    _stack('B', height: 80);
    await tester.pumpAndSettle();
    height = 140;
    first.refresh();
    await tester.pumpAndSettle();
    _expectSeparate(tester, ['A', 'B']);
    expect(_rect(tester, 'A').height, 140);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    _expectSeparate(tester, ['A', 'B']);
    expect(_rect(tester, 'A').bottom, lessThanOrEqualTo(500));
    expect(_rect(tester, 'B').bottom, lessThan(_rect(tester, 'A').top));
  });

  testWidgets('independent alignments do not reserve each others space', (
    tester,
  ) async {
    await _mount(tester);
    _stack('bottom');
    _stack('top', alignment: Alignment.topCenter);
    await tester.pumpAndSettle();
    expect(_rect(tester, 'top').top, 0);
    expect(_rect(tester, 'bottom').bottom, 600);
  });

  testWidgets('closing toast keeps its space until the animation completes', (
    tester,
  ) async {
    final original = overlayConfig.toast;
    overlayConfig.toast = const ToastConfig(
      animationTime: Duration(milliseconds: 500),
      nonAnimationTypes: [],
    );
    addTearDown(() => overlayConfig.toast = original);
    await _mount(tester);
    _stack('A');
    final middle = _stack('B');
    _stack('C');
    await tester.pumpAndSettle();
    final before = _rect(tester, 'C');
    final closing = middle.close();
    await tester.pump(const Duration(milliseconds: 100));
    _stack('D');
    await tester.pump(const Duration(milliseconds: 100));
    expect(_rect(tester, 'C'), before);
    _expectSeparate(tester, ['A', 'B', 'C', 'D']);

    await tester.pumpAndSettle();
    await closing;
    expect(find.byKey(const ValueKey('B')), findsNothing);
    expect(_rect(tester, 'C').top, greaterThan(before.top));
    _expectSeparate(tester, ['A', 'C', 'D']);
  });

  testWidgets('bulk teardown releases all reserved toast positions', (
    tester,
  ) async {
    await _mount(tester);
    final first = _stack('A');
    final second = _stack('B');
    await tester.pumpAndSettle();
    await SuperOverlay.close(target: OverlayCloseTarget.allToasts);
    await tester.pumpAndSettle();
    await Future.wait([first.closed, second.closed]);
    _stack('C');
    await tester.pumpAndSettle();
    expect(_rect(tester, 'C').bottom, 600);
  });
}

class _CounterToast extends StatefulWidget {
  const _CounterToast();

  @override
  State<_CounterToast> createState() => _CounterToastState();
}

class _CounterToastState extends State<_CounterToast> {
  var count = 0;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 120,
    height: 60,
    child: TextButton(
      onPressed: () => setState(() => count++),
      child: Text('count $count'),
    ),
  );
}
