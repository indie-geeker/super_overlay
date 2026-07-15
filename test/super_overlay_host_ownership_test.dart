import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';
import 'package:super_overlay/src/config/attach_dialog_config.dart';
import 'package:super_overlay/src/config/custom_dialog_config.dart';
import 'package:super_overlay/src/config/enum_config.dart';
import 'package:super_overlay/src/config/notify_config.dart';
import 'package:super_overlay/src/config/overlay_config.dart';
import 'package:super_overlay/src/config/toast_config.dart';
import 'package:super_overlay/src/data/show_param.dart';
import 'package:super_overlay/src/helper/overlay_manager.dart';

class _PendingCommandProbe extends StatefulWidget {
  const _PendingCommandProbe({required this.errors});

  final Map<String, Object> errors;

  @override
  State<_PendingCommandProbe> createState() => _PendingCommandProbeState();
}

class _PendingCommandProbeState extends State<_PendingCommandProbe> {
  @override
  void initState() {
    super.initState();
    _capture(
      'show',
      () => SuperOverlay.toast(
        'must not be routed during handoff',
        options: const OverlayToastOptions(
          displayDuration: Duration(minutes: 1),
        ),
      ),
    );
    _capture('global-close', SuperOverlay.close);
    _capture('exists', SuperOverlay.exists);
  }

  void _capture(String command, Object? Function() callback) {
    try {
      callback();
    } catch (error) {
      widget.errors[command] = error;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Widget _host({
  required Key key,
  required SuperOverlayIntegration integration,
  GlobalKey<NavigatorState>? navigatorKey,
  Widget child = const SizedBox.shrink(),
}) {
  return MaterialApp(
    key: key,
    navigatorKey: navigatorKey,
    builder: integration.builder,
    navigatorObservers: [integration.observer],
    home: Scaffold(body: child),
  );
}

Widget _legacyHost(Key key) {
  return MaterialApp(
    key: key,
    builder: SuperOverlay.init(),
    home: const Scaffold(),
  );
}

Widget _sideBySide(Widget first, Widget second) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Row(
      children: [
        Expanded(key: first.key, child: first),
        Expanded(key: second.key, child: second),
      ],
    ),
  );
}

Widget _hostSlots({Widget? active, Widget? candidate}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Row(
      children: [
        Expanded(child: active ?? const SizedBox.shrink()),
        Expanded(child: candidate ?? const SizedBox.shrink()),
      ],
    ),
  );
}

Widget _hosts(List<Widget> hosts) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Row(
      children: [
        for (final host in hosts) Expanded(key: host.key, child: host),
      ],
    ),
  );
}

Matcher get _unsupportedTopologyError => isA<StateError>().having(
  (error) => error.toString(),
  'message',
  allOf(
    contains('Unsupported'),
    contains('multiple MaterialApp'),
    contains('multi-window'),
  ),
);

void _expectSettledConflict() {
  expect(
    () => SuperOverlay.toast('must reject settled conflict'),
    throwsA(_unsupportedTopologyError),
  );
  expect(SuperOverlay.close, throwsA(_unsupportedTopologyError));
  expect(SuperOverlay.exists, throwsA(_unsupportedTopologyError));
}

enum _ClosingSurface { dialog, popup, notification }

Future<void> _verifyCloseInFlightSettlesBeforePromotion(
  WidgetTester tester, {
  required _ClosingSurface surface,
}) async {
  final retired = SuperOverlay.integration();
  final promoted = SuperOverlay.integration();
  late BuildContext targetContext;

  Widget host(Key key, SuperOverlayIntegration integration) {
    return _host(
      key: key,
      integration: integration,
      child: Builder(
        builder: (context) {
          targetContext = context;
          return const SizedBox(width: 80, height: 40);
        },
      ),
    );
  }

  OverlayHandle<void> showSurface(
    String label, {
    String tag = 'retired-in-flight-owner',
    OverlayStrategy strategy = OverlayStrategy.stack,
  }) {
    return switch (surface) {
      _ClosingSurface.dialog => SuperOverlay.dialog.show<void>(
        builder: (_) => Text(label),
        options: OverlayDialogOptions(tag: tag, strategy: strategy),
      ),
      _ClosingSurface.popup => SuperOverlay.popup.show<void>(
        targetContext: targetContext,
        builder: (_) => Text(label),
        options: OverlayPopupOptions(tag: tag, strategy: strategy),
      ),
      _ClosingSurface.notification => SuperOverlay.notify.success(
        label,
        options: OverlayNotifyOptions(
          tag: tag,
          strategy: strategy,
          displayDuration: null,
        ),
      ),
    };
  }

  try {
    await tester.pumpWidget(host(const ValueKey('in-flight-retired'), retired));
    final retiredHandle = showSurface('retired close in flight');
    await tester.pumpAndSettle();
    await retiredHandle.visible;

    var retiredClosedCount = 0;
    final retiredClosedProbe = retiredHandle.closed.then<void>((_) {
      retiredClosedCount++;
    });
    var primaryCloseCount = 0;
    final primaryClose = retiredHandle.close().then<void>((_) {
      primaryCloseCount++;
    });
    expect(retiredHandle.isVisible, isFalse);
    await tester.pump();

    final replacement = showSurface(
      'retired replacement must not render',
      strategy: OverlayStrategy.replaceExisting,
    );
    Object? replacementVisibleError;
    final replacementVisibleProbe = replacement.visible.then<void>(
      (_) {},
      onError: (Object error, StackTrace _) {
        replacementVisibleError = error;
      },
    );
    var replacementClosedCount = 0;
    final replacementClosedProbe = replacement.closed.then<void>((_) {
      replacementClosedCount++;
    });
    await tester.pump();

    var joinedCloseCount = 0;
    final joinedClose = retiredHandle.close().then<void>((_) {
      joinedCloseCount++;
    });
    var replacementCloseCount = 0;
    final replacementClose = replacement.close().then<void>((_) {
      replacementCloseCount++;
    });
    await tester.pump(const Duration(milliseconds: 50));
    await tester.idle();

    expect(retiredClosedCount, 0);
    expect(primaryCloseCount, 0);
    expect(joinedCloseCount, 0);
    expect(replacementClosedCount, 0);
    expect(replacementCloseCount, 0);

    await tester.pumpWidget(
      host(const ValueKey('in-flight-promoted'), promoted),
    );
    await tester.pump();
    await tester.idle();

    expect(retiredClosedCount, 1);
    expect(primaryCloseCount, 1);
    expect(joinedCloseCount, 1);
    expect(replacementClosedCount, 1);
    expect(replacementCloseCount, 1);
    expect(replacementVisibleError, isA<StateError>());
    expect(find.text('retired replacement must not render'), findsNothing);
    await Future.wait<void>([
      retiredClosedProbe,
      primaryClose,
      joinedClose,
      replacementClosedProbe,
      replacementClose,
      replacementVisibleProbe,
    ]);

    final promotedHandle = showSurface(
      'promoted surface',
      tag: 'promoted-in-flight-owner',
    );
    await tester.pumpAndSettle();
    await promotedHandle.visible;

    expect(retiredClosedCount, 1);
    expect(promotedHandle.isVisible, isTrue);
    expect(find.text('promoted surface'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.idle();

    expect(retiredClosedCount, 1);
    expect(primaryCloseCount, 1);
    expect(joinedCloseCount, 1);
    expect(replacementClosedCount, 1);
    expect(replacementCloseCount, 1);
    expect(promotedHandle.isVisible, isTrue);

    final promotedClose = promotedHandle.close();
    await tester.pumpAndSettle();
    await promotedClose;
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    retired.dispose();
    promoted.dispose();
  }
}

void main() {
  testWidgets('candidate route events do not pollute retained host binding', (
    tester,
  ) async {
    final retained = SuperOverlay.integration();
    final candidate = SuperOverlay.integration();
    final retainedNavigator = GlobalKey<NavigatorState>();
    final candidateNavigator = GlobalKey<NavigatorState>();
    late BuildContext retainedContext;

    Widget retainedHost() => _host(
      key: const ValueKey('route-retained'),
      integration: retained,
      navigatorKey: retainedNavigator,
      child: Builder(
        builder: (context) {
          retainedContext = context;
          return const Text('retained home');
        },
      ),
    );
    Widget candidateHost() => _host(
      key: const ValueKey('route-candidate'),
      integration: candidate,
      navigatorKey: candidateNavigator,
      child: const Text('candidate home'),
    );

    await tester.pumpWidget(_hostSlots(active: retainedHost()));
    final handle = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('retained route overlay'),
      options: OverlayDialogOptions(
        tag: 'retained-route-overlay',
        bindToRoute: true,
        bindToWidget: retainedContext,
      ),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _hostSlots(active: retainedHost(), candidate: candidateHost()),
    );
    candidateNavigator.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('candidate second route')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('retained route overlay'), findsOneWidget);

    candidateNavigator.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.pumpWidget(_hostSlots(active: retainedHost()));
    expect(find.text('retained route overlay'), findsOneWidget);

    retainedNavigator.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('retained second route')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('retained route overlay'), findsNothing);

    retainedNavigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('retained route overlay'), findsOneWidget);

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    await tester.pumpWidget(const SizedBox.shrink());
    retained.dispose();
    candidate.dispose();
  });

  testWidgets('promoted host restores candidate current route snapshot', (
    tester,
  ) async {
    final active = SuperOverlay.integration();
    final candidate = SuperOverlay.integration();
    final candidateNavigator = GlobalKey<NavigatorState>();

    Widget activeHost() =>
        _host(key: const ValueKey('snapshot-active'), integration: active);
    Widget candidateHost() => _host(
      key: const ValueKey('snapshot-candidate'),
      integration: candidate,
      navigatorKey: candidateNavigator,
      child: const Text('snapshot candidate home'),
    );

    await tester.pumpWidget(_hostSlots(active: activeHost()));
    await tester.pumpWidget(
      _hostSlots(active: activeHost(), candidate: candidateHost()),
    );
    candidateNavigator.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('snapshot second route')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(_hostSlots(candidate: candidateHost()));
    final handle = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('promoted route overlay'),
      options: const OverlayDialogOptions(
        tag: 'promoted-route-overlay',
        bindToRoute: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('promoted route overlay'), findsOneWidget);

    candidateNavigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('promoted route overlay'), findsNothing);
    await handle.closed;

    await tester.pumpWidget(const SizedBox.shrink());
    active.dispose();
    candidate.dispose();
  });

  testWidgets(
    'retired toast tail cannot advance the promoted generation queue',
    (tester) async {
      final originalToastConfig = overlayConfig.toast;
      final retired = SuperOverlay.integration();
      final promoted = SuperOverlay.integration();

      try {
        overlayConfig.toast = const ToastConfig(
          animationTime: Duration(milliseconds: 200),
          nonAnimationTypes: [],
        );
        await tester.pumpWidget(
          _host(key: const ValueKey('toast-retired'), integration: retired),
        );

        final retiredHandle = SuperOverlay.toast(
          'retired toast',
          options: const OverlayToastOptions(
            tag: 'retired-toast',
            displayDuration: Duration(minutes: 1),
          ),
        );
        await tester.pumpAndSettle();
        await retiredHandle.visible;

        var retiredClosedCount = 0;
        retiredHandle.closed.then((_) => retiredClosedCount++);
        final retiredClose = retiredHandle.close();
        await tester.pump(const Duration(milliseconds: 50));

        await tester.pumpWidget(
          _host(key: const ValueKey('toast-promoted'), integration: promoted),
        );
        await tester.idle();
        final settledBeforePromotedCommands = retiredClosedCount == 1;

        final first = SuperOverlay.toast(
          'promoted first',
          options: const OverlayToastOptions(
            displayDuration: Duration(minutes: 1),
          ),
        );
        final second = SuperOverlay.toast(
          'promoted second',
          options: const OverlayToastOptions(
            displayDuration: Duration(minutes: 1),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();
        await retiredClose;

        expect(
          <String, Object>{
            'retired settled before promoted commands':
                settledBeforePromotedCommands,
            'retired closed count': retiredClosedCount,
            'promoted first visible':
                find.text('promoted first').evaluate().length,
            'promoted second visible before first closes':
                find.text('promoted second').evaluate().length,
          },
          <String, Object>{
            'retired settled before promoted commands': true,
            'retired closed count': 1,
            'promoted first visible': 1,
            'promoted second visible before first closes': 0,
          },
        );

        final firstClose = first.close();
        await tester.pumpAndSettle();
        await firstClose;
        await second.visible;
        expect(find.text('promoted second'), findsOneWidget);

        final secondClose = second.close();
        await tester.pumpAndSettle();
        await secondClose;
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        retired.dispose();
        promoted.dispose();
        overlayConfig.toast = originalToastConfig;
      }
    },
  );

  testWidgets(
    'toast replacement waiting on a retired generation never reaches the new host',
    (tester) async {
      final originalToastConfig = overlayConfig.toast;
      final retired = SuperOverlay.integration();
      final promoted = SuperOverlay.integration();

      try {
        overlayConfig.toast = const ToastConfig(
          animationTime: Duration(milliseconds: 200),
          nonAnimationTypes: [],
        );
        await tester.pumpWidget(
          _host(
            key: const ValueKey('replacement-retired'),
            integration: retired,
          ),
        );

        SuperOverlay.toast(
          'replacement source',
          options: const OverlayToastOptions(
            tag: 'cross-generation-replacement',
            displayPolicy: OverlayToastDisplayPolicy.stack,
            displayDuration: Duration(minutes: 1),
          ),
        );
        await tester.pumpAndSettle();

        final replacement = SuperOverlay.toast(
          'retired replacement',
          options: const OverlayToastOptions(
            tag: 'cross-generation-replacement',
            strategy: OverlayStrategy.replaceExisting,
            displayPolicy: OverlayToastDisplayPolicy.stack,
            displayDuration: Duration(minutes: 1),
          ),
        );
        final visibleOutcome = replacement.visible.then<Object?>(
          (_) => null,
          onError: (Object error, StackTrace _) => error,
        );
        final closedOutcome = replacement.closed.then<Object?>(
          (_) => null,
          onError: (Object error, StackTrace _) => error,
        );
        await tester.pump(const Duration(milliseconds: 50));

        await tester.pumpWidget(
          _host(
            key: const ValueKey('replacement-promoted'),
            integration: promoted,
          ),
        );
        await tester.idle();
        final promotedHandle = SuperOverlay.toast(
          'promoted replacement winner',
          options: const OverlayToastOptions(
            displayPolicy: OverlayToastDisplayPolicy.stack,
            displayDuration: Duration(minutes: 1),
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();

        expect(await visibleOutcome, isA<StateError>());
        expect(await closedOutcome, isNull);
        expect(find.text('retired replacement'), findsNothing);
        expect(find.text('promoted replacement winner'), findsOneWidget);

        await tester.pumpAndSettle();
        final promotedClose = promotedHandle.close();
        await tester.pumpAndSettle();
        await promotedClose;
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        retired.dispose();
        promoted.dispose();
        overlayConfig.toast = originalToastConfig;
      }
    },
  );

  testWidgets(
    'async loading back stops after retirement and keeps promoted loading visible',
    (tester) async {
      final retired = SuperOverlay.integration();
      final promoted = SuperOverlay.integration();
      final backEntered = Completer<void>();
      final backGate = Completer<bool>();

      try {
        await tester.pumpWidget(
          _host(key: const ValueKey('loading-retired'), integration: retired),
        );
        var retiredClosedCount = 0;
        final retiredClosed = OverlayManager.instance.showLoading<void>(
          param: ShowLoadingParam(
            builder: (_) => const Text('retired loading'),
            alignment: Alignment.center,
            clickMaskDismiss: false,
            animationType: AnimationType.fade,
            nonAnimationTypes: const <NonAnimationType>[],
            animationBuilder: null,
            usePenetrate: false,
            useAnimation: false,
            animationTime: Duration.zero,
            maskColor: Colors.black45,
            maskWidget: null,
            onDismiss: null,
            onMask: null,
            awaitCompletion: AwaitCompletion.dismiss,
            displayTime: null,
            leastLoadingTime: Duration.zero,
            tag: 'retired-loading',
            backType: BackType.normal,
            onBack: () {
              if (!backEntered.isCompleted) {
                backEntered.complete();
              }
              return backGate.future;
            },
          ),
        );
        retiredClosed.then((_) => retiredClosedCount++);
        await tester.pump();

        final backResult = OverlayManager.instance.handleBackEvent();
        await backEntered.future;

        await tester.pumpWidget(
          _host(key: const ValueKey('loading-promoted'), integration: promoted),
        );
        await tester.idle();
        await retiredClosed;
        expect(retiredClosedCount, 1);

        final promotedHandle = SuperOverlay.loading.show(
          message: 'promoted loading',
          options: const OverlayLoadingOptions(tag: 'promoted-loading'),
        );
        await tester.pump();
        await promotedHandle.visible;

        backGate.complete(false);
        await tester.pump();
        expect(await backResult, isFalse);
        await tester.pump();

        expect(promotedHandle.isVisible, isTrue);
        expect(find.text('promoted loading'), findsOneWidget);

        final promotedClose = promotedHandle.close();
        await tester.pumpAndSettle();
        await promotedClose;
      } finally {
        if (!backGate.isCompleted) {
          backGate.complete(true);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        retired.dispose();
        promoted.dispose();
      }
    },
  );

  testWidgets(
    'retired async loading back cannot traverse promoted generation surfaces',
    (tester) async {
      final retired = SuperOverlay.integration();
      final promoted = SuperOverlay.integration();
      final backEntered = Completer<void>();
      final backGate = Completer<bool>();

      try {
        await tester.pumpWidget(
          _host(
            key: const ValueKey('back-traversal-retired'),
            integration: retired,
          ),
        );
        final retiredClosed = OverlayManager.instance.showLoading<void>(
          param: ShowLoadingParam(
            builder: (_) => const Text('retired gated loading'),
            alignment: Alignment.center,
            clickMaskDismiss: false,
            animationType: AnimationType.fade,
            nonAnimationTypes: const <NonAnimationType>[],
            animationBuilder: null,
            usePenetrate: false,
            useAnimation: false,
            animationTime: Duration.zero,
            maskColor: Colors.black45,
            maskWidget: null,
            onDismiss: null,
            onMask: null,
            awaitCompletion: AwaitCompletion.dismiss,
            displayTime: null,
            leastLoadingTime: Duration.zero,
            tag: 'retired-gated-loading',
            backType: BackType.ignore,
            onBack: () {
              if (!backEntered.isCompleted) {
                backEntered.complete();
              }
              return backGate.future;
            },
          ),
        );
        await tester.pump();

        final backResult = OverlayManager.instance.handleBackEvent();
        await backEntered.future;

        await tester.pumpWidget(
          _host(
            key: const ValueKey('back-traversal-promoted'),
            integration: promoted,
          ),
        );
        await tester.idle();
        await retiredClosed;

        final promotedNotify = SuperOverlay.notify.success(
          'promoted persistent notification',
          options: const OverlayNotifyOptions(
            tag: 'promoted-persistent-notification',
            displayDuration: null,
          ),
        );
        final promotedDialog = SuperOverlay.dialog.show<void>(
          builder: (_) => const Text('promoted persistent dialog'),
          options: const OverlayDialogOptions(
            tag: 'promoted-persistent-dialog',
          ),
        );
        await tester.pumpAndSettle();
        await Future.wait([promotedNotify.visible, promotedDialog.visible]);

        backGate.complete(false);
        await tester.pumpAndSettle();

        final result = await backResult;
        expect(promotedNotify.isVisible, isTrue);
        expect(promotedDialog.isVisible, isTrue);
        expect(find.text('promoted persistent notification'), findsOneWidget);
        expect(find.text('promoted persistent dialog'), findsOneWidget);
        expect(result, isFalse);

        await Future.wait([promotedNotify.close(), promotedDialog.close()]);
        await tester.pumpAndSettle();
      } finally {
        if (!backGate.isCompleted) {
          backGate.complete(true);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        retired.dispose();
        promoted.dispose();
      }
    },
  );

  testWidgets('dialog teardown settles in-flight ownership operations', (
    tester,
  ) async {
    final original = overlayConfig.custom;
    overlayConfig.custom = const CustomDialogConfig(
      animationTime: Duration(milliseconds: 500),
      nonAnimationTypes: <NonAnimationType>[
        NonAnimationType.open,
        NonAnimationType.routeClose,
      ],
    );
    try {
      await _verifyCloseInFlightSettlesBeforePromotion(
        tester,
        surface: _ClosingSurface.dialog,
      );
    } finally {
      overlayConfig.custom = original;
    }
  });

  testWidgets('popup teardown settles in-flight ownership operations', (
    tester,
  ) async {
    final original = overlayConfig.attach;
    overlayConfig.attach = const AttachDialogConfig(
      animationTime: Duration(milliseconds: 500),
      nonAnimationTypes: <NonAnimationType>[
        NonAnimationType.open,
        NonAnimationType.routeClose,
      ],
    );
    try {
      await _verifyCloseInFlightSettlesBeforePromotion(
        tester,
        surface: _ClosingSurface.popup,
      );
    } finally {
      overlayConfig.attach = original;
    }
  });

  testWidgets('notification teardown settles in-flight ownership operations', (
    tester,
  ) async {
    final original = overlayConfig.notify;
    overlayConfig.notify = const NotifyConfig(
      animationTime: Duration(milliseconds: 500),
      nonAnimationTypes: <NonAnimationType>[NonAnimationType.open],
    );
    try {
      await _verifyCloseInFlightSettlesBeforePromotion(
        tester,
        surface: _ClosingSurface.notification,
      );
    } finally {
      overlayConfig.notify = original;
    }
  });

  testWidgets('legacy hosts with the same owner identity still conflict', (
    tester,
  ) async {
    await tester.pumpWidget(_legacyHost(const ValueKey('legacy-active')));
    await tester.pumpWidget(
      _sideBySide(
        _legacyHost(const ValueKey('legacy-active')),
        _legacyHost(const ValueKey('legacy-candidate')),
      ),
    );

    _expectSettledConflict();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'candidate first build rejects commands while handoff is pending',
    (tester) async {
      final retained = SuperOverlay.integration();
      final candidate = SuperOverlay.integration();
      final errors = <String, Object>{};

      await tester.pumpWidget(
        _host(key: const ValueKey('retained'), integration: retained),
      );

      await tester.pumpWidget(
        _sideBySide(
          _host(key: const ValueKey('retained'), integration: retained),
          _host(
            key: const ValueKey('candidate'),
            integration: candidate,
            child: _PendingCommandProbe(errors: errors),
          ),
        ),
      );

      expect(
        errors.keys,
        containsAll(<String>['show', 'global-close', 'exists']),
      );
      for (final error in errors.values) {
        expect(error, isA<StateError>());
        expect(error.toString(), contains('pending'));
      }

      await tester.pumpWidget(const SizedBox.shrink());
      retained.dispose();
      candidate.dispose();
    },
  );

  testWidgets(
    'settled conflict retains handle ownership and recovers old host',
    (tester) async {
      final retained = SuperOverlay.integration(
        toastBuilder: (message) => Text('retained default: $message'),
      );
      final candidate = SuperOverlay.integration();

      await tester.pumpWidget(
        _host(key: const ValueKey('retained'), integration: retained),
      );
      final retainedHandle = SuperOverlay.dialog.show<void>(
        builder: (_) => const Text('retained generation overlay'),
        options: const OverlayDialogOptions(tag: 'retained-generation'),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _sideBySide(
          _host(key: const ValueKey('retained'), integration: retained),
          _host(key: const ValueKey('candidate'), integration: candidate),
        ),
      );

      _expectSettledConflict();

      final retainedClose = retainedHandle.close();
      await tester.pumpAndSettle();
      await retainedClose;
      expect(find.text('retained generation overlay'), findsNothing);

      await tester.pumpWidget(
        _host(key: const ValueKey('retained'), integration: retained),
      );
      final recovered = SuperOverlay.toast(
        'recovered',
        options: const OverlayToastOptions(
          displayPolicy: OverlayToastDisplayPolicy.stack,
          displayDuration: Duration(minutes: 1),
        ),
      );
      await tester.pump();
      expect(find.text('retained default: recovered'), findsOneWidget);

      final recoveredClose = recovered.close();
      await tester.pumpAndSettle();
      await recoveredClose;
      await tester.pumpWidget(const SizedBox.shrink());
      retained.dispose();
      candidate.dispose();
    },
  );

  testWidgets('removing active host promotes its only candidate', (
    tester,
  ) async {
    final active = SuperOverlay.integration();
    final candidate = SuperOverlay.integration(
      toastBuilder: (message) => Text('promoted default: $message'),
    );

    await tester.pumpWidget(
      _host(key: const ValueKey('active'), integration: active),
    );
    final oldHandle = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('old generation'),
      options: const OverlayDialogOptions(tag: 'shared-generation-tag'),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _sideBySide(
        _host(key: const ValueKey('active'), integration: active),
        _host(key: const ValueKey('candidate'), integration: candidate),
      ),
    );
    _expectSettledConflict();

    await tester.pumpWidget(
      _host(key: const ValueKey('candidate'), integration: candidate),
    );
    await tester.idle();
    await oldHandle.closed;

    final promotedHandle = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('promoted generation'),
      options: const OverlayDialogOptions(tag: 'shared-generation-tag'),
    );
    final promotedToast = SuperOverlay.toast(
      'ready',
      options: const OverlayToastOptions(
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    );
    await tester.pumpAndSettle();
    await oldHandle.close();
    oldHandle.refresh();
    await tester.pump();

    expect(promotedHandle.isVisible, isTrue);
    expect(find.text('promoted generation'), findsOneWidget);
    expect(find.text('promoted default: ready'), findsOneWidget);

    final promotedClose = promotedHandle.close();
    final toastClose = promotedToast.close();
    await tester.pumpAndSettle();
    await Future.wait([promotedClose, toastClose]);
    await tester.pumpWidget(const SizedBox.shrink());
    active.dispose();
    candidate.dispose();
  });

  testWidgets('two remaining candidates never win by registration order', (
    tester,
  ) async {
    final active = SuperOverlay.integration();
    final firstCandidate = SuperOverlay.integration(
      toastBuilder: (message) => Text('first candidate: $message'),
    );
    final secondCandidate = SuperOverlay.integration(
      toastBuilder: (message) => Text('second candidate: $message'),
    );

    await tester.pumpWidget(
      _host(key: const ValueKey('active'), integration: active),
    );
    await tester.pumpWidget(
      _hosts([
        _host(key: const ValueKey('active'), integration: active),
        _host(
          key: const ValueKey('first-candidate'),
          integration: firstCandidate,
        ),
        _host(
          key: const ValueKey('second-candidate'),
          integration: secondCandidate,
        ),
      ]),
    );
    _expectSettledConflict();

    await tester.pumpWidget(
      _hosts([
        _host(
          key: const ValueKey('first-candidate'),
          integration: firstCandidate,
        ),
        _host(
          key: const ValueKey('second-candidate'),
          integration: secondCandidate,
        ),
      ]),
    );
    _expectSettledConflict();

    await tester.pumpWidget(
      _host(
        key: const ValueKey('second-candidate'),
        integration: secondCandidate,
      ),
    );
    final promoted = SuperOverlay.toast(
      'only survivor',
      options: const OverlayToastOptions(
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    );
    await tester.pump();
    expect(find.text('second candidate: only survivor'), findsOneWidget);

    final close = promoted.close();
    await tester.pumpAndSettle();
    await close;
    await tester.pumpWidget(const SizedBox.shrink());
    active.dispose();
    firstCandidate.dispose();
    secondCandidate.dispose();
  });
}
