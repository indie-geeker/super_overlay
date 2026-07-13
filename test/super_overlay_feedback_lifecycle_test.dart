import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';
import 'package:super_overlay/src/helper/overlay_manager.dart';

import 'overlay_test_support.dart';

Widget _buildFeedbackApp() {
  return MaterialApp(
    builder: SuperOverlay.init(),
    navigatorObservers: [SuperOverlay.observer],
    home: const Scaffold(body: SizedBox.shrink()),
  );
}

void main() {
  setUp(() {
    overlayConfig.loading = const LoadingConfig(
      animationTime: Duration(milliseconds: 200),
      nonAnimationTypes: <NonAnimationType>[],
    );
    overlayConfig.toast = const ToastConfig();
  });

  testWidgets('manual close advances the untagged toast queue', (tester) async {
    await tester.pumpWidget(_buildFeedbackApp());

    final first = SuperOverlay.toast(
      'First queued toast',
      options: const OverlayToastOptions(
        displayPolicy: OverlayToastDisplayPolicy.queue,
        displayDuration: Duration(minutes: 1),
      ),
    );
    final second = SuperOverlay.toast(
      'Second queued toast',
      options: const OverlayToastOptions(
        displayPolicy: OverlayToastDisplayPolicy.queue,
        displayDuration: Duration(minutes: 1),
      ),
    );
    var firstClosed = false;
    var secondVisible = false;
    first.closed.then((_) => firstClosed = true);
    second.visible.then((_) => secondVisible = true);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('First queued toast'), findsOneWidget);
    expect(find.text('Second queued toast'), findsNothing);
    expect(first.isVisible, isTrue);
    expect(second.isVisible, isFalse);

    final close = SuperOverlay.close(target: OverlayCloseTarget.toast);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await close;
    await tester.pump();
    await tester.idle();

    expect(firstClosed, isTrue);
    expect(secondVisible, isTrue);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);
    expect(find.text('First queued toast'), findsNothing);
    expect(find.text('Second queued toast'), findsOneWidget);

    final secondClose = second.close();
    await tester.pumpAndSettle();
    await secondClose;
  });

  testWidgets('host disposal settles a toast close already in flight', (
    tester,
  ) async {
    overlayConfig.toast = const ToastConfig(
      animationTime: Duration(seconds: 1),
      nonAnimationTypes: <NonAnimationType>[],
    );
    await tester.pumpWidget(_buildFeedbackApp());

    SuperOverlay.toast(
      'Closing toast',
      options: const OverlayToastOptions(displayDuration: Duration(minutes: 1)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final close = SuperOverlay.close(target: OverlayCloseTarget.toast);
    var closeCompleted = false;
    close.then((_) => closeCompleted = true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(closeCompleted, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.idle();

    expect(closeCompleted, isTrue);
    await close;
    await tester.pump(const Duration(seconds: 1));
    await tester.idle();
  });

  testWidgets(
    'loading close callers wait for minimum duration and dismissal animation',
    (tester) async {
      await tester.pumpWidget(_buildFeedbackApp());

      final handle = SuperOverlay.loading.show(
        message: 'Minimum loading',
        options: const OverlayLoadingOptions(
          tag: 'minimum-loading',
          minimumVisibleDuration: Duration(milliseconds: 500),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final handleClose = handle.close();
      final globalClose = SuperOverlay.close(
        target: OverlayCloseTarget.loading,
        tag: 'minimum-loading',
      );
      var handleCloseCompleted = false;
      var globalCloseCompleted = false;
      var closedCompleted = false;
      handleClose.then((_) => handleCloseCompleted = true);
      globalClose.then((_) => globalCloseCompleted = true);
      handle.closed.then((_) => closedCompleted = true);

      await tester.pump(const Duration(milliseconds: 399));
      await tester.idle();

      expect(handleCloseCompleted, isFalse);
      expect(globalCloseCompleted, isFalse);
      expect(closedCompleted, isFalse);
      expect(handle.isVisible, isTrue);
      expect(find.text('Minimum loading'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 199));
      await tester.idle();

      expect(handleCloseCompleted, isFalse);
      expect(globalCloseCompleted, isFalse);
      expect(closedCompleted, isFalse);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.idle();
      await handleClose;
      await globalClose;
      await handle.closed;

      expect(handleCloseCompleted, isTrue);
      expect(globalCloseCompleted, isTrue);
      expect(closedCompleted, isTrue);
      expect(handle.isVisible, isFalse);
      expect(find.text('Minimum loading'), findsNothing);
    },
  );

  testWidgets('host disposal settles a pending loading close', (tester) async {
    await tester.pumpWidget(_buildFeedbackApp());

    final handle = SuperOverlay.loading.show(
      message: 'Disposed loading',
      options: const OverlayLoadingOptions(
        minimumVisibleDuration: Duration(minutes: 1),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final close = handle.close();
    var closeCompleted = false;
    var closedCompleted = false;
    close.then((_) => closeCompleted = true);
    handle.closed.then((_) => closedCompleted = true);
    await tester.idle();

    expect(closeCompleted, isFalse);
    expect(closedCompleted, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.idle();
    await close;
    await handle.closed;

    expect(closeCompleted, isTrue);
    expect(closedCompleted, isTrue);
  });

  testWidgets('new loading settles the replaced pending close', (tester) async {
    await tester.pumpWidget(_buildFeedbackApp());

    final first = SuperOverlay.loading.show(
      message: 'Replaced loading',
      options: const OverlayLoadingOptions(
        minimumVisibleDuration: Duration(minutes: 1),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final firstClose = first.close();
    var firstCloseCompleted = false;
    firstClose.then((_) => firstCloseCompleted = true);
    await tester.idle();
    expect(firstCloseCompleted, isFalse);

    final second = SuperOverlay.loading.show(message: 'Current loading');
    await tester.pump();
    await tester.idle();
    await firstClose;
    await first.closed;

    expect(firstCloseCompleted, isTrue);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);
    expect(find.text('Replaced loading'), findsNothing);
    expect(find.text('Current loading'), findsOneWidget);

    final secondClose = second.close();
    await tester.pumpAndSettle();
    await secondClose;
  });

  testWidgets('new loading survives an active dismissal operation', (
    tester,
  ) async {
    await tester.pumpWidget(_buildFeedbackApp());

    final first = SuperOverlay.loading.show(message: 'Closing loading');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final firstClose = first.close();
    final second = SuperOverlay.loading.show(message: 'Next loading');
    var secondClosed = false;
    second.closed.then((_) => secondClosed = true);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.idle();
    await firstClose;
    await tester.pump();
    await tester.idle();

    expect(secondClosed, isFalse);
    expect(second.isVisible, isTrue);
    expect(find.text('Closing loading'), findsNothing);
    expect(find.text('Next loading'), findsOneWidget);

    final secondClose = second.close();
    await tester.pump(const Duration(milliseconds: 200));
    await secondClose;
  });

  testWidgets(
    'stale loading handle cannot close a synchronous same-tag replacement',
    (tester) async {
      await tester.pumpWidget(_buildFeedbackApp());

      final first = SuperOverlay.loading.show(
        message: 'First tagged loading',
        options: const OverlayLoadingOptions(tag: 'job'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final second = SuperOverlay.loading.show(
        message: 'Second tagged loading',
        options: const OverlayLoadingOptions(tag: 'job'),
      );
      final staleClose = first.close();

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.idle();
      await staleClose;

      expect(second.isVisible, isTrue);
      expect(find.text('First tagged loading'), findsNothing);
      expect(find.text('Second tagged loading'), findsOneWidget);

      final secondClose = second.close();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.idle();
      await secondClose;
      await second.closed;

      expect(second.isVisible, isFalse);
      expect(find.text('Second tagged loading'), findsNothing);
    },
  );

  testWidgets(
    'stale loading handle cannot cancel a deferred same-tag replacement',
    (tester) async {
      await tester.pumpWidget(_buildFeedbackApp());

      final first = SuperOverlay.loading.show(
        message: 'Closing tagged loading',
        options: const OverlayLoadingOptions(tag: 'job'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final activeClose = SuperOverlay.close(
        target: OverlayCloseTarget.loading,
        tag: 'job',
      );
      final second = SuperOverlay.loading.show(
        message: 'Deferred tagged loading',
        options: const OverlayLoadingOptions(tag: 'job'),
      );
      Object? secondVisibleError;
      second.visible.then(
        (_) {},
        onError: (Object error) {
          secondVisibleError = error;
        },
      );

      await tester.pump(const Duration(milliseconds: 199));
      final staleClose = first.close();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      await tester.idle();
      await activeClose;
      await staleClose;

      expect(secondVisibleError, isNull);
      expect(second.isVisible, isTrue);
      expect(find.text('Closing tagged loading'), findsNothing);
      expect(find.text('Deferred tagged loading'), findsOneWidget);

      final secondClose = second.close();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.idle();
      await secondClose;
      await second.closed;

      expect(second.isVisible, isFalse);
      expect(find.text('Deferred tagged loading'), findsNothing);
    },
  );

  testWidgets('deferred loading close cancels before it renders', (
    tester,
  ) async {
    await tester.pumpWidget(_buildFeedbackApp());

    final first = SuperOverlay.loading.show(message: 'Closing first');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final firstClose = first.close();
    final second = SuperOverlay.loading.show(message: 'Cancelled next');
    Object? visibleError;
    var closedCompleted = false;
    second.visible.then(
      (_) {},
      onError: (Object error) {
        visibleError = error;
      },
    );
    second.closed.then((_) => closedCompleted = true);

    final secondClose = second.close();
    await tester.idle();

    expect(visibleError, isA<StateError>());
    expect(closedCompleted, isTrue);
    await secondClose;

    await tester.pump(const Duration(milliseconds: 200));
    await tester.idle();
    await firstClose;

    expect(second.isVisible, isFalse);
    expect(find.text('Cancelled next'), findsNothing);
  });

  testWidgets('host disposal cancels a deferred loading show', (tester) async {
    await tester.pumpWidget(_buildFeedbackApp());

    final first = SuperOverlay.loading.show(message: 'Closing before dispose');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final firstClose = first.close();
    final second = SuperOverlay.loading.show(message: 'Disposed next');
    Object? visibleError;
    var closedCompleted = false;
    second.visible.then(
      (_) {},
      onError: (Object error) {
        visibleError = error;
      },
    );
    second.closed.then((_) => closedCompleted = true);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.idle();

    expect(visibleError, isA<StateError>());
    expect(closedCompleted, isTrue);
    expect(second.isVisible, isFalse);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.idle();
    await firstClose;
    await second.closed;

    expect(find.text('Disposed next'), findsNothing);
  });

  testWidgets('stale deferred loading cannot swallow a replacement close', (
    tester,
  ) async {
    await tester.pumpWidget(_buildFeedbackApp());

    SuperOverlay.loading.show(message: 'Closing original');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final directClose = OverlayManager.instance.loadingOverlay.dismiss();
    OverlayHandle<void>? replacement;
    Future<void>? replacementClose;
    var replacementCloseCompleted = false;
    Object? replacementVisibleError;
    var replacementClosed = false;
    directClose.then((_) {
      replacement = SuperOverlay.loading.show(message: 'Listener replacement');
      replacement!.visible.then(
        (_) {},
        onError: (Object error) {
          replacementVisibleError = error;
        },
      );
      replacement!.closed.then((_) => replacementClosed = true);
      replacementClose = SuperOverlay.close(target: OverlayCloseTarget.loading);
      replacementClose!.then((_) => replacementCloseCompleted = true);
    });

    final deferred = SuperOverlay.loading.show(message: 'Stale deferred');
    Object? deferredVisibleError;
    var deferredClosed = false;
    deferred.visible.then(
      (_) {},
      onError: (Object error) {
        deferredVisibleError = error;
      },
    );
    deferred.closed.then((_) => deferredClosed = true);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.idle();

    expect(replacement, isNotNull);
    expect(deferredVisibleError, isA<StateError>());
    expect(deferredClosed, isTrue);
    expect(replacementVisibleError, isA<StateError>());
    expect(replacementClosed, isTrue);
    expect(replacementCloseCompleted, isTrue);

    await directClose;
    await replacementClose;
    await replacement!.closed;

    await tester.pump();
    await tester.idle();

    expect(replacementCloseCompleted, isTrue);
    expect(replacement!.isVisible, isFalse);
    expect(find.text('Listener replacement'), findsNothing);
    expect(find.text('Stale deferred'), findsNothing);
  });

  testWidgets('tagged loading close joins an active dismissal operation', (
    tester,
  ) async {
    await tester.pumpWidget(_buildFeedbackApp());

    final handle = SuperOverlay.loading.show(
      message: 'Tagged loading',
      options: const OverlayLoadingOptions(tag: 'sync-loading'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final handleClose = handle.close();
    final taggedClose = SuperOverlay.close(
      target: OverlayCloseTarget.loading,
      tag: 'sync-loading',
    );
    var handleCloseCompleted = false;
    var taggedCloseCompleted = false;
    handleClose.then((_) => handleCloseCompleted = true);
    taggedClose.then((_) => taggedCloseCompleted = true);

    await tester.pump(const Duration(milliseconds: 199));
    await tester.idle();

    expect(handleCloseCompleted, isFalse);
    expect(taggedCloseCompleted, isFalse);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.idle();
    await handleClose;
    await taggedClose;

    expect(handleCloseCompleted, isTrue);
    expect(taggedCloseCompleted, isTrue);
    expect(handle.isVisible, isFalse);
  });
}
