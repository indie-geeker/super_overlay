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

    await tester.tapAt(const Offset(10, 10));
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
}
