import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

const _bulkTargets = <OverlayCloseTarget>[
  OverlayCloseTarget.allDialogs,
  OverlayCloseTarget.allPopups,
  OverlayCloseTarget.allNotifications,
  OverlayCloseTarget.allToasts,
  OverlayCloseTarget.all,
];

Widget _buildOverlayApp(ValueChanged<BuildContext> onTargetContext) {
  return MaterialApp(
    builder: SuperOverlay.init(),
    navigatorObservers: [SuperOverlay.observer],
    home: Scaffold(
      body: Builder(
        builder: (context) {
          onTargetContext(context);
          return const SizedBox(
            width: 80,
            height: 40,
            child: Text('Bulk popup target'),
          );
        },
      ),
    ),
  );
}

class _OverlayProbe {
  const _OverlayProbe({
    required this.label,
    required this.isVisible,
    required this.isClosed,
    required this.closed,
  });

  final String label;
  final bool Function() isVisible;
  final bool Function() isClosed;
  final Future<void> closed;
}

_OverlayProbe _track<T>(String label, OverlayHandle<T> handle) {
  var isClosed = false;
  final closed = handle.closed.then<void>((_) {
    isClosed = true;
  });
  return _OverlayProbe(
    label: label,
    isVisible: () => handle.isVisible,
    isClosed: () => isClosed,
    closed: closed,
  );
}

List<_OverlayProbe> _showBulkRepresentatives(
  OverlayCloseTarget target,
  BuildContext targetContext,
) {
  switch (target) {
    case OverlayCloseTarget.allDialogs:
      return [
        _track(
          'Bulk bool dialog',
          SuperOverlay.dialog.show<bool>(
            builder: (_) => const Text('Bulk bool dialog'),
            options: const OverlayDialogOptions(tag: 'bulk-bool-dialog'),
          ),
        ),
        _track(
          'Bulk int dialog',
          SuperOverlay.dialog.show<int>(
            builder: (_) => const Text('Bulk int dialog'),
            options: const OverlayDialogOptions(tag: 'bulk-int-dialog'),
          ),
        ),
      ];
    case OverlayCloseTarget.allPopups:
      return [
        _track(
          'Bulk bool popup',
          SuperOverlay.popup.show<bool>(
            targetContext: targetContext,
            builder: (_) => const Text('Bulk bool popup'),
            options: const OverlayPopupOptions(tag: 'bulk-bool-popup'),
          ),
        ),
        _track(
          'Bulk int popup',
          SuperOverlay.popup.show<int>(
            targetContext: targetContext,
            builder: (_) => const Text('Bulk int popup'),
            options: const OverlayPopupOptions(tag: 'bulk-int-popup'),
          ),
        ),
      ];
    case OverlayCloseTarget.allNotifications:
      return [
        _track(
          'Bulk notification',
          SuperOverlay.notify.success(
            'Bulk notification',
            options: const OverlayNotifyOptions(
              tag: 'bulk-notification',
              displayDuration: Duration(minutes: 1),
            ),
          ),
        ),
      ];
    case OverlayCloseTarget.allToasts:
      return [
        _track(
          'Bulk toast',
          SuperOverlay.toast(
            'Bulk toast',
            options: const OverlayToastOptions(
              tag: 'bulk-toast',
              displayPolicy: OverlayToastDisplayPolicy.stack,
              displayDuration: Duration(minutes: 1),
            ),
          ),
        ),
      ];
    case OverlayCloseTarget.all:
      return [
        _track(
          'Bulk all loading',
          SuperOverlay.loading.show(
            message: 'Bulk all loading',
            options: const OverlayLoadingOptions(tag: 'bulk-all-loading'),
          ),
        ),
        _track(
          'Bulk all dialog',
          SuperOverlay.dialog.show<bool>(
            builder: (_) => const Text('Bulk all dialog'),
            options: const OverlayDialogOptions(tag: 'bulk-all-dialog'),
          ),
        ),
      ];
    case OverlayCloseTarget.topMost:
    case OverlayCloseTarget.dialog:
    case OverlayCloseTarget.popup:
    case OverlayCloseTarget.notification:
    case OverlayCloseTarget.loading:
    case OverlayCloseTarget.toast:
      throw ArgumentError.value(target, 'target', 'Expected a bulk target.');
  }
}

void main() {
  test('bulk result validation runs before overlay host resolution', () {
    for (final target in _bulkTargets) {
      expect(
        () => SuperOverlay.close<String>(target: target, result: 'wrong'),
        throwsA(isA<StateError>()),
        reason: '$target must reject before looking up an overlay host',
      );
    }
  });

  testWidgets('typed global close validates before mutating a dialog', (
    tester,
  ) async {
    late BuildContext targetContext;
    await tester.pumpWidget(
      _buildOverlayApp((context) => targetContext = context),
    );
    expect(targetContext, isNotNull);

    final handle = SuperOverlay.dialog.show<bool>(
      builder: (_) => const Text('Typed global dialog'),
      options: const OverlayDialogOptions(tag: 'typed-global-dialog'),
    );
    await tester.pumpAndSettle();

    var didClose = false;
    bool? closedResult;
    final trackedClosed = handle.closed.then<void>((result) {
      didClose = true;
      closedResult = result;
    });

    await expectLater(
      SuperOverlay.close<String>(
        target: OverlayCloseTarget.dialog,
        result: 'wrong',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('typed-global-dialog'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Typed global dialog'), findsOneWidget);
    expect(handle.isVisible, isTrue);
    expect(
      SuperOverlay.exists(
        tag: 'typed-global-dialog',
        surfaces: const {OverlaySurface.dialog},
      ),
      isTrue,
    );
    expect(didClose, isFalse);

    final close = handle.close(true);
    await tester.pumpAndSettle();
    await close;
    await trackedClosed;

    expect(closedResult, isTrue);
    expect(handle.isVisible, isFalse);
    expect(find.text('Typed global dialog'), findsNothing);
  });

  testWidgets('typed global close accepts an exact result type', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOverlayApp((_) {}));

    final handle = SuperOverlay.dialog.show<bool>(
      builder: (_) => const Text('Exact result dialog'),
    );
    await tester.pumpAndSettle();

    final close = SuperOverlay.close<bool>(
      target: OverlayCloseTarget.dialog,
      result: true,
    );
    await tester.pumpAndSettle();
    await close;

    await expectLater(handle.closed, completion(isTrue));
    expect(handle.isVisible, isFalse);
    expect(find.text('Exact result dialog'), findsNothing);
  });

  testWidgets('typed global close accepts a subtype value for a supertype', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOverlayApp((_) {}));

    final handle = SuperOverlay.dialog.show<num>(
      builder: (_) => const Text('Supertype result dialog'),
    );
    await tester.pumpAndSettle();

    final close = SuperOverlay.close(
      target: OverlayCloseTarget.dialog,
      result: 7,
    );
    await tester.pumpAndSettle();
    await close;

    await expectLater(handle.closed, completion(7));
    expect(handle.isVisible, isFalse);
    expect(find.text('Supertype result dialog'), findsNothing);
  });

  testWidgets('typed global close accepts a value for a nullable type', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOverlayApp((_) {}));

    final handle = SuperOverlay.dialog.show<String?>(
      builder: (_) => const Text('Nullable result dialog'),
    );
    await tester.pumpAndSettle();

    final close = SuperOverlay.close(
      target: OverlayCloseTarget.dialog,
      result: 'accepted',
    );
    await tester.pumpAndSettle();
    await close;

    await expectLater(handle.closed, completion('accepted'));
    expect(handle.isVisible, isFalse);
    expect(find.text('Nullable result dialog'), findsNothing);
  });

  testWidgets('typed global close accepts a concrete value for dynamic', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOverlayApp((_) {}));

    final handle = SuperOverlay.dialog.show<dynamic>(
      builder: (_) => const Text('Dynamic result dialog'),
    );
    await tester.pumpAndSettle();
    final result = <String, bool>{'accepted': true};

    final close = SuperOverlay.close(
      target: OverlayCloseTarget.dialog,
      result: result,
    );
    await tester.pumpAndSettle();
    await close;

    await expectLater(handle.closed, completion(same(result)));
    expect(handle.isVisible, isFalse);
    expect(find.text('Dynamic result dialog'), findsNothing);
  });

  testWidgets('void global close accepts values like handle-owned close', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOverlayApp((_) {}));

    final handleOwned = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Handle-owned void dialog'),
    );
    await tester.pumpAndSettle();

    final handleClose =
        Function.apply(handleOwned.close, const ['ignored by void'])
            as Future<void>;
    await tester.pumpAndSettle();
    await handleClose;
    await handleOwned.closed;

    expect(handleOwned.isVisible, isFalse);
    expect(find.text('Handle-owned void dialog'), findsNothing);

    final global = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Global void dialog'),
    );
    await tester.pumpAndSettle();

    final globalClose = SuperOverlay.close(
      target: OverlayCloseTarget.dialog,
      result: 'ignored by void',
    );
    await tester.pumpAndSettle();
    await globalClose;
    await global.closed;

    expect(global.isVisible, isFalse);
    expect(find.text('Global void dialog'), findsNothing);
  });

  for (final target in _bulkTargets) {
    testWidgets(
      '${target.name} rejects a result before mutation and accepts null cleanup',
      (tester) async {
        late BuildContext targetContext;
        await tester.pumpWidget(
          _buildOverlayApp((context) => targetContext = context),
        );

        final probes = _showBulkRepresentatives(target, targetContext);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        for (final probe in probes) {
          expect(find.text(probe.label), findsOneWidget);
          expect(probe.isVisible(), isTrue);
          expect(probe.isClosed(), isFalse);
        }

        await expectLater(
          Future<void>.sync(
            () => SuperOverlay.close<String>(target: target, result: 'wrong'),
          ),
          throwsA(isA<StateError>()),
        );
        await tester.pump();

        for (final probe in probes) {
          expect(find.text(probe.label), findsOneWidget);
          expect(probe.isVisible(), isTrue);
          expect(probe.isClosed(), isFalse);
        }

        final cleanup = SuperOverlay.close(target: target);
        await tester.pumpAndSettle();
        await cleanup;
        await Future.wait(probes.map((probe) => probe.closed));

        for (final probe in probes) {
          expect(find.text(probe.label), findsNothing);
          expect(probe.isVisible(), isFalse);
          expect(probe.isClosed(), isTrue);
        }
      },
    );
  }
}
