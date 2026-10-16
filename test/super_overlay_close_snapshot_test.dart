import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

import 'overlay_test_support.dart';

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
      home: const Scaffold(body: Text('base page')),
    ),
  );
  await tester.pumpAndSettle();
}

OverlayHandle<void> _show(
  String surface, {
  String? tag,
  bool minimumLoading = false,
}) {
  Widget content(BuildContext context) => Text('$surface content');
  return switch (surface) {
    'loading' => SuperOverlay.loading.show(
      builder: content,
      options: OverlayLoadingOptions(
        tag: tag,
        minimumVisibleDuration:
            minimumLoading ? const Duration(seconds: 2) : Duration.zero,
      ),
    ),
    'popup' => SuperOverlay.popup.show<void>(
      builder: (context, _) => content(context),
      options: OverlayPopupOptions(
        tag: tag,
        targetPointBuilder: (_, _) => const Offset(240, 180),
      ),
    ),
    'notification' => SuperOverlay.notify.alert(
      'notice',
      builder: content,
      options: OverlayNotifyOptions(tag: tag, displayDuration: null),
    ),
    'toast' => SuperOverlay.toast(
      'toast',
      builder: content,
      options: OverlayToastOptions(
        tag: tag,
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: const Duration(minutes: 1),
      ),
    ),
    _ => SuperOverlay.dialog.show<void>(
      builder: (context, _) => content(context),
      options: OverlayDialogOptions(tag: tag),
    ),
  };
}

void main() {
  for (final tagged in [false, true]) {
    for (final surface in [
      'dialog',
      'popup',
      'notification',
      'toast',
      'loading',
    ]) {
      testWidgets(
        'all close snapshots every surface before waiting; fresh $surface, tagged=$tagged',
        (tester) async {
          await _mount(tester);
          final tag = tagged ? 'flow' : null;
          final old = [
            _show('loading', tag: tag, minimumLoading: true),
            for (final family in ['dialog', 'popup', 'notification', 'toast'])
              _show(family, tag: tag),
          ];
          final unrelated = tagged ? _show('dialog', tag: 'other') : null;
          await tester.pumpAndSettle();
          await Future.wait(old.map((handle) => handle.visible));
          var allDone = false;
          final all = SuperOverlay.close(
            target: OverlayCloseTarget.all,
            tag: tag,
          ).then((_) => allDone = true);
          final fresh = _show(surface, tag: tag);
          await tester.pump();
          if (surface != 'loading') expect(allDone, isFalse);
          // Families other than the Loading must begin closing immediately.
          for (final handle in old.skip(1)) {
            expect(handle.isVisible, isFalse);
          }
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();
          await all;
          await Future.wait(old.map((handle) => handle.closed));
          await fresh.visible;
          expect(fresh.isVisible, isTrue);
          expect(allDone, isTrue);
          if (unrelated != null) expect(unrelated.isVisible, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('tagged toast bulk close does not join a later in-flight owner', (
    tester,
  ) async {
    final original = overlayConfig.toast;
    addTearDown(() => overlayConfig.toast = original);
    overlayConfig.toast = const ToastConfig(
      animationTime: Duration(milliseconds: 500),
      nonAnimationTypes: [NonAnimationType.open],
    );
    await _mount(tester);
    final a = _show('toast', tag: 'flow');
    final b = _show('toast', tag: 'flow');
    await tester.pumpAndSettle();
    var bulkDone = false;
    final bulk = SuperOverlay.close(
      target: OverlayCloseTarget.allToasts,
      tag: 'flow',
    ).then((_) => bulkDone = true);
    overlayConfig.toast = const ToastConfig(
      animationTime: Duration(seconds: 3),
      nonAnimationTypes: [NonAnimationType.open],
    );
    final fresh = _show('toast', tag: 'flow');
    await tester.pump();
    await fresh.visible;
    var freshClosed = false;
    final closing = fresh.close().then((_) => freshClosed = true);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.idle();
    expect(bulkDone, isTrue);
    expect(freshClosed, isFalse);
    await bulk;
    await Future.wait([a.closed, b.closed]);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await closing;
    expect(tester.takeException(), isNull);
  });
}
