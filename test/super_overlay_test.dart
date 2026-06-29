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
}
