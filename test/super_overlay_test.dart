import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      builder: SuperOverlayInit.init(),
      navigatorObservers: [SuperOverlayInit.observer],
      home: Scaffold(body: child),
    );
  }

  Future<bool> dispatchSystemBack(WidgetTester tester) async {
    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    return handled;
  }

  testWidgets('initializes with SuperOverlayInit builder', (tester) async {
    await tester.pumpWidget(buildApp(const Text('home')));

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('custom overlay new API renders and dismisses by tag', (
    tester,
  ) async {
    Object? result;

    await tester.pumpWidget(
      buildApp(
        ElevatedButton(
          onPressed: () async {
            result = await SuperOverlay.show(
              builder: (_) => const Text('Dialog Content'),
            ).withTag('profile').withMask(dismissible: true).fire<String>();
          },
          child: const Text('Show'),
        ),
      ),
    );

    expect(find.text('Dialog Content'), findsNothing);

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(find.text('Dialog Content'), findsOneWidget);
    expect(SuperOverlay.checkExist(tag: 'profile'), isTrue);

    await SuperOverlay.dismiss(
      status: DismissStatus.auto,
      tag: 'profile',
      result: 'closed',
    );
    await tester.pumpAndSettle();

    expect(find.text('Dialog Content'), findsNothing);
    expect(SuperOverlay.checkExist(tag: 'profile'), isFalse);
    expect(result, 'closed');
  });

  testWidgets('mask click dismisses when enabled', (tester) async {
    await tester.pumpWidget(
      buildApp(
        ElevatedButton(
          onPressed: () {
            SuperOverlay.show(
              builder: (_) => const Text('Mask Dialog'),
            ).withMask(dismissible: true).fire<void>();
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

    expect(find.text('Mask Dialog'), findsNothing);
  });

  testWidgets('loading, toast, popup, and notify call sites use new API', (
    tester,
  ) async {
    late BuildContext targetContext;

    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) {
            targetContext = context;
            return const Text('target');
          },
        ),
      ),
    );

    SuperOverlay.showLoading(msg: 'Loading...').fire<void>();
    SuperOverlay.showToast('Saved').fire<void>();
    SuperOverlay.showPopup(
      targetContext: targetContext,
      builder: (_) => const Text('Popup Menu'),
    ).fire<void>();
    SuperOverlay.showNotify(msg: 'Done', type: NotifyType.success).fire<void>();

    await tester.pump();
    await SuperOverlay.dismiss(status: DismissStatus.loading);
    await SuperOverlay.dismiss(status: DismissStatus.allToast);
    await SuperOverlay.dismiss(status: DismissStatus.allNotify);
    await tester.pump();
  });

  testWidgets('displayTime auto dismisses and calls onDismiss', (tester) async {
    var dismissed = false;

    await tester.pumpWidget(
      buildApp(
        ElevatedButton(
          onPressed: () {
            SuperOverlay.show(builder: (_) => const Text('Auto Dialog'))
                .withTag('auto')
                .withDisplayTime(const Duration(milliseconds: 300))
                .onDismiss(() => dismissed = true)
                .fire<void>();
          },
          child: const Text('Show Auto'),
        ),
      ),
    );

    await tester.tap(find.text('Show Auto'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Auto Dialog'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Auto Dialog'), findsNothing);
    expect(dismissed, isTrue);
  });

  testWidgets('keepSingle reuses an existing tagged overlay', (tester) async {
    await tester.pumpWidget(buildApp(const SizedBox.shrink()));

    SuperOverlay.show(
      builder: (_) => const Text('First Single'),
    ).withTag('single').withKeepSingle().fire<void>();
    await tester.pumpAndSettle();

    SuperOverlay.show(
      builder: (_) => const Text('Second Single'),
    ).withTag('single').withKeepSingle().fire<void>();
    await tester.pumpAndSettle();

    expect(find.text('First Single'), findsNothing);
    expect(find.text('Second Single'), findsOneWidget);
    expect(SuperOverlay.checkExist(tag: 'single'), isTrue);

    await SuperOverlay.dismiss(tag: 'single');
    await tester.pumpAndSettle();
  });

  testWidgets(
    'permanent overlay ignores normal dismiss and closes with force',
    (tester) async {
      await tester.pumpWidget(buildApp(const SizedBox.shrink()));

      SuperOverlay.show(
        builder: (_) => const Text('Permanent Dialog'),
      ).withTag('permanent').withPermanent().fire<void>();
      await tester.pumpAndSettle();

      await SuperOverlay.dismiss(tag: 'permanent');
      await tester.pumpAndSettle();
      expect(find.text('Permanent Dialog'), findsOneWidget);

      await SuperOverlay.dismiss(tag: 'permanent', force: true);
      await tester.pumpAndSettle();
      expect(find.text('Permanent Dialog'), findsNothing);
    },
  );

  testWidgets('controller refresh rebuilds overlay content', (tester) async {
    final controller = SuperOverlayController();
    var count = 0;

    await tester.pumpWidget(buildApp(const SizedBox.shrink()));

    SuperOverlay.show(
      builder: (_) => Text('Count $count'),
    ).withTag('refresh').withController(controller).fire<void>();
    await tester.pumpAndSettle();

    expect(find.text('Count 0'), findsOneWidget);

    count = 1;
    controller.refresh();
    await tester.pumpAndSettle();

    expect(find.text('Count 0'), findsNothing);
    expect(find.text('Count 1'), findsOneWidget);

    await SuperOverlay.dismiss(tag: 'refresh');
    await tester.pumpAndSettle();
  });

  testWidgets('mask trigger fires at configured pointer phase', (tester) async {
    var maskCount = 0;

    await tester.pumpWidget(buildApp(const SizedBox.shrink()));

    SuperOverlay.show(builder: (_) => const Text('Pointer Dialog'))
        .withMask(dismissible: false, triggerType: MaskTriggerType.down)
        .onMask(() => maskCount++)
        .fire<void>();
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(const Offset(10, 10));
    await tester.pump();

    expect(maskCount, 1);

    await gesture.up();
    await tester.pump();

    expect(maskCount, 1);

    await SuperOverlay.dismiss(force: true);
    await tester.pumpAndSettle();
  });

  testWidgets('loading shows and dismisses by loading status', (tester) async {
    await tester.pumpWidget(buildApp(const SizedBox.shrink()));

    SuperOverlay.showLoading(msg: 'Loading...').fire<void>();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading...'), findsOneWidget);

    await SuperOverlay.dismiss(status: DismissStatus.loading);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('loading waits for leastLoadingTime before closing', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(const SizedBox.shrink()));

    SuperOverlay.showLoading(
      msg: 'Hold',
    ).withLeastLoadingTime(const Duration(milliseconds: 500)).fire<void>();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    await SuperOverlay.dismiss(status: DismissStatus.loading);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Hold'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Hold'), findsNothing);
  });

  testWidgets('repeated loading refreshes the singleton entry', (tester) async {
    await tester.pumpWidget(buildApp(const SizedBox.shrink()));

    SuperOverlay.showLoading(msg: 'First Loading').fire<void>();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    SuperOverlay.showLoading(msg: 'Second Loading').fire<void>();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('First Loading'), findsNothing);
    expect(find.text('Second Loading'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await SuperOverlay.dismiss(status: DismissStatus.loading);
    await tester.pumpAndSettle();
  });

  testWidgets('toast auto-dismisses', (tester) async {
    await tester.pumpWidget(buildApp(const SizedBox.shrink()));

    SuperOverlay.showToast(
      'Saved',
    ).withDisplayTime(const Duration(milliseconds: 300)).fire<void>();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Saved'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('last toast replaces the previous toast', (tester) async {
    await tester.pumpWidget(buildApp(const SizedBox.shrink()));

    SuperOverlay.showToast('First Last')
        .withDisplayType(ToastDisplayType.last)
        .withDisplayTime(const Duration(seconds: 1))
        .fire<void>();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    SuperOverlay.showToast('Second Last')
        .withDisplayType(ToastDisplayType.last)
        .withDisplayTime(const Duration(seconds: 1))
        .fire<void>();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('First Last'), findsNothing);
    expect(find.text('Second Last'), findsOneWidget);

    await SuperOverlay.dismiss(status: DismissStatus.allToast);
    await tester.pumpAndSettle();
  });

  testWidgets('normal toast queues toasts', (tester) async {
    await tester.pumpWidget(buildApp(const SizedBox.shrink()));

    SuperOverlay.showToast(
      'First Normal',
    ).withDisplayTime(const Duration(milliseconds: 300)).fire<void>();
    SuperOverlay.showToast(
      'Second Normal',
    ).withDisplayTime(const Duration(milliseconds: 300)).fire<void>();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('First Normal'), findsOneWidget);
    expect(find.text('Second Normal'), findsNothing);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('First Normal'), findsNothing);
    expect(find.text('Second Normal'), findsOneWidget);

    await SuperOverlay.dismiss(status: DismissStatus.allToast);
    await tester.pumpAndSettle();
  });

  testWidgets('onlyRefresh updates existing toast content', (tester) async {
    await tester.pumpWidget(buildApp(const SizedBox.shrink()));

    SuperOverlay.showToast('First Refresh')
        .withDisplayType(ToastDisplayType.onlyRefresh)
        .withDisplayTime(const Duration(seconds: 1))
        .fire<void>();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    SuperOverlay.showToast('Second Refresh')
        .withDisplayType(ToastDisplayType.onlyRefresh)
        .withDisplayTime(const Duration(seconds: 1))
        .fire<void>();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('First Refresh'), findsNothing);
    expect(find.text('Second Refresh'), findsOneWidget);

    await SuperOverlay.dismiss(status: DismissStatus.allToast);
    await tester.pumpAndSettle();
  });

  testWidgets('multi toast shows multiple entries', (tester) async {
    await tester.pumpWidget(buildApp(const SizedBox.shrink()));

    SuperOverlay.showToast('First Multi')
        .withDisplayType(ToastDisplayType.multi)
        .withDisplayTime(const Duration(seconds: 1))
        .fire<void>();
    SuperOverlay.showToast('Second Multi')
        .withDisplayType(ToastDisplayType.multi)
        .withDisplayTime(const Duration(seconds: 1))
        .fire<void>();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('First Multi'), findsOneWidget);
    expect(find.text('Second Multi'), findsOneWidget);

    await SuperOverlay.dismiss(status: DismissStatus.allToast);
    await tester.pumpAndSettle();
  });

  testWidgets('popup appears relative to target widget', (tester) async {
    await tester.pumpWidget(
      buildApp(
        Align(
          alignment: Alignment.topLeft,
          child: Builder(
            builder: (targetContext) {
              return SizedBox(
                width: 80,
                height: 40,
                child: ElevatedButton(
                  onPressed: () {
                    SuperOverlay.showPopup(
                      targetContext: targetContext,
                      builder: (_) => const SizedBox(
                        width: 120,
                        height: 40,
                        child: Text('Popup Content'),
                      ),
                    ).withTag('popup').fire<void>();
                  },
                  child: const Text('Target'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Target'));
    await tester.pumpAndSettle();

    expect(find.text('Popup Content'), findsOneWidget);
    final targetBottom = tester.getBottomLeft(find.text('Target')).dy;
    final popupTop = tester.getTopLeft(find.text('Popup Content')).dy;
    expect(popupTop, greaterThanOrEqualTo(targetBottom));

    await SuperOverlay.dismiss(status: DismissStatus.attach, tag: 'popup');
    await tester.pumpAndSettle();
  });

  testWidgets('popup clamps inside screen bounds', (tester) async {
    await tester.pumpWidget(
      buildApp(
        Align(
          alignment: Alignment.bottomRight,
          child: Builder(
            builder: (targetContext) {
              return SizedBox(
                width: 48,
                height: 32,
                child: ElevatedButton(
                  onPressed: () {
                    SuperOverlay.showPopup(
                      targetContext: targetContext,
                      builder: (_) => const SizedBox(
                        width: 320,
                        height: 160,
                        child: Text('Clamped Popup'),
                      ),
                    ).fire<void>();
                  },
                  child: const Text('Edge'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edge'), warnIfMissed: false);
    await tester.pumpAndSettle();

    final popupRect = tester.getRect(find.byType(SizedBox).last);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(popupRect.left, greaterThanOrEqualTo(0));
    expect(popupRect.top, greaterThanOrEqualTo(0));
    expect(popupRect.right, lessThanOrEqualTo(screen.width));
    expect(popupRect.bottom, lessThanOrEqualTo(screen.height));

    await SuperOverlay.dismiss(status: DismissStatus.allAttach);
    await tester.pumpAndSettle();
  });

  testWidgets('popup highlight creates a transparent target area', (
    tester,
  ) async {
    var targetClicks = 0;

    await tester.pumpWidget(
      buildApp(
        Center(
          child: Builder(
            builder: (targetContext) {
              return ElevatedButton(
                onPressed: () {
                  targetClicks++;
                  if (targetClicks == 1) {
                    SuperOverlay.showPopup(
                      targetContext: targetContext,
                      builder: (_) => const Text('Highlighted Popup'),
                    ).withHighlight().fire<void>();
                  }
                },
                child: const Text('Highlight Target'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Highlight Target'));
    await tester.pumpAndSettle();
    expect(find.text('Highlighted Popup'), findsOneWidget);

    await tester.tap(find.text('Highlight Target'));
    await tester.pumpAndSettle();
    expect(targetClicks, 2);

    await SuperOverlay.dismiss(status: DismissStatus.allAttach);
    await tester.pumpAndSettle();
  });

  testWidgets('popup mask click dismisses only when enabled', (tester) async {
    late BuildContext targetContext;
    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) {
            targetContext = context;
            return const Text('mask target');
          },
        ),
      ),
    );

    SuperOverlay.showPopup(
      targetContext: targetContext,
      builder: (_) => const Text('Locked Popup'),
    ).withMask(dismissible: false).withTag('locked').fire<void>();
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(790, 590));
    await tester.pumpAndSettle();
    expect(find.text('Locked Popup'), findsOneWidget);

    await SuperOverlay.dismiss(status: DismissStatus.attach, tag: 'locked');
    await tester.pumpAndSettle();

    SuperOverlay.showPopup(
      targetContext: targetContext,
      builder: (_) => const Text('Dismissible Popup'),
    ).withMask(dismissible: true).fire<void>();
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(790, 590));
    await tester.pumpAndSettle();
    expect(find.text('Dismissible Popup'), findsNothing);
  });

  testWidgets(
    'attach dialogs participate in attach and dialog dismiss statuses',
    (tester) async {
      late BuildContext targetContext;
      await tester.pumpWidget(
        buildApp(
          Builder(
            builder: (context) {
              targetContext = context;
              return const Text('dismiss target');
            },
          ),
        ),
      );

      SuperOverlay.showPopup(
        targetContext: targetContext,
        builder: (_) => const Text('Attach One'),
      ).withTag('attach-one').fire<void>();
      await tester.pumpAndSettle();

      await SuperOverlay.dismiss(
        status: DismissStatus.attach,
        tag: 'attach-one',
      );
      await tester.pumpAndSettle();
      expect(find.text('Attach One'), findsNothing);

      SuperOverlay.showPopup(
        targetContext: targetContext,
        builder: (_) => const Text('Attach Two'),
      ).fire<void>();
      SuperOverlay.show(builder: (_) => const Text('Custom Two')).fire<void>();
      await tester.pumpAndSettle();

      await SuperOverlay.dismiss(status: DismissStatus.allDialog);
      await tester.pumpAndSettle();

      expect(find.text('Attach Two'), findsNothing);
      expect(find.text('Custom Two'), findsNothing);
    },
  );

  testWidgets('each notify type renders its default builder', (tester) async {
    await tester.pumpWidget(buildApp(const SizedBox.shrink()));

    for (final type in NotifyType.values) {
      final message = 'notify-${type.name}';
      SuperOverlay.showNotify(msg: message, type: type).fire<void>();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(message), findsOneWidget);

      await SuperOverlay.dismiss(status: DismissStatus.allNotify);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('notify auto-dismisses after display time', (tester) async {
    await tester.pumpWidget(buildApp(const SizedBox.shrink()));

    SuperOverlay.showNotify(
      msg: 'Auto Notify',
      type: NotifyType.success,
    ).withDisplayTime(const Duration(milliseconds: 300)).fire<void>();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Auto Notify'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('Auto Notify'), findsNothing);
  });

  testWidgets('notify dismiss statuses close the correct entries', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(const SizedBox.shrink()));

    SuperOverlay.showNotify(
      msg: 'Notify One',
      type: NotifyType.success,
    ).withTag('notify-one').fire<void>();
    SuperOverlay.showNotify(
      msg: 'Notify Two',
      type: NotifyType.warning,
    ).withTag('notify-two').fire<void>();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await SuperOverlay.dismiss(status: DismissStatus.notify, tag: 'notify-one');
    await tester.pumpAndSettle();

    expect(find.text('Notify One'), findsNothing);
    expect(find.text('Notify Two'), findsOneWidget);

    await SuperOverlay.dismiss(status: DismissStatus.allNotify);
    await tester.pumpAndSettle();
    expect(find.text('Notify Two'), findsNothing);
  });

  testWidgets(
    'auto dismiss closes notify before dialog when loading is absent',
    (tester) async {
      await tester.pumpWidget(buildApp(const SizedBox.shrink()));

      SuperOverlay.show(builder: (_) => const Text('Auto Custom')).fire<void>();
      SuperOverlay.showNotify(
        msg: 'Auto Notify',
        type: NotifyType.alert,
      ).fire<void>();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await SuperOverlay.dismiss(status: DismissStatus.auto);
      await tester.pumpAndSettle();

      expect(find.text('Auto Notify'), findsNothing);
      expect(find.text('Auto Custom'), findsOneWidget);

      await SuperOverlay.dismiss(status: DismissStatus.allDialog);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('popping a route removes bindPage dialogs from that route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlayInit.init(),
        navigatorObservers: [SuperOverlayInit.observer],
        home: Scaffold(
          body: Builder(
            builder: (homeContext) {
              return ElevatedButton(
                onPressed: () {
                  Navigator.of(homeContext).push<void>(
                    MaterialPageRoute<void>(
                      builder: (routeContext) {
                        return Scaffold(
                          body: Column(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  SuperOverlay.show(
                                    builder: (_) =>
                                        const Text('Route Bound Dialog'),
                                  ).withTag('route-bound').fire<void>();
                                },
                                child: const Text('Show Route Dialog'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(routeContext).pop();
                                },
                                child: const Text('Pop Route'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
                child: const Text('Open Route'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Route'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Route Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Route Bound Dialog'), findsOneWidget);
    expect(SuperOverlay.checkExist(tag: 'route-bound'), isTrue);

    Navigator.of(tester.element(find.text('Show Route Dialog'))).pop();
    await tester.pumpAndSettle();

    expect(find.text('Route Bound Dialog'), findsNothing);
    expect(SuperOverlay.checkExist(tag: 'route-bound'), isFalse);
  });

  testWidgets('pushing a new route hides bound dialogs and pop shows them', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlayInit.init(),
        navigatorObservers: [SuperOverlayInit.observer],
        home: Scaffold(
          body: Builder(
            builder: (homeContext) {
              return Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      SuperOverlay.show(
                        builder: (_) => const Text('Home Bound Dialog'),
                      ).withTag('home-bound').fire<void>();
                    },
                    child: const Text('Show Home Dialog'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(homeContext).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const Scaffold(
                            body: Center(child: Text('Second Route')),
                          ),
                        ),
                      );
                    },
                    child: const Text('Push Route'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Home Dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Home Bound Dialog'), findsOneWidget);

    Navigator.of(tester.element(find.text('Show Home Dialog'))).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            const Scaffold(body: Center(child: Text('Second Route'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Second Route'), findsOneWidget);
    expect(find.text('Home Bound Dialog'), findsNothing);
    expect(SuperOverlay.checkExist(tag: 'home-bound'), isTrue);

    Navigator.of(tester.element(find.text('Second Route'))).pop();
    await tester.pumpAndSettle();

    expect(find.text('Home Bound Dialog'), findsOneWidget);
    await SuperOverlay.dismiss(tag: 'home-bound');
    await tester.pumpAndSettle();
  });

  testWidgets('BackType.normal dismisses overlay and blocks page pop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlayInit.init(),
        navigatorObservers: [SuperOverlayInit.observer],
        home: const Scaffold(body: Text('First Page')),
        routes: {
          '/second': (_) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                SuperOverlay.show(
                  builder: (_) => const Text('Back Normal Dialog'),
                ).withBack(type: BackType.normal).fire<void>();
              },
              child: const Text('Show Back Normal'),
            ),
          ),
        },
      ),
    );

    Navigator.of(tester.element(find.text('First Page'))).pushNamed('/second');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Back Normal'));
    await tester.pumpAndSettle();

    final handled = await dispatchSystemBack(tester);

    expect(handled, isTrue);
    expect(find.text('Back Normal Dialog'), findsNothing);
    expect(find.text('Show Back Normal'), findsOneWidget);
  });

  testWidgets('BackType.block blocks overlay dismiss and page pop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlayInit.init(),
        navigatorObservers: [SuperOverlayInit.observer],
        home: const Scaffold(body: Text('First Page')),
        routes: {
          '/second': (_) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                SuperOverlay.show(
                  builder: (_) => const Text('Back Block Dialog'),
                ).withBack(type: BackType.block).fire<void>();
              },
              child: const Text('Show Back Block'),
            ),
          ),
        },
      ),
    );

    Navigator.of(tester.element(find.text('First Page'))).pushNamed('/second');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Back Block'));
    await tester.pumpAndSettle();

    final handled = await dispatchSystemBack(tester);

    expect(handled, isTrue);
    expect(find.text('Back Block Dialog'), findsOneWidget);
    expect(find.text('Show Back Block'), findsOneWidget);

    await SuperOverlay.dismiss(status: DismissStatus.allDialog, force: true);
    await tester.pumpAndSettle();
  });

  testWidgets('BackType.ignore lets page pop proceed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlayInit.init(),
        navigatorObservers: [SuperOverlayInit.observer],
        home: const Scaffold(body: Text('First Page')),
        routes: {
          '/second': (_) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                SuperOverlay.show(
                  builder: (_) => const Text('Back Ignore Dialog'),
                ).withBack(type: BackType.ignore).fire<void>();
              },
              child: const Text('Show Back Ignore'),
            ),
          ),
        },
      ),
    );

    Navigator.of(tester.element(find.text('First Page'))).pushNamed('/second');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Back Ignore'));
    await tester.pumpAndSettle();

    final handled = await dispatchSystemBack(tester);

    expect(handled, isTrue);
    expect(find.text('First Page'), findsOneWidget);
    expect(find.text('Back Ignore Dialog'), findsNothing);
  });

  testWidgets('onBack returning true intercepts the event', (tester) async {
    var backCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlayInit.init(),
        navigatorObservers: [SuperOverlayInit.observer],
        home: const Scaffold(body: Text('First Page')),
        routes: {
          '/second': (_) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                SuperOverlay.show(
                      builder: (_) => const Text('Back Callback Dialog'),
                    )
                    .withBack(
                      type: BackType.normal,
                      onBack: () {
                        backCalls++;
                        return true;
                      },
                    )
                    .fire<void>();
              },
              child: const Text('Show Back Callback'),
            ),
          ),
        },
      ),
    );

    Navigator.of(tester.element(find.text('First Page'))).pushNamed('/second');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Back Callback'));
    await tester.pumpAndSettle();

    final handled = await dispatchSystemBack(tester);

    expect(handled, isTrue);
    expect(backCalls, 1);
    expect(find.text('Back Callback Dialog'), findsOneWidget);
    expect(find.text('Show Back Callback'), findsOneWidget);

    await SuperOverlay.dismiss(status: DismissStatus.allDialog, force: true);
    await tester.pumpAndSettle();
  });

  testWidgets('loading back handling dismisses loading before page pop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlayInit.init(),
        navigatorObservers: [SuperOverlayInit.observer],
        home: const Scaffold(body: Text('First Page')),
        routes: {
          '/second': (_) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                SuperOverlay.showLoading(
                  msg: 'Back Loading',
                ).withBack(type: BackType.normal).fire<void>();
              },
              child: const Text('Show Back Loading'),
            ),
          ),
        },
      ),
    );

    Navigator.of(tester.element(find.text('First Page'))).pushNamed('/second');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Back Loading'));
    await tester.pump(const Duration(milliseconds: 250));

    final handled = await dispatchSystemBack(tester);

    expect(handled, isTrue);
    expect(find.text('Back Loading'), findsNothing);
    expect(find.text('Show Back Loading'), findsOneWidget);
  });

  testWidgets('notify back handling dismisses notify before page pop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlayInit.init(),
        navigatorObservers: [SuperOverlayInit.observer],
        home: const Scaffold(body: Text('First Page')),
        routes: {
          '/second': (_) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                SuperOverlay.showNotify(
                      msg: 'Back Notify',
                      type: NotifyType.alert,
                    )
                    .withDisplayTime(const Duration(seconds: 1))
                    .withBack(type: BackType.normal)
                    .fire<void>();
              },
              child: const Text('Show Back Notify'),
            ),
          ),
        },
      ),
    );

    Navigator.of(tester.element(find.text('First Page'))).pushNamed('/second');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Back Notify'));
    await tester.pump(const Duration(milliseconds: 100));

    final handled = await dispatchSystemBack(tester);

    expect(handled, isTrue);
    expect(find.text('Back Notify'), findsNothing);
    expect(find.text('Show Back Notify'), findsOneWidget);
  });

  testWidgets('bindWidget overlay hides when its widget unmounts', (
    tester,
  ) async {
    var showTarget = true;
    StateSetter? setHostState;

    await tester.pumpWidget(
      buildApp(
        StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return Column(
              children: [
                if (showTarget)
                  Builder(
                    builder: (targetContext) {
                      return ElevatedButton(
                        onPressed: () {
                          SuperOverlay.show(
                                builder: (_) =>
                                    const Text('Widget Bound Dialog'),
                              )
                              .withTag('widget-bound')
                              .bindWidget(targetContext)
                              .fire<void>();
                        },
                        child: const Text('Show Widget Dialog'),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Show Widget Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Widget Bound Dialog'), findsOneWidget);

    setHostState!(() {
      showTarget = false;
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('Widget Bound Dialog'), findsNothing);
    expect(SuperOverlay.checkExist(tag: 'widget-bound'), isFalse);
  });
}
