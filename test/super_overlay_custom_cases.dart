import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

Widget buildCustomOverlayApp(Widget child) {
  return MaterialApp(
    builder: SuperOverlay.init(),
    navigatorObservers: [SuperOverlay.observer],
    home: Scaffold(body: child),
  );
}

void main() {
  registerCustomOverlayTests();
}

void registerCustomOverlayTests() {
  setUp(() {
    SuperOverlay.config.custom = const CustomDialogConfig();
    SuperOverlay.config.attach = const AttachDialogConfig();
    SuperOverlay.config.loading = const LoadingConfig();
    SuperOverlay.config.notify = const NotifyConfig();
    SuperOverlay.config.toast = const ToastConfig();
  });

  testWidgets('initializes with SuperOverlay command host', (tester) async {
    await tester.pumpWidget(buildCustomOverlayApp(const Text('home')));

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('dialog command renders and closes with a result', (
    tester,
  ) async {
    late OverlayHandle<String> handle;

    await tester.pumpWidget(
      buildCustomOverlayApp(
        ElevatedButton(
          onPressed: () {
            handle = SuperOverlay.dialog.show<String>(
              builder: (_) => const Text('Dialog Content'),
              options: const OverlayDialogOptions(tag: 'profile'),
            );
          },
          child: const Text('Show'),
        ),
      ),
    );

    expect(find.text('Dialog Content'), findsNothing);

    await tester.tap(find.text('Show'));
    await tester.pump();
    await handle.visible;

    expect(find.text('Dialog Content'), findsOneWidget);
    expect(SuperOverlay.checkExist(tag: 'profile'), isTrue);

    final closed = expectLater(handle.closed, completion('closed'));
    final close = handle.close('closed');
    await tester.pumpAndSettle();
    await close;
    await closed;

    expect(find.text('Dialog Content'), findsNothing);
    expect(SuperOverlay.checkExist(tag: 'profile'), isFalse);
  });

  testWidgets('mask tap dismisses a dialog command when enabled', (
    tester,
  ) async {
    late OverlayHandle<void> handle;

    await tester.pumpWidget(
      buildCustomOverlayApp(
        ElevatedButton(
          onPressed: () {
            handle = SuperOverlay.dialog.show<void>(
              builder: (_) => const Text('Mask Dialog'),
              options: const OverlayDialogOptions(dismissOnMaskTap: true),
            );
          },
          child: const Text('Show'),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(find.text('Mask Dialog'), findsOneWidget);

    await tester.tapAt(const Offset(790, 590));
    await tester.pumpAndSettle();
    await handle.closed;

    expect(find.text('Mask Dialog'), findsNothing);
    expect(handle.isVisible, isFalse);
  });

  testWidgets('command surfaces cover loading toast popup and notify', (
    tester,
  ) async {
    late BuildContext targetContext;

    await tester.pumpWidget(
      buildCustomOverlayApp(
        Builder(
          builder: (context) {
            targetContext = context;
            return const Text('target');
          },
        ),
      ),
    );

    final loading = SuperOverlay.loading.show(message: 'Loading...');
    final toast = SuperOverlay.toast('Saved');
    final popup = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Popup Menu'),
    );
    final notify = SuperOverlay.notify.success('Done');

    await tester.pump();

    expect(find.text('Loading...'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Popup Menu'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await loading.close();
    await toast.close();
    await popup.close();
    await notify.close();
    await tester.pumpAndSettle();
  });

  testWidgets('dialog displayDuration auto closes and settles once', (
    tester,
  ) async {
    var closedCount = 0;

    await tester.pumpWidget(buildCustomOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Auto Dialog'),
      options: const OverlayDialogOptions(
        tag: 'auto',
        displayDuration: Duration(milliseconds: 300),
      ),
    );
    handle.closed.then((_) => closedCount++);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Auto Dialog'), findsOneWidget);
    expect(closedCount, 0);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await handle.closed;

    expect(find.text('Auto Dialog'), findsNothing);
    expect(closedCount, 1);

    await handle.close();
    await tester.pump();
    expect(closedCount, 1);
  });

  testWidgets('replaceExisting strategy replaces a tagged dialog', (
    tester,
  ) async {
    await tester.pumpWidget(buildCustomOverlayApp(const SizedBox.shrink()));

    final first = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('First Single'),
      options: const OverlayDialogOptions(tag: 'single'),
    );
    await tester.pumpAndSettle();

    final second = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Second Single'),
      options: const OverlayDialogOptions(
        tag: 'single',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First Single'), findsNothing);
    expect(find.text('Second Single'), findsOneWidget);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);
    expect(SuperOverlay.checkExist(tag: 'single'), isTrue);

    await second.close();
    await tester.pumpAndSettle();
  });

  testWidgets('keepExisting strategy reuses and refreshes a tagged dialog', (
    tester,
  ) async {
    await tester.pumpWidget(buildCustomOverlayApp(const SizedBox.shrink()));

    var count = 0;
    final first = SuperOverlay.dialog.show<String>(
      builder: (_) => Text('Kept Dialog $count'),
      options: const OverlayDialogOptions(tag: 'keep-existing'),
    );
    await tester.pumpAndSettle();
    await first.visible;

    final second = SuperOverlay.dialog.show<String>(
      builder: (_) => const Text('Ignored Keep Existing Dialog'),
      options: const OverlayDialogOptions(
        tag: 'keep-existing',
        strategy: OverlayStrategy.keepExisting,
      ),
    );
    await tester.pumpAndSettle();
    await second.visible;

    expect(find.text('Kept Dialog 0'), findsOneWidget);
    expect(find.text('Ignored Keep Existing Dialog'), findsNothing);
    expect(first.isVisible, isTrue);
    expect(second.isVisible, isTrue);

    count = 1;
    second.refresh();
    await tester.pumpAndSettle();

    expect(find.text('Kept Dialog 0'), findsNothing);
    expect(find.text('Kept Dialog 1'), findsOneWidget);
    expect(find.text('Ignored Keep Existing Dialog'), findsNothing);

    final firstClosed = expectLater(first.closed, completion('closed'));
    final secondClosed = expectLater(second.closed, completion('closed'));
    final close = second.close('closed');
    await tester.pumpAndSettle();
    await close;
    await firstClosed;
    await secondClosed;

    expect(find.text('Kept Dialog 1'), findsNothing);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isFalse);
  });

  testWidgets('close is idempotent and preserves the first result', (
    tester,
  ) async {
    await tester.pumpWidget(buildCustomOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.dialog.show<String>(
      builder: (_) => const Text('Idempotent Dialog'),
      options: const OverlayDialogOptions(tag: 'idempotent'),
    );

    await tester.pumpAndSettle();
    expect(find.text('Idempotent Dialog'), findsOneWidget);

    final closed = expectLater(handle.closed, completion('first'));
    final firstClose = handle.close('first');
    final secondClose = handle.close('second');
    await tester.pumpAndSettle();
    await firstClose;
    await secondClose;
    await closed;

    expect(find.text('Idempotent Dialog'), findsNothing);
    expect(handle.isVisible, isFalse);
  });

  testWidgets('visible completes before closed', (tester) async {
    await tester.pumpWidget(buildCustomOverlayApp(const SizedBox.shrink()));

    final events = <String>[];
    final handle = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Lifecycle Dialog'),
    );
    handle.visible.then((_) => events.add('visible'));
    handle.closed.then((_) => events.add('closed'));

    await tester.pump();
    await handle.visible;

    expect(events, ['visible']);
    expect(find.text('Lifecycle Dialog'), findsOneWidget);

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    await handle.closed;

    expect(events, ['visible', 'closed']);
  });

  testWidgets('refresh rebuilds command dialog content', (tester) async {
    var count = 0;

    await tester.pumpWidget(buildCustomOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.dialog.show<void>(
      builder: (_) => Text('Count $count'),
      options: const OverlayDialogOptions(tag: 'refresh'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Count 0'), findsOneWidget);

    count = 1;
    handle.refresh();
    await tester.pumpAndSettle();

    expect(find.text('Count 0'), findsNothing);
    expect(find.text('Count 1'), findsOneWidget);

    await handle.close();
    await tester.pumpAndSettle();
  });
}
