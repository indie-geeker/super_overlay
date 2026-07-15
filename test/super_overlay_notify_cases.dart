import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

import 'overlay_test_support.dart';

Widget buildNotifyOverlayApp(Widget child, {NotifyStyle? notifyStyle}) {
  return MaterialApp(
    builder: SuperOverlay.init(notifyStyle: notifyStyle),
    navigatorObservers: [SuperOverlay.observer],
    home: Scaffold(body: child),
  );
}

void main() {
  registerNotifyOverlayTests();
}

void registerNotifyOverlayTests() {
  setUp(() {
    overlayConfig.notify = const NotifyConfig();
  });

  testWidgets('each notify command renders its default builder', (
    tester,
  ) async {
    await tester.pumpWidget(buildNotifyOverlayApp(const SizedBox.shrink()));

    final handles = [
      SuperOverlay.notify.success('notify-success'),
      SuperOverlay.notify.failure('notify-failure'),
      SuperOverlay.notify.warning('notify-warning'),
      SuperOverlay.notify.error('notify-error'),
      SuperOverlay.notify.alert('notify-alert'),
    ];

    for (var i = 0; i < handles.length; i++) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('notify-${OverlayNotificationType.values[i].name}'),
        findsOneWidget,
      );

      await handles[i].close();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('every custom notify stays below display cutout padding', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44);
    tester.view.viewPadding = const FakeViewPadding(top: 44);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    Widget surface(OverlayNotificationType type, String message) {
      return Container(
        key: ValueKey('safe-notify-${type.name}'),
        child: Text(message),
      );
    }

    await tester.pumpWidget(
      buildNotifyOverlayApp(
        const SizedBox.shrink(),
        notifyStyle: NotifyStyle(
          successBuilder:
              (message) => surface(OverlayNotificationType.success, message),
          failureBuilder:
              (message) => surface(OverlayNotificationType.failure, message),
          warningBuilder:
              (message) => surface(OverlayNotificationType.warning, message),
          errorBuilder:
              (message) => surface(OverlayNotificationType.error, message),
          alertBuilder:
              (message) => surface(OverlayNotificationType.alert, message),
        ),
      ),
    );

    final handles = [
      SuperOverlay.notify.success('success'),
      SuperOverlay.notify.failure('failure'),
      SuperOverlay.notify.warning('warning'),
      SuperOverlay.notify.error('error'),
      SuperOverlay.notify.alert('alert'),
    ];
    await tester.pump();

    for (final type in OverlayNotificationType.values) {
      expect(
        tester.getTopLeft(find.byKey(ValueKey('safe-notify-${type.name}'))).dy,
        greaterThanOrEqualTo(44),
      );
    }

    await SuperOverlay.close(
      target: OverlayCloseTarget.allNotifications,
      force: true,
    );
    await Future.wait(handles.map((handle) => handle.closed));
  });

  testWidgets('notify honors physical cutout after safe padding is consumed', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44);
    tester.view.viewPadding = const FakeViewPadding(top: 44);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    final integration = SuperOverlay.integration(
      notifyStyle: NotifyStyle(
        warningBuilder:
            (message) => Container(
              key: const ValueKey('consumed-padding-notify'),
              child: Text(message),
            ),
      ),
    );
    addTearDown(integration.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final data = MediaQuery.of(context);
          return MediaQuery(
            data: data.copyWith(padding: EdgeInsets.zero),
            child: integration.builder(context, child),
          );
        },
        navigatorObservers: [integration.observer],
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    final handle = SuperOverlay.notify.warning(
      'Physical cutout notification',
      options: const OverlayNotifyOptions(displayDuration: null),
    );
    await tester.pump();

    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('consumed-padding-notify')))
          .dy,
      greaterThanOrEqualTo(44),
    );

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
  });

  testWidgets('notify auto-dismisses after displayDuration', (tester) async {
    await tester.pumpWidget(buildNotifyOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.notify.success(
      'Auto Notify',
      options: const OverlayNotifyOptions(
        displayDuration: Duration(milliseconds: 300),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Auto Notify'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    await handle.closed;
    expect(find.text('Auto Notify'), findsNothing);
  });

  testWidgets('init notifyStyle changes default notify widgets', (
    tester,
  ) async {
    final originalNotify = overlayConfig.notify;
    addTearDown(() => overlayConfig.notify = originalNotify);

    await tester.pumpWidget(
      buildNotifyOverlayApp(
        const SizedBox.shrink(),
        notifyStyle: NotifyStyle(
          successBuilder: (message) => Text('Styled Success $message'),
        ),
      ),
    );

    final handle = SuperOverlay.notify.success('Init Notify');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Styled Success Init Notify'), findsOneWidget);
    expect(find.text('Init Notify'), findsNothing);

    await handle.close();
    await tester.pumpAndSettle();
  });

  testWidgets('notify dismiss statuses close the correct entries', (
    tester,
  ) async {
    await tester.pumpWidget(buildNotifyOverlayApp(const SizedBox.shrink()));

    final one = SuperOverlay.notify.success(
      'Notify One',
      options: const OverlayNotifyOptions(tag: 'notify-one'),
    );
    final two = SuperOverlay.notify.warning(
      'Notify Two',
      options: const OverlayNotifyOptions(tag: 'notify-two'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await one.close();
    await tester.pumpAndSettle();

    expect(find.text('Notify One'), findsNothing);
    expect(find.text('Notify Two'), findsOneWidget);

    await SuperOverlay.close(target: OverlayCloseTarget.allNotifications);
    await tester.pumpAndSettle();
    await two.closed;
    expect(find.text('Notify Two'), findsNothing);
  });

  testWidgets(
    'auto dismiss closes notify before dialog when loading is absent',
    (tester) async {
      await tester.pumpWidget(buildNotifyOverlayApp(const SizedBox.shrink()));

      final dialog = SuperOverlay.dialog.show<void>(
        builder: (_) => const Text('Auto Custom'),
      );
      final notify = SuperOverlay.notify.alert('Auto Notify');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await SuperOverlay.close(target: OverlayCloseTarget.topMost);
      await tester.pumpAndSettle();
      await notify.closed;

      expect(find.text('Auto Notify'), findsNothing);
      expect(find.text('Auto Custom'), findsOneWidget);

      await dialog.close();
      await tester.pumpAndSettle();
    },
  );
}
