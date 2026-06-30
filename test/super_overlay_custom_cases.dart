import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

Widget buildCustomOverlayApp(Widget child) {
  return MaterialApp(
    builder: SuperOverlayInit.init(),
    navigatorObservers: [SuperOverlayInit.observer],
    home: Scaffold(body: child),
  );
}

void main() {
  registerCustomOverlayTests();
}

void registerCustomOverlayTests() {
  testWidgets('initializes with SuperOverlayInit builder', (tester) async {
    await tester.pumpWidget(buildCustomOverlayApp(const Text('home')));

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('custom overlay new API renders and dismisses by tag', (
    tester,
  ) async {
    Object? result;

    await tester.pumpWidget(
      buildCustomOverlayApp(
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
      buildCustomOverlayApp(
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
      buildCustomOverlayApp(
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
      buildCustomOverlayApp(
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
    await tester.pumpWidget(buildCustomOverlayApp(const SizedBox.shrink()));

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
      await tester.pumpWidget(buildCustomOverlayApp(const SizedBox.shrink()));

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

    await tester.pumpWidget(buildCustomOverlayApp(const SizedBox.shrink()));

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

  testWidgets('withAwait dismiss completes with dismiss result', (
    tester,
  ) async {
    Object? result;
    var completed = false;

    await tester.pumpWidget(buildCustomOverlayApp(const SizedBox.shrink()));

    final future =
        SuperOverlay.show(builder: (_) => const Text('Await Dismiss'))
            .withTag('await-dismiss')
            .withAwait(AwaitCompletion.dismiss)
            .fire<String>();
    future.then((value) {
      result = value;
      completed = true;
    });

    await tester.pumpAndSettle();
    expect(completed, isFalse);

    await SuperOverlay.dismiss(tag: 'await-dismiss', result: 'closed');
    await tester.pumpAndSettle();
    await future;

    expect(completed, isTrue);
    expect(result, 'closed');
  });

  testWidgets('withAwait appear completes after open animation', (
    tester,
  ) async {
    final originalCustom = SuperOverlay.config.custom;
    addTearDown(() => SuperOverlay.config.custom = originalCustom);
    SuperOverlay.config.custom = const CustomDialogConfig(
      animationTime: Duration(milliseconds: 200),
      nonAnimationTypes: [],
    );
    var completed = false;

    await tester.pumpWidget(buildCustomOverlayApp(const SizedBox.shrink()));

    final future = SuperOverlay.show(
      builder: (_) => const Text('Await Appear'),
    ).withTag('await-appear').withAwait(AwaitCompletion.appear).fire<void>();
    future.then((_) => completed = true);

    await tester.pump();
    expect(completed, isFalse);

    await tester.pump(const Duration(milliseconds: 100));
    expect(completed, isFalse);

    await tester.pump(const Duration(milliseconds: 101));
    await tester.pump();
    await future;
    expect(completed, isTrue);
    expect(find.text('Await Appear'), findsOneWidget);

    final dismiss = SuperOverlay.dismiss(tag: 'await-appear', force: true);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    await dismiss;
  });

  testWidgets('withAwait none completes after scheduling insertion', (
    tester,
  ) async {
    var completed = false;

    await tester.pumpWidget(buildCustomOverlayApp(const SizedBox.shrink()));

    final future = SuperOverlay.show(
      builder: (_) => const Text('Await None'),
    ).withTag('await-none').withAwait(AwaitCompletion.none).fire<void>();
    future.then((_) => completed = true);

    await tester.pump();
    await future;

    expect(completed, isTrue);
    expect(find.text('Await None'), findsOneWidget);

    await SuperOverlay.dismiss(tag: 'await-none', force: true);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'penetrating custom overlay lets underlying widgets receive taps',
    (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        buildCustomOverlayApp(
          Center(
            child: ElevatedButton(
              onPressed: () => taps++,
              child: const Text('Underlying Action'),
            ),
          ),
        ),
      );

      SuperOverlay.show(
            builder: (_) => const Align(
              alignment: Alignment.topCenter,
              child: Text('Passive Overlay'),
            ),
          )
          .withMask(color: Colors.transparent, dismissible: false)
          .withPenetrate()
          .withTag('passive')
          .fire<void>();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Underlying Action'));
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(find.text('Passive Overlay'), findsOneWidget);

      await SuperOverlay.dismiss(tag: 'passive', force: true);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('mask trigger fires at configured pointer phase', (tester) async {
    var maskCount = 0;

    await tester.pumpWidget(buildCustomOverlayApp(const SizedBox.shrink()));

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
