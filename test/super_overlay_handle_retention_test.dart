import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

import 'support/vm_heap.dart';

class _Payload {
  final bytes = List<int>.filled(4096, 1);
}

OverlayHandle<void> _show(
  String surface,
  List<WeakReference<_Payload>> references, {
  OverlayStrategy strategy = OverlayStrategy.stack,
}) {
  final payload = _Payload();
  references.add(WeakReference(payload));
  Widget builder(BuildContext context) =>
      Text('payload ${payload.bytes.length}');
  return switch (surface) {
    'dialog' => SuperOverlay.dialog.show<void>(
      builder: (context, _) => builder(context),
      options: OverlayDialogOptions(tag: 'capture', strategy: strategy),
    ),
    'popup' => SuperOverlay.popup.show<void>(
      builder: (context, _) => builder(context),
      options: OverlayPopupOptions(
        tag: 'capture',
        strategy: strategy,
        targetPointBuilder: (_, _) => const Offset(200, 200),
      ),
    ),
    'notify' => SuperOverlay.notify.success(
      'capture',
      builder: builder,
      options: OverlayNotifyOptions(tag: 'capture', strategy: strategy),
    ),
    'loading' => SuperOverlay.loading.show(builder: builder),
    _ => SuperOverlay.toast(
      'capture',
      builder: builder,
      options: OverlayToastOptions(tag: 'capture', strategy: strategy),
    ),
  };
}

Future<void> _showThenClose(
  WidgetTester tester,
  String surface,
  List<WeakReference<_Payload>> refs,
  List<OverlayHandle<void>> handles,
) async {
  final handle = _show(surface, refs);
  handles.add(handle);
  await tester.pumpAndSettle();
  final closing = handle.close();
  await tester.pumpAndSettle();
  await closing;
  await handle.closed;
}

int _alive(List<WeakReference<_Payload>> references) =>
    references.where((reference) => reference.target != null).length;

Future<OverlayHandle<void>> _defaultLoadingAfterHostTeardown(
  WidgetTester tester,
  List<WeakReference<_Payload>> refs,
) async {
  final payload = _Payload();
  refs.add(WeakReference(payload));
  final integration = SuperOverlay.integration(
    loadingBuilder: (message) => Text('${payload.bytes.length} $message'),
  );
  try {
    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: [integration.observer],
        home: const Scaffold(),
      ),
    );
    final handle = SuperOverlay.loading.show(message: 'host factory');
    await tester.pumpAndSettle();
    return handle;
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  }
}

void main() {
  testWidgets(
    'a closed default Loading handle releases its removed host factory',
    (tester) async {
      final refs = <WeakReference<_Payload>>[];
      final handle = await _defaultLoadingAfterHostTeardown(tester, refs);
      await handle.closed;
      await tester.runAsync(collectHeapCounts);
      expect(_alive(refs), 0);
      expect(handle.isVisible, isFalse);
    },
  );
  for (final surface in ['dialog', 'popup', 'notify', 'loading', 'toast']) {
    for (final boundary in [
      'close',
      'replacement',
      'teardown',
      'before frame',
    ]) {
      testWidgets(
        '$surface releases content with retained handles after $boundary',
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
          final refs = <WeakReference<_Payload>>[];
          final handles = <OverlayHandle<void>>[];
          if (boundary == 'close') {
            for (var i = 0; i < 10; i++) {
              await _showThenClose(tester, surface, refs, handles);
            }
          } else {
            for (var i = 0; i < 10; i++) {
              handles.add(
                _show(
                  surface,
                  refs,
                  strategy:
                      boundary == 'replacement'
                          ? OverlayStrategy.replaceExisting
                          : OverlayStrategy.stack,
                ),
              );
              if (boundary != 'before frame') await tester.pumpAndSettle();
            }
            if (boundary == 'teardown') {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pumpAndSettle();
            } else {
              final closes = handles.map((handle) => handle.close()).toList();
              await tester.pumpAndSettle();
              await Future.wait(closes);
            }
            await Future.wait(handles.map((handle) => handle.closed));
          }
          await tester.runAsync(collectHeapCounts);
          expect(_alive(refs), 0);
          expect(
            handles.map((handle) => handle.isVisible),
            everyElement(false),
          );
          // Old callbacks remain harmless even though the handles are retained.
          for (final handle in handles) {
            handle.refresh();
            await handle.close();
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final surface in ['dialog', 'popup', 'notify', 'toast']) {
    testWidgets('$surface keepExisting releases unused and closed builders', (
      tester,
    ) async {
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
      final refs = <WeakReference<_Payload>>[];
      final handles = <OverlayHandle<void>>[];
      handles.add(_show(surface, refs));
      await tester.pumpAndSettle();
      for (var i = 0; i < 10; i++) {
        handles.add(
          _show(surface, refs, strategy: OverlayStrategy.keepExisting),
        );
      }
      await tester.pumpAndSettle();
      await tester.runAsync(collectHeapCounts);
      expect(_alive(refs), 1);
      final closing = handles.first.close();
      await tester.pumpAndSettle();
      await closing;
      await Future.wait(handles.map((handle) => handle.closed));
      await tester.runAsync(collectHeapCounts);
      expect(_alive(refs), 0);
      expect(handles.map((handle) => handle.isVisible), everyElement(false));
    });
  }
}
