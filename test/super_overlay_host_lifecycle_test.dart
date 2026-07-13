import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';
import 'package:super_overlay/src/config/overlay_config.dart';

Widget _buildHost({SuperOverlayToastBuilder? toastBuilder}) {
  return MaterialApp(
    builder: SuperOverlay.init(toastBuilder: toastBuilder),
    navigatorObservers: [SuperOverlay.observer],
    home: const Scaffold(body: SizedBox.shrink()),
  );
}

Widget _buildOwnedHost({
  Key? key,
  required SuperOverlayIntegration integration,
  required Widget child,
}) {
  return MaterialApp(
    key: key,
    builder: integration.builder,
    navigatorObservers: [integration.observer],
    home: Scaffold(body: child),
  );
}

Future<void> _verifyAtomicHostReplacement(
  WidgetTester tester, {
  required bool useDistinctRootKeys,
}) async {
  final firstIntegration = SuperOverlay.integration(
    toastBuilder: (message) => Text('first default: $message'),
  );
  final secondIntegration = SuperOverlay.integration(
    toastBuilder: (message) => Text('second default: $message'),
  );

  await tester.pumpWidget(
    _buildOwnedHost(
      key: useDistinctRootKeys ? const ValueKey('first-root') : null,
      integration: firstIntegration,
      child: const SizedBox.shrink(),
    ),
  );

  final firstHandles = <OverlayHandle<void>>[
    SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('first generation dialog'),
      options: const OverlayDialogOptions(tag: 'reused-generation-tag'),
    ),
    SuperOverlay.loading.show(
      message: 'first generation loading',
      options: const OverlayLoadingOptions(tag: 'first-generation-loading'),
    ),
    SuperOverlay.notify.success(
      'first generation notification',
      options: const OverlayNotifyOptions(displayDuration: null),
    ),
    SuperOverlay.toast(
      'first generation toast',
      options: const OverlayToastOptions(
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    ),
  ];
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await Future.wait(firstHandles.map((handle) => handle.visible));

  final firstClosedCounts = List<int>.filled(firstHandles.length, 0);
  for (var index = 0; index < firstHandles.length; index++) {
    firstHandles[index].closed.then((_) => firstClosedCounts[index]++);
  }

  await tester.pumpWidget(
    _buildOwnedHost(
      key: useDistinctRootKeys ? const ValueKey('second-root') : null,
      integration: secondIntegration,
      child: const SizedBox.shrink(),
    ),
  );
  await tester.pump();
  await tester.idle();

  expect(firstClosedCounts, everyElement(1));
  expect(firstHandles.map((handle) => handle.isVisible), everyElement(isFalse));

  final secondHandle = SuperOverlay.dialog.show<void>(
    builder: (_) => const Text('second generation dialog'),
    options: const OverlayDialogOptions(tag: 'reused-generation-tag'),
  );
  final toast = SuperOverlay.toast(
    'replacement',
    options: const OverlayToastOptions(
      displayPolicy: OverlayToastDisplayPolicy.stack,
      displayDuration: Duration(minutes: 1),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('second generation dialog'), findsOneWidget);
  expect(find.text('second default: replacement'), findsOneWidget);

  await firstHandles.first.close();
  await tester.pump();
  expect(secondHandle.isVisible, isTrue);
  expect(find.text('second generation dialog'), findsOneWidget);

  final secondClose = secondHandle.close();
  final toastClose = toast.close();
  await tester.pumpAndSettle();
  await Future.wait([secondClose, toastClose]);
  await tester.pumpWidget(const SizedBox.shrink());
  firstIntegration.dispose();
  secondIntegration.dispose();
}

void main() {
  testWidgets('host defaults do not overwrite the base overlay configuration', (
    tester,
  ) async {
    final originalToast = overlayConfig.toast;
    Widget baseBuilder(String message) => Text('base default: $message');
    overlayConfig.toast = originalToast.withBuilder(baseBuilder);
    final configuredBaseBuilder = overlayConfig.toast.builder;
    final firstIntegration = SuperOverlay.integration(
      toastBuilder: (message) => Text('host default: $message'),
    );
    final secondIntegration = SuperOverlay.integration();

    try {
      await tester.pumpWidget(
        _buildOwnedHost(
          integration: firstIntegration,
          child: const SizedBox.shrink(),
        ),
      );
      final hostToast = SuperOverlay.toast(
        'first',
        options: const OverlayToastOptions(
          displayPolicy: OverlayToastDisplayPolicy.stack,
          displayDuration: Duration(minutes: 1),
        ),
      );
      await tester.pump();
      expect(find.text('host default: first'), findsOneWidget);
      final hostClose = hostToast.close();
      await tester.pumpAndSettle();
      await hostClose;

      await tester.pumpWidget(
        _buildOwnedHost(
          integration: secondIntegration,
          child: const SizedBox.shrink(),
        ),
      );
      final baseToast = SuperOverlay.toast(
        'second',
        options: const OverlayToastOptions(
          displayPolicy: OverlayToastDisplayPolicy.stack,
          displayDuration: Duration(minutes: 1),
        ),
      );
      await tester.pump();
      expect(find.text('base default: second'), findsOneWidget);
      final baseClose = baseToast.close();
      await tester.pumpAndSettle();
      await baseClose;

      await tester.pumpWidget(const SizedBox.shrink());
      expect(overlayConfig.toast.builder, same(configuredBaseBuilder));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      firstIntegration.dispose();
      secondIntegration.dispose();
      overlayConfig.toast = originalToast;
    }
  });

  testWidgets('atomically replaces distinct keyed MaterialApp roots', (
    tester,
  ) async {
    await _verifyAtomicHostReplacement(tester, useDistinctRootKeys: true);
  });

  testWidgets('atomically replaces integration in the same unkeyed element', (
    tester,
  ) async {
    await _verifyAtomicHostReplacement(tester, useDistinctRootKeys: false);
  });

  testWidgets('removing an init builder restores the default renderer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHost(
        toastBuilder: (message) => Text('Custom host toast: $message'),
      ),
    );

    final custom = SuperOverlay.toast(
      'first',
      options: const OverlayToastOptions(displayDuration: Duration(minutes: 1)),
    );
    await tester.pump();
    expect(find.text('Custom host toast: first'), findsOneWidget);
    final customClose = custom.close();
    await tester.pumpAndSettle();
    await customClose;

    await tester.pumpWidget(_buildHost());

    final restored = SuperOverlay.toast(
      'restored default',
      options: const OverlayToastOptions(displayDuration: Duration(minutes: 1)),
    );
    await tester.pump();
    expect(find.text('Custom host toast: restored default'), findsNothing);
    expect(find.text('restored default'), findsOneWidget);
    final restoredClose = restored.close();
    await tester.pumpAndSettle();
    await restoredClose;
  });

  testWidgets('disposing the host settles every active command handle', (
    tester,
  ) async {
    late BuildContext targetContext;
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlay.init(),
        navigatorObservers: [SuperOverlay.observer],
        home: Scaffold(
          body: Builder(
            builder: (context) {
              targetContext = context;
              return const SizedBox(width: 80, height: 40);
            },
          ),
        ),
      ),
    );

    final handles = <OverlayHandle<void>>[
      SuperOverlay.dialog.show<void>(builder: (_) => const Text('Host dialog')),
      SuperOverlay.loading.show(message: 'Host loading'),
      SuperOverlay.popup.show<void>(
        targetContext: targetContext,
        builder: (_) => const Text('Host popup'),
      ),
      SuperOverlay.notify.success(
        'Host notification',
        options: const OverlayNotifyOptions(displayDuration: null),
      ),
      SuperOverlay.toast(
        'Host toast',
        options: const OverlayToastOptions(
          displayPolicy: OverlayToastDisplayPolicy.stack,
          displayDuration: Duration(minutes: 1),
        ),
      ),
    ];
    await tester.pump();
    await Future.wait(handles.map((handle) => handle.visible));

    final closed = List<bool>.filled(handles.length, false);
    for (var index = 0; index < handles.length; index++) {
      handles[index].closed.then((_) => closed[index] = true);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.idle();

    expect(closed, everyElement(isTrue));
    expect(handles.map((handle) => handle.isVisible), everyElement(isFalse));
    expect(SuperOverlay.exists(), isFalse);
  });
}
