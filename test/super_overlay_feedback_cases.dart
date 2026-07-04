import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

import 'overlay_test_support.dart';

Widget buildFeedbackOverlayApp(
  Widget child, {
  SuperOverlayToastBuilder? toastBuilder,
  SuperOverlayLoadingBuilder? loadingBuilder,
}) {
  return MaterialApp(
    builder: SuperOverlay.init(
      toastBuilder: toastBuilder,
      loadingBuilder: loadingBuilder,
    ),
    navigatorObservers: [SuperOverlay.observer],
    home: Scaffold(body: child),
  );
}

void main() {
  registerFeedbackOverlayTests();
}

void registerFeedbackOverlayTests() {
  setUp(() {
    overlayConfig.loading = const LoadingConfig();
    overlayConfig.toast = const ToastConfig();
  });

  testWidgets('loading command shows and closes by handle', (tester) async {
    await tester.pumpWidget(buildFeedbackOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.loading.show(message: 'Loading...');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading...'), findsOneWidget);

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    await handle.closed;

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('loading waits for minimumVisibleDuration before closing', (
    tester,
  ) async {
    await tester.pumpWidget(buildFeedbackOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.loading.show(
      message: 'Hold',
      options: const OverlayLoadingOptions(
        minimumVisibleDuration: Duration(milliseconds: 500),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final close = handle.close();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Hold'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    await close;
    expect(find.text('Hold'), findsNothing);
  });

  testWidgets('repeated loading commands refresh the singleton entry', (
    tester,
  ) async {
    await tester.pumpWidget(buildFeedbackOverlayApp(const SizedBox.shrink()));

    final first = SuperOverlay.loading.show(message: 'First Loading');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final second = SuperOverlay.loading.show(message: 'Second Loading');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('First Loading'), findsNothing);
    expect(find.text('Second Loading'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);

    await second.close();
    await tester.pumpAndSettle();
  });

  testWidgets('init loadingBuilder changes default loading widget', (
    tester,
  ) async {
    final originalLoading = overlayConfig.loading;
    addTearDown(() => overlayConfig.loading = originalLoading);

    await tester.pumpWidget(
      buildFeedbackOverlayApp(
        const SizedBox.shrink(),
        loadingBuilder: (message) => Text('Default Loading $message'),
      ),
    );

    final handle = SuperOverlay.loading.show(message: 'Init Load');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Default Loading Init Load'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await handle.close();
    await tester.pumpAndSettle();
  });

  testWidgets('init toastBuilder changes default toast widget', (tester) async {
    final originalToast = overlayConfig.toast;
    addTearDown(() => overlayConfig.toast = originalToast);

    await tester.pumpWidget(
      buildFeedbackOverlayApp(
        const SizedBox.shrink(),
        toastBuilder: (message) => Text('Default Toast $message'),
      ),
    );

    final handle = SuperOverlay.toast(
      'Init Saved',
      options: const OverlayToastOptions(displayDuration: Duration(seconds: 1)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Default Toast Init Saved'), findsOneWidget);

    await handle.close();
    await tester.pumpAndSettle();
  });

  testWidgets('per-call toast builder overrides init default builder', (
    tester,
  ) async {
    final originalToast = overlayConfig.toast;
    addTearDown(() => overlayConfig.toast = originalToast);

    await tester.pumpWidget(
      buildFeedbackOverlayApp(
        const SizedBox.shrink(),
        toastBuilder: (message) => Text('Default Toast $message'),
      ),
    );

    final handle = SuperOverlay.toast(
      'Override',
      builder: (_) => const Text('Per Call Toast'),
      options: const OverlayToastOptions(displayDuration: Duration(seconds: 1)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Per Call Toast'), findsOneWidget);
    expect(find.text('Default Toast Override'), findsNothing);

    await handle.close();
    await tester.pumpAndSettle();
  });

  testWidgets('toast command visible future completes while displayed', (
    tester,
  ) async {
    await tester.pumpWidget(buildFeedbackOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.toast(
      'Await Toast Visible',
      options: const OverlayToastOptions(displayDuration: Duration(seconds: 1)),
    );

    await tester.pump();
    await handle.visible;

    expect(find.text('Await Toast Visible'), findsOneWidget);
    expect(handle.isVisible, isTrue);

    await handle.close();
    await tester.pumpAndSettle();
  });

  testWidgets('toast closed future completes after auto-dismiss', (
    tester,
  ) async {
    var completed = false;

    await tester.pumpWidget(buildFeedbackOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.toast(
      'Await Toast Dismiss',
      options: const OverlayToastOptions(
        displayDuration: Duration(milliseconds: 300),
      ),
    );
    handle.closed.then((_) => completed = true);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(completed, isFalse);

    await tester.pump(const Duration(milliseconds: 350));
    await handle.closed;

    expect(completed, isTrue);
    expect(find.text('Await Toast Dismiss'), findsNothing);
  });

  testWidgets('toast auto-dismisses after displayDuration', (tester) async {
    await tester.pumpWidget(buildFeedbackOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.toast(
      'Saved',
      options: const OverlayToastOptions(
        displayDuration: Duration(milliseconds: 300),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Saved'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await handle.closed;

    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('replaceLatest toast replaces the previous toast', (
    tester,
  ) async {
    await tester.pumpWidget(buildFeedbackOverlayApp(const SizedBox.shrink()));

    SuperOverlay.toast(
      'First Last',
      options: const OverlayToastOptions(
        displayPolicy: OverlayToastDisplayPolicy.replaceLatest,
        displayDuration: Duration(seconds: 1),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final second = SuperOverlay.toast(
      'Second Last',
      options: const OverlayToastOptions(
        displayPolicy: OverlayToastDisplayPolicy.replaceLatest,
        displayDuration: Duration(seconds: 1),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('First Last'), findsNothing);
    expect(find.text('Second Last'), findsOneWidget);

    await second.close();
    await tester.pumpAndSettle();
  });

  testWidgets('queue toast displays messages in order', (tester) async {
    await tester.pumpWidget(buildFeedbackOverlayApp(const SizedBox.shrink()));

    SuperOverlay.toast(
      'First Normal',
      options: const OverlayToastOptions(
        displayDuration: Duration(milliseconds: 300),
      ),
    );
    final second = SuperOverlay.toast(
      'Second Normal',
      options: const OverlayToastOptions(
        displayDuration: Duration(milliseconds: 300),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('First Normal'), findsOneWidget);
    expect(find.text('Second Normal'), findsNothing);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('First Normal'), findsNothing);
    expect(find.text('Second Normal'), findsOneWidget);

    await second.close();
    await tester.pumpAndSettle();
  });

  testWidgets('refreshActive toast updates existing toast content', (
    tester,
  ) async {
    await tester.pumpWidget(buildFeedbackOverlayApp(const SizedBox.shrink()));

    SuperOverlay.toast(
      'First Refresh',
      options: const OverlayToastOptions(
        displayPolicy: OverlayToastDisplayPolicy.refreshActive,
        displayDuration: Duration(seconds: 1),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final second = SuperOverlay.toast(
      'Second Refresh',
      options: const OverlayToastOptions(
        displayPolicy: OverlayToastDisplayPolicy.refreshActive,
        displayDuration: Duration(seconds: 1),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('First Refresh'), findsNothing);
    expect(find.text('Second Refresh'), findsOneWidget);

    await second.close();
    await tester.pumpAndSettle();
  });

  testWidgets('stack toast shows multiple entries', (tester) async {
    await tester.pumpWidget(buildFeedbackOverlayApp(const SizedBox.shrink()));

    final first = SuperOverlay.toast(
      'First Multi',
      options: const OverlayToastOptions(
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(seconds: 1),
      ),
    );
    final second = SuperOverlay.toast(
      'Second Multi',
      options: const OverlayToastOptions(
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(seconds: 1),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('First Multi'), findsOneWidget);
    expect(find.text('Second Multi'), findsOneWidget);

    await first.close();
    await second.close();
    await tester.pumpAndSettle();
  });

  testWidgets('stack toast entries do not visually overlap', (tester) async {
    await tester.pumpWidget(buildFeedbackOverlayApp(const SizedBox.shrink()));

    final handles = [
      SuperOverlay.toast(
        'Stack One',
        options: const OverlayToastOptions(
          displayPolicy: OverlayToastDisplayPolicy.stack,
          alignment: Alignment.topRight,
          displayDuration: Duration(seconds: 1),
        ),
      ),
      SuperOverlay.toast(
        'Stack Two',
        options: const OverlayToastOptions(
          displayPolicy: OverlayToastDisplayPolicy.stack,
          alignment: Alignment.topRight,
          displayDuration: Duration(seconds: 1),
        ),
      ),
      SuperOverlay.toast(
        'Stack Three',
        options: const OverlayToastOptions(
          displayPolicy: OverlayToastDisplayPolicy.stack,
          alignment: Alignment.topRight,
          displayDuration: Duration(seconds: 1),
        ),
      ),
    ];
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final firstTop = tester.getTopLeft(find.text('Stack One')).dy;
    final secondTop = tester.getTopLeft(find.text('Stack Two')).dy;
    final thirdTop = tester.getTopLeft(find.text('Stack Three')).dy;

    expect(secondTop, greaterThan(firstTop));
    expect(thirdTop, greaterThan(secondTop));

    for (final handle in handles) {
      await handle.close();
    }
    await tester.pumpAndSettle();
  });
}
