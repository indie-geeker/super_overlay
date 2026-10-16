import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';
import 'package:super_overlay/src/config/overlay_config.dart';
import 'package:super_overlay/src/config/toast_config.dart';
import 'package:super_overlay/src/kit/debounce_utils.dart';

import 'support/vm_heap.dart';

class _Payload {
  _Payload(this.id);

  final int id;
  final bytes = List<int>.filled(1024, 7);
}

Future<void> _collect() async {
  await collectHeapCounts();
}

Future<void> _mount(WidgetTester tester) async {
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
      home: const Scaffold(),
    ),
  );
}

void _refreshUnobserved(int id, OverlayStrategy strategy) {
  SuperOverlay.toast(
    'unobserved $id',
    options: OverlayToastOptions(
      tag: 'unobserved-$id',
      strategy: strategy,
      displayPolicy: OverlayToastDisplayPolicy.refreshActive,
      displayDuration: const Duration(minutes: 1),
    ),
  );
}

OverlayHandle<void> _add(int id, List<WeakReference<_Payload>> references) {
  final payload = _Payload(id);
  references.add(WeakReference(payload));
  return SuperOverlay.toast(
    'payload',
    builder: (_) => Text('payload ${payload.id} / ${payload.bytes.length}'),
    options: OverlayToastOptions(
      tag: 'capture-$id',
      displayPolicy: OverlayToastDisplayPolicy.refreshActive,
      displayDuration: const Duration(minutes: 1),
    ),
  );
}

int _alive(List<WeakReference<_Payload>> references) =>
    references.where((reference) => reference.target != null).length;

void main() {
  for (final renderEach in [false, true]) {
    for (final strategy in [
      OverlayStrategy.stack,
      OverlayStrategy.keepExisting,
    ]) {
      testWidgets(
        'unobserved refresh metadata stays bounded, render=$renderEach strategy=$strategy',
        (tester) async {
          await _mount(tester);
          for (var i = 0; i < 100; i++) {
            _refreshUnobserved(i, strategy);
            if (renderEach) await tester.pump();
          }
          await tester.pumpAndSettle();
          final initial = (await tester.runAsync(collectHeapCounts))!;
          for (var i = 100; i < 1100; i++) {
            _refreshUnobserved(i, strategy);
            if (renderEach) await tester.pump();
          }
          await tester.pumpAndSettle();
          final later = (await tester.runAsync(collectHeapCounts))!;
          expect(later['_CommandOverlayLifecycle'] ?? 0, 0);
          expect(later['OverlayHandle'] ?? 0, 0);
          expect(later['SuperOverlayController'], 1);
          expect(later['_ToastRequest'], 1);
          for (final name in ['_Future', '_FutureListener']) {
            expect(
              later[name] ?? 0,
              lessThanOrEqualTo((initial[name] ?? 0) + 16),
              reason: name,
            );
          }
          final closing = SuperOverlay.close(target: OverlayCloseTarget.toast);
          await tester.pumpAndSettle();
          await closing;
          final closed = (await tester.runAsync(collectHeapCounts))!;
          expect(closed['SuperOverlayController'] ?? 0, 0);
        },
      );
    }
  }

  testWidgets(
    'historical Toast close futures can be first read after lane closure',
    (tester) async {
      await _mount(tester);
      final handles = List.generate(
        10,
        (i) => SuperOverlay.toast(
          'late $i',
          options: const OverlayToastOptions(
            displayPolicy: OverlayToastDisplayPolicy.refreshActive,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final closing = handles.last.close();
      await tester.pumpAndSettle();
      await closing;
      for (final handle in handles) {
        expect(handle.closed, same(handle.closed));
        await handle.closed;
        expect(handle.isVisible, isFalse);
      }
    },
  );

  for (final cancel in [false, true]) {
    testWidgets(
      'Toast close observation before replacement activation, cancel=$cancel',
      (tester) async {
        await _mount(tester);
        SuperOverlay.toast(
          'old',
          options: const OverlayToastOptions(tag: 'replace'),
        );
        await tester.pumpAndSettle();
        final next = SuperOverlay.toast(
          'next',
          options: const OverlayToastOptions(
            tag: 'replace',
            strategy: OverlayStrategy.replaceExisting,
            displayPolicy: OverlayToastDisplayPolicy.refreshActive,
          ),
        );
        var completed = false;
        final closed = next.closed.then((_) => completed = true);
        final closing = cancel ? next.close() : null;
        await tester.pumpAndSettle();
        expect(completed, cancel);
        if (cancel) {
          await closing;
          await expectLater(next.visible, throwsStateError);
        } else {
          await next.visible;
          final laterClosing = next.close();
          await tester.pumpAndSettle();
          await laterClosing;
        }
        await closed;
        expect(completed, isTrue);
      },
    );
  }

  testWidgets('rejected Toast visible fails without reading closed first', (
    tester,
  ) async {
    await _mount(tester);
    final config = overlayConfig.toast;
    overlayConfig.toast = const ToastConfig(debounce: true);
    DebounceUtils.instance.reset();
    addTearDown(() {
      overlayConfig.toast = config;
      DebounceUtils.instance.reset();
    });
    SuperOverlay.toast('accepted');
    final rejected = SuperOverlay.toast('rejected');
    await expectLater(rejected.visible, throwsStateError);
    expect(rejected.isVisible, isFalse);
    await rejected.closed;
  });

  for (final renderEach in [false, true]) {
    testWidgets(
      'refresh lane releases superseded captures with retained handles, render each=$renderEach',
      (tester) async {
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
            home: const Scaffold(),
          ),
        );
        final references = <WeakReference<_Payload>>[];
        final handles = <OverlayHandle<void>>[];
        var closed = 0;
        for (var i = 0; i < 100; i++) {
          final handle = _add(i, references);
          handles.add(handle);
          handle.closed.then((_) => closed++);
          if (renderEach) await tester.pump();
        }
        await tester.pumpAndSettle();
        await handles.last.visible;
        await tester.runAsync(_collect);
        expect(_alive(references), 1);
        expect(closed, 0);
        expect(
          handles.take(99).map((handle) => handle.isVisible),
          everyElement(false),
        );
        expect(handles.last.isVisible, isTrue);
        handles.first.refresh();
        await handles.first.close();
        await tester.pump();
        expect(find.text('payload 99 / 1024'), findsOneWidget);
        expect(closed, 0);
        final closing = handles.last.close();
        await tester.pumpAndSettle();
        await closing;
        await Future.wait(handles.map((handle) => handle.closed));
        expect(closed, 100);
        // The handles remain strongly held through this second collection.
        await tester.runAsync(_collect);
        expect(_alive(references), 0);
        expect(handles.map((handle) => handle.isVisible), everyElement(false));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
