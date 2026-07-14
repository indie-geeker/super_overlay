import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

Widget _buildOverlayApp(Widget child) {
  return MaterialApp(
    builder: SuperOverlay.init(),
    navigatorObservers: [SuperOverlay.observer],
    home: Scaffold(body: child),
  );
}

typedef _ShowTaggedOverlay =
    OverlayHandle<void> Function({
      required String label,
      required OverlayStrategy strategy,
    });

typedef _ShowBusinessTaggedOverlay =
    OverlayHandle<void> Function({
      required String label,
      required String tag,
      required OverlayStrategy strategy,
    });

Future<void> _expectEveryStackedMatchReplaced(
  WidgetTester tester, {
  required String surface,
  required _ShowTaggedOverlay show,
}) async {
  final firstLabel = 'First stacked $surface';
  final secondLabel = 'Second stacked $surface';
  final replacementLabel = 'Replacement $surface';
  final first = show(label: firstLabel, strategy: OverlayStrategy.stack);
  final second = show(label: secondLabel, strategy: OverlayStrategy.stack);

  await tester.pumpAndSettle();

  expect(find.text(firstLabel), findsOneWidget);
  expect(find.text(secondLabel), findsOneWidget);
  expect(first.isVisible, isTrue);
  expect(second.isVisible, isTrue);

  final replacement = show(
    label: replacementLabel,
    strategy: OverlayStrategy.replaceExisting,
  );

  await tester.pumpAndSettle();

  expect(find.text(firstLabel), findsNothing);
  expect(find.text(secondLabel), findsNothing);
  expect(find.text(replacementLabel), findsOneWidget);
  expect(first.isVisible, isFalse);
  expect(second.isVisible, isFalse);
  expect(replacement.isVisible, isTrue);
  await first.closed;
  await second.closed;

  await replacement.close();
}

String _findSyntheticIdentity({
  required String kind,
  required OverlaySurface surface,
}) {
  for (var id = 0; id < 10000; id++) {
    final candidate = '_super_overlay_command_${kind}_$id';
    if (SuperOverlay.exists(tag: candidate, surfaces: {surface})) {
      return candidate;
    }
  }
  throw StateError('Could not discover the $kind handle identity.');
}

Future<void> _expectSyntheticIdentityIsNotABusinessMatch(
  WidgetTester tester, {
  required String surfaceLabel,
  required OverlaySurface surface,
  required String identityKind,
  required OverlayCloseTarget globalCloseTarget,
  required _ShowBusinessTaggedOverlay show,
}) async {
  final unrelatedLabel = 'Unrelated $surfaceLabel';
  final replacementLabel = 'Namespace replacement $surfaceLabel';
  final unrelated = show(
    label: unrelatedLabel,
    tag: 'real-business-$surfaceLabel',
    strategy: OverlayStrategy.stack,
  );
  await tester.pumpAndSettle();

  final unrelatedIdentity = _findSyntheticIdentity(
    kind: identityKind,
    surface: surface,
  );
  final replacement = show(
    label: replacementLabel,
    tag: unrelatedIdentity,
    strategy: OverlayStrategy.replaceExisting,
  );
  await tester.pumpAndSettle();

  expect(find.text(unrelatedLabel), findsOneWidget);
  expect(find.text(replacementLabel), findsOneWidget);
  expect(unrelated.isVisible, isTrue);
  expect(replacement.isVisible, isTrue);

  final unrelatedClose = unrelated.close();
  await tester.pumpAndSettle();
  await unrelatedClose;

  expect(find.text(unrelatedLabel), findsNothing);
  expect(find.text(replacementLabel), findsOneWidget);
  expect(unrelated.isVisible, isFalse);
  expect(replacement.isVisible, isTrue);

  final replacementClose = SuperOverlay.close(
    target: globalCloseTarget,
    tag: unrelatedIdentity,
  );
  await tester.pumpAndSettle();
  await replacementClose;

  expect(find.text(replacementLabel), findsNothing);
  expect(replacement.isVisible, isFalse);
}

String _futureSyntheticIdentity(String currentIdentity, int offset) {
  final separator = currentIdentity.lastIndexOf('_');
  final id = int.parse(currentIdentity.substring(separator + 1));
  return '${currentIdentity.substring(0, separator + 1)}${id + offset}';
}

Future<void> _expectKeepExistingUsesBusinessNamespace(
  WidgetTester tester, {
  required String surfaceLabel,
  required OverlaySurface surface,
  required String identityKind,
  required _ShowBusinessTaggedOverlay show,
}) async {
  final anchor = show(
    label: 'Keep namespace anchor $surfaceLabel',
    tag: 'keep-namespace-anchor-$surfaceLabel',
    strategy: OverlayStrategy.stack,
  );
  await tester.pumpAndSettle();

  final anchorIdentity = _findSyntheticIdentity(
    kind: identityKind,
    surface: surface,
  );
  final collisionIdentity = _futureSyntheticIdentity(anchorIdentity, 2);
  final intended = show(
    label: 'Keep namespace intended $surfaceLabel',
    tag: collisionIdentity,
    strategy: OverlayStrategy.stack,
  );
  final unrelated = show(
    label: 'Keep namespace unrelated $surfaceLabel',
    tag: 'keep-namespace-unrelated-$surfaceLabel',
    strategy: OverlayStrategy.stack,
  );
  await tester.pumpAndSettle();

  final kept = show(
    label: 'Keep namespace ignored $surfaceLabel',
    tag: collisionIdentity,
    strategy: OverlayStrategy.keepExisting,
  );
  await tester.pumpAndSettle();
  await kept.visible;

  expect(find.text('Keep namespace intended $surfaceLabel'), findsOneWidget);
  expect(find.text('Keep namespace unrelated $surfaceLabel'), findsOneWidget);
  expect(find.text('Keep namespace ignored $surfaceLabel'), findsNothing);

  final keptClose = kept.close();
  await tester.pumpAndSettle();
  await keptClose;

  expect(find.text('Keep namespace intended $surfaceLabel'), findsNothing);
  expect(find.text('Keep namespace unrelated $surfaceLabel'), findsOneWidget);
  expect(intended.isVisible, isFalse);
  expect(unrelated.isVisible, isTrue);

  final anchorClose = anchor.close();
  final unrelatedClose = unrelated.close();
  await tester.pumpAndSettle();
  await Future.wait([anchorClose, unrelatedClose]);
}

void main() {
  testWidgets('same-turn dialog replacement leaves only the latest overlay', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

    final first = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('First racing dialog'),
      options: const OverlayDialogOptions(
        tag: 'racing-dialog',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );
    final second = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Second racing dialog'),
      options: const OverlayDialogOptions(
        tag: 'racing-dialog',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('First racing dialog'), findsNothing);
    expect(find.text('Second racing dialog'), findsOneWidget);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);

    await second.close();
  });

  testWidgets('same-turn popup replacement leaves only the latest overlay', (
    tester,
  ) async {
    late BuildContext targetContext;
    await tester.pumpWidget(
      _buildOverlayApp(
        Builder(
          builder: (context) {
            targetContext = context;
            return const SizedBox(width: 80, height: 40);
          },
        ),
      ),
    );

    final first = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('First racing popup'),
      options: const OverlayPopupOptions(
        tag: 'racing-popup',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );
    final second = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Second racing popup'),
      options: const OverlayPopupOptions(
        tag: 'racing-popup',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('First racing popup'), findsNothing);
    expect(find.text('Second racing popup'), findsOneWidget);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);

    await second.close();
  });

  testWidgets(
    'same-turn notification replacement leaves only the latest overlay',
    (tester) async {
      await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

      final first = SuperOverlay.notify.success(
        'First racing notification',
        options: const OverlayNotifyOptions(
          tag: 'racing-notification',
          strategy: OverlayStrategy.replaceExisting,
          displayDuration: null,
        ),
      );
      final second = SuperOverlay.notify.success(
        'Second racing notification',
        options: const OverlayNotifyOptions(
          tag: 'racing-notification',
          strategy: OverlayStrategy.replaceExisting,
          displayDuration: null,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('First racing notification'), findsNothing);
      expect(find.text('Second racing notification'), findsOneWidget);
      expect(first.isVisible, isFalse);
      expect(second.isVisible, isTrue);

      await second.close();
    },
  );

  testWidgets('same-turn toast replacement leaves only the latest overlay', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

    final first = SuperOverlay.toast(
      'First racing toast',
      options: const OverlayToastOptions(
        tag: 'racing-toast',
        strategy: OverlayStrategy.replaceExisting,
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    );
    final second = SuperOverlay.toast(
      'Second racing toast',
      options: const OverlayToastOptions(
        tag: 'racing-toast',
        strategy: OverlayStrategy.replaceExisting,
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('First racing toast'), findsNothing);
    expect(find.text('Second racing toast'), findsOneWidget);
    expect(first.isVisible, isFalse);
    expect(second.isVisible, isTrue);

    await second.close();
  });

  testWidgets('dialog replacement closes every stacked same-tag overlay', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

    await _expectEveryStackedMatchReplaced(
      tester,
      surface: 'dialog',
      show:
          ({required label, required strategy}) =>
              SuperOverlay.dialog.show<void>(
                builder: (_) => Text(label),
                options: OverlayDialogOptions(
                  tag: 'stacked-dialog',
                  strategy: strategy,
                ),
              ),
    );
  });

  testWidgets('popup replacement closes every stacked same-tag overlay', (
    tester,
  ) async {
    late BuildContext targetContext;
    await tester.pumpWidget(
      _buildOverlayApp(
        Builder(
          builder: (context) {
            targetContext = context;
            return const SizedBox(width: 80, height: 40);
          },
        ),
      ),
    );

    await _expectEveryStackedMatchReplaced(
      tester,
      surface: 'popup',
      show:
          ({required label, required strategy}) =>
              SuperOverlay.popup.show<void>(
                targetContext: targetContext,
                builder: (_) => Text(label),
                options: OverlayPopupOptions(
                  tag: 'stacked-popup',
                  strategy: strategy,
                ),
              ),
    );
  });

  testWidgets(
    'notification replacement closes every stacked same-tag overlay',
    (tester) async {
      await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

      await _expectEveryStackedMatchReplaced(
        tester,
        surface: 'notification',
        show:
            ({required label, required strategy}) =>
                SuperOverlay.notify.success(
                  label,
                  options: OverlayNotifyOptions(
                    tag: 'stacked-notification',
                    strategy: strategy,
                    displayDuration: null,
                  ),
                ),
      );
    },
  );

  testWidgets('toast replacement closes every stacked same-tag overlay', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

    await _expectEveryStackedMatchReplaced(
      tester,
      surface: 'toast',
      show:
          ({required label, required strategy}) => SuperOverlay.toast(
            label,
            options: OverlayToastOptions(
              tag: 'stacked-toast',
              strategy: strategy,
              displayPolicy: OverlayToastDisplayPolicy.stack,
              displayDuration: const Duration(minutes: 1),
            ),
          ),
    );
  });

  testWidgets(
    'dialog replacement ignores an unrelated synthetic identity collision',
    (tester) async {
      await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

      await _expectSyntheticIdentityIsNotABusinessMatch(
        tester,
        surfaceLabel: 'dialog',
        surface: OverlaySurface.dialog,
        identityKind: 'dialog',
        globalCloseTarget: OverlayCloseTarget.dialog,
        show:
            ({required label, required tag, required strategy}) =>
                SuperOverlay.dialog.show<void>(
                  builder: (_) => Text(label),
                  options: OverlayDialogOptions(tag: tag, strategy: strategy),
                ),
      );
    },
  );

  testWidgets(
    'popup replacement ignores an unrelated synthetic identity collision',
    (tester) async {
      late BuildContext targetContext;
      await tester.pumpWidget(
        _buildOverlayApp(
          Builder(
            builder: (context) {
              targetContext = context;
              return const SizedBox(width: 80, height: 40);
            },
          ),
        ),
      );

      await _expectSyntheticIdentityIsNotABusinessMatch(
        tester,
        surfaceLabel: 'popup',
        surface: OverlaySurface.popup,
        identityKind: 'popup',
        globalCloseTarget: OverlayCloseTarget.popup,
        show:
            ({required label, required tag, required strategy}) =>
                SuperOverlay.popup.show<void>(
                  targetContext: targetContext,
                  builder: (_) => Text(label),
                  options: OverlayPopupOptions(tag: tag, strategy: strategy),
                ),
      );
    },
  );

  testWidgets(
    'notification replacement ignores an unrelated synthetic identity collision',
    (tester) async {
      await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

      await _expectSyntheticIdentityIsNotABusinessMatch(
        tester,
        surfaceLabel: 'notification',
        surface: OverlaySurface.notification,
        identityKind: 'notify',
        globalCloseTarget: OverlayCloseTarget.notification,
        show:
            ({required label, required tag, required strategy}) =>
                SuperOverlay.notify.success(
                  label,
                  options: OverlayNotifyOptions(
                    tag: tag,
                    strategy: strategy,
                    displayDuration: null,
                  ),
                ),
      );
    },
  );

  testWidgets(
    'toast replacement ignores an unrelated synthetic identity collision',
    (tester) async {
      await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

      await _expectSyntheticIdentityIsNotABusinessMatch(
        tester,
        surfaceLabel: 'toast',
        surface: OverlaySurface.toast,
        identityKind: 'toast',
        globalCloseTarget: OverlayCloseTarget.toast,
        show:
            ({required label, required tag, required strategy}) =>
                SuperOverlay.toast(
                  label,
                  options: OverlayToastOptions(
                    tag: tag,
                    strategy: strategy,
                    displayPolicy: OverlayToastDisplayPolicy.stack,
                    displayDuration: const Duration(minutes: 1),
                  ),
                ),
      );
    },
  );

  testWidgets('dialog replacement leaves a same-tag popup untouched', (
    tester,
  ) async {
    late BuildContext targetContext;
    await tester.pumpWidget(
      _buildOverlayApp(
        Builder(
          builder: (context) {
            targetContext = context;
            return const SizedBox(width: 80, height: 40);
          },
        ),
      ),
    );

    final popup = SuperOverlay.popup.show<void>(
      targetContext: targetContext,
      builder: (_) => const Text('Cross-surface popup'),
      options: const OverlayPopupOptions(tag: 'cross-surface-tag'),
    );
    final originalDialog = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Cross-surface original dialog'),
      options: const OverlayDialogOptions(tag: 'cross-surface-tag'),
    );
    await tester.pumpAndSettle();

    final replacement = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Cross-surface replacement dialog'),
      options: const OverlayDialogOptions(
        tag: 'cross-surface-tag',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cross-surface original dialog'), findsNothing);
    expect(find.text('Cross-surface replacement dialog'), findsOneWidget);
    expect(find.text('Cross-surface popup'), findsOneWidget);
    expect(originalDialog.isVisible, isFalse);
    expect(replacement.isVisible, isTrue);
    expect(popup.isVisible, isTrue);

    final popupClose = popup.close();
    final replacementClose = replacement.close();
    await tester.pumpAndSettle();
    await Future.wait([popupClose, replacementClose]);
  });

  testWidgets(
    'dialog keepExisting resolves business tag before synthetic identity',
    (tester) async {
      await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

      await _expectKeepExistingUsesBusinessNamespace(
        tester,
        surfaceLabel: 'dialog',
        surface: OverlaySurface.dialog,
        identityKind: 'dialog',
        show:
            ({required label, required tag, required strategy}) =>
                SuperOverlay.dialog.show<void>(
                  builder: (_) => Text(label),
                  options: OverlayDialogOptions(tag: tag, strategy: strategy),
                ),
      );
    },
  );

  testWidgets(
    'popup keepExisting resolves business tag before synthetic identity',
    (tester) async {
      late BuildContext targetContext;
      await tester.pumpWidget(
        _buildOverlayApp(
          Builder(
            builder: (context) {
              targetContext = context;
              return const SizedBox(width: 80, height: 40);
            },
          ),
        ),
      );

      await _expectKeepExistingUsesBusinessNamespace(
        tester,
        surfaceLabel: 'popup',
        surface: OverlaySurface.popup,
        identityKind: 'popup',
        show:
            ({required label, required tag, required strategy}) =>
                SuperOverlay.popup.show<void>(
                  targetContext: targetContext,
                  builder: (_) => Text(label),
                  options: OverlayPopupOptions(tag: tag, strategy: strategy),
                ),
      );
    },
  );

  testWidgets(
    'notification keepExisting resolves business tag before synthetic identity',
    (tester) async {
      await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

      await _expectKeepExistingUsesBusinessNamespace(
        tester,
        surfaceLabel: 'notification',
        surface: OverlaySurface.notification,
        identityKind: 'notify',
        show:
            ({required label, required tag, required strategy}) =>
                SuperOverlay.notify.success(
                  label,
                  options: OverlayNotifyOptions(
                    tag: tag,
                    strategy: strategy,
                    displayDuration: null,
                  ),
                ),
      );
    },
  );

  testWidgets(
    'toast keepExisting resolves business tag before synthetic identity',
    (tester) async {
      await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

      await _expectKeepExistingUsesBusinessNamespace(
        tester,
        surfaceLabel: 'toast',
        surface: OverlaySurface.toast,
        identityKind: 'toast',
        show:
            ({required label, required tag, required strategy}) =>
                SuperOverlay.toast(
                  label,
                  options: OverlayToastOptions(
                    tag: tag,
                    strategy: strategy,
                    displayPolicy: OverlayToastDisplayPolicy.stack,
                    displayDuration: const Duration(minutes: 1),
                  ),
                ),
      );
    },
  );

  testWidgets('canceling a queued replacement preserves the current winner', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOverlayApp(const SizedBox.shrink()));

    final original = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Original queued dialog'),
      options: const OverlayDialogOptions(
        tag: 'queued-dialog',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );
    await tester.pumpAndSettle();
    await original.visible;

    final winner = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Current queued winner'),
      options: const OverlayDialogOptions(
        tag: 'queued-dialog',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );
    final canceled = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Canceled queued successor'),
      options: const OverlayDialogOptions(
        tag: 'queued-dialog',
        strategy: OverlayStrategy.replaceExisting,
      ),
    );
    final canceledClose = canceled.close();

    await tester.pumpAndSettle();
    await canceledClose;

    expect(find.text('Current queued winner'), findsOneWidget);
    expect(find.text('Canceled queued successor'), findsNothing);
    expect(winner.isVisible, isTrue);
    expect(canceled.isVisible, isFalse);

    await winner.close();
  });
}
