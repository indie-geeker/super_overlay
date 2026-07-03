import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

Widget _buildCommandOverlayApp(Widget child) {
  return MaterialApp(
    builder: SuperOverlay.init(),
    navigatorObservers: [SuperOverlay.observer],
    home: child,
  );
}

Future<bool> _completesWithin<T>(Future<T> future) {
  return future
      .then((_) => true)
      .timeout(const Duration(milliseconds: 100), onTimeout: () => false);
}

void main() {
  setUp(() {
    SuperOverlay.config.custom = const CustomDialogConfig();
    SuperOverlay.config.attach = const AttachDialogConfig();
    SuperOverlay.config.notify = const NotifyConfig();
    SuperOverlay.config.toast = const ToastConfig();
  });

  testWidgets('toast command shows a message and returns a handle', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.toast('Saved');

    await tester.pump();
    await handle.visible;
    expect(find.text('Saved'), findsOneWidget);
    expect(handle.isVisible, isTrue);

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    expect(find.text('Saved'), findsNothing);
    expect(handle.isVisible, isFalse);
  });

  testWidgets('loading command can be shown and closed through its handle', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.loading.show(message: 'Syncing');

    await tester.pump();
    expect(find.text('Syncing'), findsOneWidget);
    expect(handle.isVisible, isTrue);

    final closed = expectLater(handle.closed, completes);
    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    await closed;
    expect(find.text('Syncing'), findsNothing);
    expect(handle.isVisible, isFalse);
  });

  testWidgets(
    'repeated loading commands do not strand earlier singleton handles',
    (tester) async {
      await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

      final first = SuperOverlay.loading.show(
        message: 'First loading',
        options: const OverlayLoadingOptions(tag: 'first-loading'),
      );
      await tester.pump();
      expect(find.text('First loading'), findsOneWidget);

      final second = SuperOverlay.loading.show(
        message: 'Second loading',
        options: const OverlayLoadingOptions(tag: 'second-loading'),
      );
      await tester.pump();

      expect(find.text('First loading'), findsNothing);
      expect(find.text('Second loading'), findsOneWidget);

      var firstClosed = false;
      final firstClosedProbe = first.closed.then((_) => firstClosed = true);
      await tester.pump();
      expect(firstClosed, isTrue);
      await firstClosedProbe;

      var secondClosed = false;
      final secondClosedProbe = second.closed.then((_) => secondClosed = true);
      final close = first.close();
      await tester.pump();
      await close;

      expect(secondClosed, isFalse);
      expect(find.text('Second loading'), findsOneWidget);
      expect(second.isVisible, isTrue);

      final secondClose = second.close();
      await tester.pumpAndSettle();
      await secondClose;

      expect(secondClosed, isTrue);
      await secondClosedProbe;
      expect(find.text('Second loading'), findsNothing);
    },
  );

  testWidgets('dialog command exposes a closed future with the result', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.dialog.show<String>(
      builder: (_) => const Center(child: Text('Confirm changes')),
      options: const OverlayDialogOptions(tag: 'confirm-dialog'),
    );

    await tester.pump();
    expect(find.text('Confirm changes'), findsOneWidget);
    expect(handle.isVisible, isTrue);

    final closed = expectLater(handle.closed, completion('confirmed'));
    final close = handle.close('confirmed');
    await tester.pumpAndSettle();
    await close;
    await closed;
    expect(find.text('Confirm changes'), findsNothing);
    expect(handle.isVisible, isFalse);
  });

  testWidgets('untagged dialog handles close their own stacked overlay', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final first = SuperOverlay.dialog.show<void>(
      builder: (_) => const Center(child: Text('First untagged dialog')),
    );
    final second = SuperOverlay.dialog.show<void>(
      builder: (_) => const Center(child: Text('Second untagged dialog')),
    );
    await tester.pump();

    expect(find.text('First untagged dialog'), findsOneWidget);
    expect(find.text('Second untagged dialog'), findsOneWidget);

    var firstClosed = false;
    final firstClosedProbe = first.closed.then((_) => firstClosed = true);
    final close = first.close();
    await tester.pumpAndSettle();
    await close;

    expect(firstClosed, isTrue);
    await firstClosedProbe;
    expect(find.text('First untagged dialog'), findsNothing);
    expect(find.text('Second untagged dialog'), findsOneWidget);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);

    await second.close();
  });

  testWidgets('same-tag stacked dialog handles close their own overlay', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final first = SuperOverlay.dialog.show<void>(
      builder: (_) => const Center(child: Text('First shared-tag dialog')),
      options: const OverlayDialogOptions(tag: 'shared-stack-dialog'),
    );
    final second = SuperOverlay.dialog.show<void>(
      builder: (_) => const Center(child: Text('Second shared-tag dialog')),
      options: const OverlayDialogOptions(tag: 'shared-stack-dialog'),
    );
    await tester.pump();

    expect(find.text('First shared-tag dialog'), findsOneWidget);
    expect(find.text('Second shared-tag dialog'), findsOneWidget);

    var firstClosed = false;
    final firstClosedProbe = first.closed.then((_) => firstClosed = true);
    final close = first.close();
    await tester.pumpAndSettle();
    await close;

    expect(firstClosed, isTrue);
    await firstClosedProbe;
    expect(find.text('First shared-tag dialog'), findsNothing);
    expect(find.text('Second shared-tag dialog'), findsOneWidget);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);
    expect(
      SuperOverlay.checkExist(
        tag: 'shared-stack-dialog',
        dialogTypes: const {OverlayType.custom},
      ),
      isTrue,
    );

    await second.close();
  });

  testWidgets('dialog replaceExisting closes a matching tagged dialog', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final first = SuperOverlay.dialog.show<void>(
      builder: (_) => const Center(child: Text('First dialog')),
      options: const OverlayDialogOptions(tag: 'replace-dialog'),
    );

    await tester.pump();
    expect(find.text('First dialog'), findsOneWidget);

    final second = SuperOverlay.dialog.show<void>(
      builder: (_) => const Center(child: Text('Second dialog')),
      options: const OverlayDialogOptions(
        tag: 'replace-dialog',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('First dialog'), findsNothing);
    expect(find.text('Second dialog'), findsOneWidget);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);

    await second.close();
  });

  testWidgets(
    'stale dialog handle cannot close replacement after it is closed',
    (tester) async {
      await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

      final first = SuperOverlay.dialog.show<void>(
        builder: (_) => const Center(child: Text('Stale first dialog')),
        options: const OverlayDialogOptions(tag: 'stale-replace-dialog'),
      );
      await tester.pump();
      expect(find.text('Stale first dialog'), findsOneWidget);

      final second = SuperOverlay.dialog.show<void>(
        builder: (_) => const Center(child: Text('Stale second dialog')),
        options: const OverlayDialogOptions(
          tag: 'stale-replace-dialog',
          strategy: OverlayStrategy.replaceExisting,
        ),
      );
      await tester.pumpAndSettle();

      var firstClosed = false;
      final firstClosedProbe = first.closed.then((_) => firstClosed = true);
      await tester.pump();
      expect(firstClosed, isTrue);
      await firstClosedProbe;
      expect(find.text('Stale first dialog'), findsNothing);
      expect(find.text('Stale second dialog'), findsOneWidget);

      final staleClose = first.close();
      await tester.pumpAndSettle();
      await staleClose;

      expect(find.text('Stale second dialog'), findsOneWidget);
      expect(second.isVisible, isTrue);

      final close = second.close();
      await tester.pumpAndSettle();
      await close;
      expect(find.text('Stale second dialog'), findsNothing);
    },
  );

  testWidgets(
    'dialog replaceExisting close during old animation prevents stuck content',
    (tester) async {
      SuperOverlay.config.custom = const CustomDialogConfig(
        animationTime: Duration(milliseconds: 200),
        nonAnimationTypes: [NonAnimationType.routeClose],
      );
      await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

      SuperOverlay.dialog.show<void>(
        builder: (_) => const Center(child: Text('Closing gap dialog')),
        options: const OverlayDialogOptions(tag: 'gap-replace-dialog'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Closing gap dialog'), findsOneWidget);

      final replacement = SuperOverlay.dialog.show<void>(
        builder: (_) => const Center(child: Text('Canceled replacement')),
        options: const OverlayDialogOptions(
          tag: 'gap-replace-dialog',
          strategy: OverlayStrategy.replaceExisting,
        ),
      );
      await tester.pump();
      expect(find.text('Canceled replacement'), findsNothing);

      var closed = false;
      final closedProbe = replacement.closed.then((_) => closed = true);
      final close = replacement.close();
      await tester.pumpAndSettle();
      await close;

      expect(closed, isTrue);
      await closedProbe;
      expect(find.text('Closing gap dialog'), findsNothing);
      expect(find.text('Canceled replacement'), findsNothing);
      expect(replacement.isVisible, isFalse);
    },
  );

  testWidgets(
    'dialog keepExisting preserves first content and shares existing handle',
    (tester) async {
      await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

      final first = SuperOverlay.dialog.show<void>(
        builder: (_) => const Center(child: Text('Original dialog')),
        options: const OverlayDialogOptions(tag: 'keep-dialog'),
      );
      await tester.pump();

      final second = SuperOverlay.dialog.show<void>(
        builder: (_) => const Center(child: Text('Ignored dialog')),
        options: const OverlayDialogOptions(
          tag: 'keep-dialog',
          strategy: OverlayStrategy.keepExisting,
        ),
      );
      await tester.pump();

      expect(find.text('Original dialog'), findsOneWidget);
      expect(find.text('Ignored dialog'), findsNothing);
      expect(first.isVisible, isTrue);
      expect(second.isVisible, isTrue);

      final firstClosed = _completesWithin(first.closed);
      final secondClosed = _completesWithin(second.closed);
      final close = second.close();
      await tester.pumpAndSettle();
      await close;

      expect(await firstClosed, isTrue);
      expect(await secondClosed, isTrue);
      expect(find.text('Original dialog'), findsNothing);
      expect(first.isVisible, isFalse);
      expect(second.isVisible, isFalse);
    },
  );

  testWidgets('dialog keepExisting second handle refreshes existing content', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    var count = 0;
    SuperOverlay.dialog.show<void>(
      builder: (_) => Center(child: Text('Kept dialog count $count')),
      options: const OverlayDialogOptions(tag: 'refresh-kept-dialog'),
    );
    await tester.pump();
    expect(find.text('Kept dialog count 0'), findsOneWidget);

    final second = SuperOverlay.dialog.show<void>(
      builder: (_) => const Center(child: Text('Ignored kept dialog')),
      options: const OverlayDialogOptions(
        tag: 'refresh-kept-dialog',
        strategy: OverlayStrategy.keepExisting,
      ),
    );
    await tester.pump();

    count = 1;
    second.refresh();
    await tester.pump();

    expect(find.text('Kept dialog count 0'), findsNothing);
    expect(find.text('Kept dialog count 1'), findsOneWidget);
    expect(find.text('Ignored kept dialog'), findsNothing);

    await second.close();
  });

  testWidgets(
    'dialog replaceExisting waits for close animation before showing replacement',
    (tester) async {
      SuperOverlay.config.custom = const CustomDialogConfig(
        animationTime: Duration(milliseconds: 200),
        nonAnimationTypes: [NonAnimationType.routeClose],
      );
      await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

      SuperOverlay.dialog.show<void>(
        builder: (_) => const Center(child: Text('Closing dialog')),
        options: const OverlayDialogOptions(tag: 'animated-replace-dialog'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Closing dialog'), findsOneWidget);

      final second = SuperOverlay.dialog.show<void>(
        builder: (_) => const Center(child: Text('Replacement dialog')),
        options: const OverlayDialogOptions(
          tag: 'animated-replace-dialog',
          strategy: OverlayStrategy.replaceExisting,
        ),
      );

      await tester.pump();
      expect(find.text('Closing dialog'), findsOneWidget);
      expect(find.text('Replacement dialog'), findsNothing);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Replacement dialog'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('Closing dialog'), findsNothing);
      expect(find.text('Replacement dialog'), findsOneWidget);

      final close = second.close();
      await tester.pumpAndSettle();
      await close;
    },
  );

  testWidgets('dialog refresh rebuilds command content', (tester) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    var count = 0;
    final handle = SuperOverlay.dialog.show<void>(
      builder: (_) => Center(child: Text('Refresh count $count')),
    );

    await tester.pump();
    expect(find.text('Refresh count 0'), findsOneWidget);

    count = 1;
    handle.refresh();
    await tester.pump();

    expect(find.text('Refresh count 0'), findsNothing);
    expect(find.text('Refresh count 1'), findsOneWidget);

    await handle.close();
  });

  testWidgets('popup command shows content from a target context', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildCommandOverlayApp(
        Center(
          child: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  SuperOverlay.popup.show<void>(
                    targetContext: context,
                    builder: (_) => const Text('Popup action'),
                  );
                },
                child: const Text('Open popup'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open popup'));
    await tester.pump();

    expect(find.text('Popup action'), findsOneWidget);
  });

  testWidgets('untagged popup handles close their own stacked overlay', (
    tester,
  ) async {
    late BuildContext targetContext;
    await tester.pumpWidget(
      _buildCommandOverlayApp(
        Center(
          child: Builder(
            builder: (context) {
              targetContext = context;
              return const Text('Popup target');
            },
          ),
        ),
      ),
    );

    final first = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('First untagged popup'),
    );
    final second = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Second untagged popup'),
    );
    await tester.pump();

    expect(find.text('First untagged popup'), findsOneWidget);
    expect(find.text('Second untagged popup'), findsOneWidget);

    var firstClosed = false;
    final firstClosedProbe = first.closed.then((_) => firstClosed = true);
    final close = first.close();
    await tester.pumpAndSettle();
    await close;

    expect(firstClosed, isTrue);
    await firstClosedProbe;
    expect(find.text('First untagged popup'), findsNothing);
    expect(find.text('Second untagged popup'), findsOneWidget);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);

    await second.close();
  });

  testWidgets('same-tag stacked popup handles close their own overlay', (
    tester,
  ) async {
    late BuildContext targetContext;
    await tester.pumpWidget(
      _buildCommandOverlayApp(
        Center(
          child: Builder(
            builder: (context) {
              targetContext = context;
              return const Text('Popup target');
            },
          ),
        ),
      ),
    );

    final first = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('First shared-tag popup'),
      options: const OverlayPopupOptions(tag: 'shared-stack-popup'),
    );
    final second = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Second shared-tag popup'),
      options: const OverlayPopupOptions(tag: 'shared-stack-popup'),
    );
    await tester.pump();

    expect(find.text('First shared-tag popup'), findsOneWidget);
    expect(find.text('Second shared-tag popup'), findsOneWidget);

    var firstClosed = false;
    final firstClosedProbe = first.closed.then((_) => firstClosed = true);
    final close = first.close();
    await tester.pumpAndSettle();
    await close;

    expect(firstClosed, isTrue);
    await firstClosedProbe;
    expect(find.text('First shared-tag popup'), findsNothing);
    expect(find.text('Second shared-tag popup'), findsOneWidget);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);
    expect(
      SuperOverlay.checkExist(
        tag: 'shared-stack-popup',
        dialogTypes: const {OverlayType.attach},
      ),
      isTrue,
    );

    final secondClose = second.close();
    await tester.pumpAndSettle();
    await secondClose;
  });

  testWidgets('popup replaceExisting closes a matching tagged popup', (
    tester,
  ) async {
    late BuildContext targetContext;
    await tester.pumpWidget(
      _buildCommandOverlayApp(
        Center(
          child: Builder(
            builder: (context) {
              targetContext = context;
              return const Text('Popup target');
            },
          ),
        ),
      ),
    );

    final first = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('First popup'),
      options: const OverlayPopupOptions(tag: 'replace-popup'),
    );
    await tester.pump();
    expect(find.text('First popup'), findsOneWidget);

    final second = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Second popup'),
      options: const OverlayPopupOptions(
        tag: 'replace-popup',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('First popup'), findsNothing);
    expect(find.text('Second popup'), findsOneWidget);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);

    await second.close();
  });

  testWidgets(
    'popup keepExisting preserves first content and shares existing handle',
    (tester) async {
      late BuildContext targetContext;
      await tester.pumpWidget(
        _buildCommandOverlayApp(
          Center(
            child: Builder(
              builder: (context) {
                targetContext = context;
                return const Text('Popup target');
              },
            ),
          ),
        ),
      );

      final first = SuperOverlay.popup.show<void>(
        targetContext: targetContext,
        builder: (_) => const Text('Original popup'),
        options: const OverlayPopupOptions(tag: 'keep-popup'),
      );
      await tester.pump();

      final second = SuperOverlay.popup.show<void>(
        targetContext: targetContext,
        builder: (_) => const Text('Ignored popup'),
        options: const OverlayPopupOptions(
          tag: 'keep-popup',
          strategy: OverlayStrategy.keepExisting,
        ),
      );
      await tester.pump();

      expect(find.text('Original popup'), findsOneWidget);
      expect(find.text('Ignored popup'), findsNothing);
      expect(first.isVisible, isTrue);
      expect(second.isVisible, isTrue);

      final firstClosed = _completesWithin(first.closed);
      final secondClosed = _completesWithin(second.closed);
      final close = second.close();
      await tester.pumpAndSettle();
      await close;

      expect(await firstClosed, isTrue);
      expect(await secondClosed, isTrue);
      expect(find.text('Original popup'), findsNothing);
      expect(first.isVisible, isFalse);
      expect(second.isVisible, isFalse);
    },
  );

  testWidgets('popup keepExisting second handle refreshes existing content', (
    tester,
  ) async {
    late BuildContext targetContext;
    await tester.pumpWidget(
      _buildCommandOverlayApp(
        Center(
          child: Builder(
            builder: (context) {
              targetContext = context;
              return const Text('Popup target');
            },
          ),
        ),
      ),
    );

    var count = 0;
    SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => Text('Kept popup count $count'),
      options: const OverlayPopupOptions(tag: 'refresh-kept-popup'),
    );
    await tester.pump();
    expect(find.text('Kept popup count 0'), findsOneWidget);

    final second = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Ignored kept popup'),
      options: const OverlayPopupOptions(
        tag: 'refresh-kept-popup',
        strategy: OverlayStrategy.keepExisting,
      ),
    );
    await tester.pump();

    count = 1;
    second.refresh();
    await tester.pump();

    expect(find.text('Kept popup count 0'), findsNothing);
    expect(find.text('Kept popup count 1'), findsOneWidget);
    expect(find.text('Ignored kept popup'), findsNothing);

    await second.close();
  });

  testWidgets('popup displayDuration auto closes command popup', (
    tester,
  ) async {
    late BuildContext targetContext;
    await tester.pumpWidget(
      _buildCommandOverlayApp(
        Center(
          child: Builder(
            builder: (context) {
              targetContext = context;
              return const Text('Popup target');
            },
          ),
        ),
      ),
    );

    SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Timed popup'),
      options: const OverlayPopupOptions(
        displayDuration: Duration(milliseconds: 20),
      ),
    );

    await tester.pump();
    expect(find.text('Timed popup'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 25));
    await tester.pumpAndSettle();
    expect(find.text('Timed popup'), findsNothing);
  });

  testWidgets('popup bindToRoute false keeps popup visible across route push', (
    tester,
  ) async {
    late BuildContext targetContext;
    await tester.pumpWidget(
      _buildCommandOverlayApp(
        Scaffold(
          body: Center(
            child: Builder(
              builder: (context) {
                targetContext = context;
                return const Text('Popup target');
              },
            ),
          ),
        ),
      ),
    );

    final handle = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Route independent popup'),
      options: const OverlayPopupOptions(bindToRoute: false),
    );
    await tester.pump();
    expect(find.text('Route independent popup'), findsOneWidget);

    Navigator.of(targetContext).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('Next route'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Next route'), findsOneWidget);
    expect(find.text('Route independent popup'), findsOneWidget);

    await handle.close();
  });

  testWidgets('notify success command shows a success notification', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.notify.success('Saved');

    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);
    expect(handle.isVisible, isTrue);

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    expect(find.text('Saved'), findsNothing);
    expect(handle.isVisible, isFalse);
  });

  testWidgets('untagged notify handles close their own stacked notification', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final first = SuperOverlay.notify.success(
      'First untagged notice',
      options: const OverlayNotifyOptions(displayDuration: null),
    );
    final second = SuperOverlay.notify.success(
      'Second untagged notice',
      options: const OverlayNotifyOptions(displayDuration: null),
    );
    await tester.pump();

    expect(find.text('First untagged notice'), findsOneWidget);
    expect(find.text('Second untagged notice'), findsOneWidget);

    var firstClosed = false;
    final firstClosedProbe = first.closed.then((_) => firstClosed = true);
    final close = first.close();
    await tester.pumpAndSettle();
    await close;

    expect(firstClosed, isTrue);
    await firstClosedProbe;
    expect(find.text('First untagged notice'), findsNothing);
    expect(find.text('Second untagged notice'), findsOneWidget);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);

    await second.close();
  });

  testWidgets('same-tag stacked notify handles close their own notification', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final first = SuperOverlay.notify.success(
      'First shared-tag notice',
      options: const OverlayNotifyOptions(
        tag: 'shared-stack-notify',
        displayDuration: null,
      ),
    );
    final second = SuperOverlay.notify.success(
      'Second shared-tag notice',
      options: const OverlayNotifyOptions(
        tag: 'shared-stack-notify',
        displayDuration: null,
      ),
    );
    await tester.pump();

    expect(find.text('First shared-tag notice'), findsOneWidget);
    expect(find.text('Second shared-tag notice'), findsOneWidget);

    var firstClosed = false;
    final firstClosedProbe = first.closed.then((_) => firstClosed = true);
    final close = first.close();
    await tester.pumpAndSettle();
    await close;

    expect(firstClosed, isTrue);
    await firstClosedProbe;
    expect(find.text('First shared-tag notice'), findsNothing);
    expect(find.text('Second shared-tag notice'), findsOneWidget);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);
    expect(
      SuperOverlay.checkExist(
        tag: 'shared-stack-notify',
        dialogTypes: const {OverlayType.notify},
      ),
      isTrue,
    );

    await second.close();
  });

  testWidgets('notify replaceExisting closes a matching tagged notification', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final first = SuperOverlay.notify.success(
      'First notice',
      options: const OverlayNotifyOptions(tag: 'replace-notify'),
    );

    await tester.pump();
    expect(find.text('First notice'), findsOneWidget);

    final second = SuperOverlay.notify.success(
      'Second notice',
      options: const OverlayNotifyOptions(
        tag: 'replace-notify',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('First notice'), findsNothing);
    expect(find.text('Second notice'), findsOneWidget);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);

    await second.close();
  });

  testWidgets(
    'stale notify handle cannot close replacement after it is closed',
    (tester) async {
      await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

      final first = SuperOverlay.notify.success(
        'Stale first notice',
        options: const OverlayNotifyOptions(
          tag: 'stale-replace-notify',
          displayDuration: null,
        ),
      );
      await tester.pump();
      expect(find.text('Stale first notice'), findsOneWidget);

      final second = SuperOverlay.notify.success(
        'Stale second notice',
        options: const OverlayNotifyOptions(
          tag: 'stale-replace-notify',
          strategy: OverlayStrategy.replaceExisting,
          displayDuration: null,
        ),
      );
      await tester.pumpAndSettle();

      var firstClosed = false;
      final firstClosedProbe = first.closed.then((_) => firstClosed = true);
      await tester.pump();
      expect(firstClosed, isTrue);
      await firstClosedProbe;
      expect(find.text('Stale first notice'), findsNothing);
      expect(find.text('Stale second notice'), findsOneWidget);

      final staleClose = first.close();
      await tester.pumpAndSettle();
      await staleClose;

      expect(find.text('Stale second notice'), findsOneWidget);
      expect(second.isVisible, isTrue);

      final close = second.close();
      await tester.pumpAndSettle();
      await close;
      expect(find.text('Stale second notice'), findsNothing);
    },
  );

  testWidgets(
    'notify keepExisting preserves first content and shares existing handle',
    (tester) async {
      await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

      final first = SuperOverlay.notify.success(
        'Original notice',
        options: const OverlayNotifyOptions(
          tag: 'keep-notify',
          displayDuration: null,
        ),
      );
      await tester.pump();

      final second = SuperOverlay.notify.success(
        'Ignored notice',
        options: const OverlayNotifyOptions(
          tag: 'keep-notify',
          strategy: OverlayStrategy.keepExisting,
          displayDuration: null,
        ),
      );
      await tester.pump();

      expect(find.text('Original notice'), findsOneWidget);
      expect(find.text('Ignored notice'), findsNothing);
      expect(first.isVisible, isTrue);
      expect(second.isVisible, isTrue);

      final firstClosed = _completesWithin(first.closed);
      final secondClosed = _completesWithin(second.closed);
      final close = second.close();
      await tester.pumpAndSettle();
      await close;

      expect(await firstClosed, isTrue);
      expect(await secondClosed, isTrue);
      expect(find.text('Original notice'), findsNothing);
      expect(first.isVisible, isFalse);
      expect(second.isVisible, isFalse);
    },
  );

  testWidgets('notify command applies alignment option', (tester) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.notify.success(
      'Bottom notice',
      options: const OverlayNotifyOptions(
        alignment: Alignment.bottomCenter,
        displayDuration: null,
      ),
    );

    await tester.pump();
    final noticeCenter = tester.getCenter(find.text('Bottom notice'));
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(noticeCenter.dy, greaterThan(screenHeight / 2));

    await handle.close();
  });

  testWidgets('toast replaceExisting closes a matching tagged toast', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final first = SuperOverlay.toast(
      'First toast',
      options: const OverlayToastOptions(
        tag: 'replace-toast',
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    );
    await tester.pump();
    expect(find.text('First toast'), findsOneWidget);

    final second = SuperOverlay.toast(
      'Second toast',
      options: const OverlayToastOptions(
        tag: 'replace-toast',
        strategy: OverlayStrategy.replaceExisting,
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('First toast'), findsNothing);
    expect(find.text('Second toast'), findsOneWidget);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);

    await second.close();
  });

  testWidgets('same-tag stacked toast handles close their own toast', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final first = SuperOverlay.toast(
      'First shared-tag toast',
      options: const OverlayToastOptions(
        tag: 'shared-stack-toast',
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    );
    final second = SuperOverlay.toast(
      'Second shared-tag toast',
      options: const OverlayToastOptions(
        tag: 'shared-stack-toast',
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    );
    await tester.pump();

    expect(find.text('First shared-tag toast'), findsOneWidget);
    expect(find.text('Second shared-tag toast'), findsOneWidget);

    var firstClosed = false;
    var secondClosed = false;
    final firstClosedProbe = first.closed.then((_) => firstClosed = true);
    final secondClosedProbe = second.closed.then((_) => secondClosed = true);
    final close = first.close();
    await tester.pumpAndSettle();
    await close;

    expect(firstClosed, isTrue);
    expect(secondClosed, isFalse);
    await firstClosedProbe;
    expect(find.text('First shared-tag toast'), findsNothing);
    expect(find.text('Second shared-tag toast'), findsOneWidget);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);
    expect(
      SuperOverlay.checkExist(
        tag: 'shared-stack-toast',
        dialogTypes: const {OverlayType.toast},
      ),
      isTrue,
    );

    final secondClose = second.close();
    await tester.pumpAndSettle();
    await secondClose;

    expect(secondClosed, isTrue);
    await secondClosedProbe;
  });

  testWidgets('queued toast handle is not visible until it is active', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final first = SuperOverlay.toast(
      'Active queued toast',
      options: const OverlayToastOptions(displayDuration: Duration(minutes: 1)),
    );
    final second = SuperOverlay.toast(
      'Waiting queued toast',
      options: const OverlayToastOptions(displayDuration: Duration(minutes: 1)),
    );
    await tester.pump();

    expect(find.text('Active queued toast'), findsOneWidget);
    expect(find.text('Waiting queued toast'), findsNothing);
    expect(first.isVisible, isTrue);
    expect(second.isVisible, isFalse);

    var secondVisible = false;
    final secondVisibleProbe = second.visible.then((_) {
      secondVisible = true;
    });
    await tester.pump();
    expect(secondVisible, isFalse);

    final firstClose = first.close();
    await tester.pumpAndSettle();
    await firstClose;
    await tester.pump();

    expect(find.text('Waiting queued toast'), findsOneWidget);
    expect(second.isVisible, isTrue);
    expect(secondVisible, isTrue);
    await secondVisibleProbe;

    final secondClose = second.close();
    await tester.pumpAndSettle();
    await secondClose;
  });

  testWidgets(
    'toast replaceExisting waits for close animation before showing replacement',
    (tester) async {
      SuperOverlay.config.toast = const ToastConfig(
        animationTime: Duration(milliseconds: 200),
        nonAnimationTypes: [],
      );
      await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

      SuperOverlay.toast(
        'Closing toast',
        options: const OverlayToastOptions(
          tag: 'animated-replace-toast',
          displayPolicy: OverlayToastDisplayPolicy.stack,
          displayDuration: Duration(minutes: 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Closing toast'), findsOneWidget);

      final second = SuperOverlay.toast(
        'Replacement toast',
        options: const OverlayToastOptions(
          tag: 'animated-replace-toast',
          strategy: OverlayStrategy.replaceExisting,
          displayPolicy: OverlayToastDisplayPolicy.stack,
          displayDuration: Duration(minutes: 1),
        ),
      );

      await tester.pump();
      expect(find.text('Closing toast'), findsOneWidget);
      expect(find.text('Replacement toast'), findsNothing);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Replacement toast'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('Closing toast'), findsNothing);
      expect(find.text('Replacement toast'), findsOneWidget);

      final close = second.close();
      await tester.pumpAndSettle();
      await close;
    },
  );

  testWidgets('toast keepExisting keeps a matching tagged toast', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final first = SuperOverlay.toast(
      'Original toast',
      options: const OverlayToastOptions(
        tag: 'keep-toast',
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    );
    await tester.pump();

    final second = SuperOverlay.toast(
      'Ignored toast',
      options: const OverlayToastOptions(
        tag: 'keep-toast',
        strategy: OverlayStrategy.keepExisting,
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    );
    await tester.pump();

    expect(find.text('Original toast'), findsOneWidget);
    expect(find.text('Ignored toast'), findsNothing);
    expect(first.isVisible, isTrue);
    expect(second.isVisible, isTrue);

    await first.close();
  });

  testWidgets('loading command exposes its tag to existence checks', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.loading.show(
      message: 'Tagged loading',
      options: const OverlayLoadingOptions(tag: 'sync-loading'),
    );

    await tester.pump();
    expect(
      SuperOverlay.checkExist(
        tag: 'sync-loading',
        dialogTypes: const {OverlayType.loading},
      ),
      isTrue,
    );

    await handle.close();
  });

  testWidgets('auto dismiss with wrong tag keeps tagged loading visible', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.loading.show(
      message: 'Tagged auto loading',
      options: const OverlayLoadingOptions(tag: 'sync-loading'),
    );

    await tester.pump();
    expect(find.text('Tagged auto loading'), findsOneWidget);
    expect(handle.isVisible, isTrue);

    await SuperOverlay.dismiss(tag: 'wrong');
    await tester.pump();

    expect(find.text('Tagged auto loading'), findsOneWidget);
    expect(handle.isVisible, isTrue);

    final closed = expectLater(handle.closed, completes);
    await SuperOverlay.dismiss(tag: 'sync-loading');
    await tester.pumpAndSettle();
    await closed;

    expect(find.text('Tagged auto loading'), findsNothing);
    expect(handle.isVisible, isFalse);
  });
}
