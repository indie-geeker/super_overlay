part of 'super_overlay_test.dart';

void registerFeedbackOverlayTests() {
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

  testWidgets('multi toast stacks entries without visual overlap', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(const SizedBox.shrink()));

    SuperOverlay.showToast('Stack One')
        .withDisplayType(ToastDisplayType.multi)
        .withAlignment(Alignment.topRight)
        .withDisplayTime(const Duration(seconds: 1))
        .fire<void>();
    SuperOverlay.showToast('Stack Two')
        .withDisplayType(ToastDisplayType.multi)
        .withAlignment(Alignment.topRight)
        .withDisplayTime(const Duration(seconds: 1))
        .fire<void>();
    SuperOverlay.showToast('Stack Three')
        .withDisplayType(ToastDisplayType.multi)
        .withAlignment(Alignment.topRight)
        .withDisplayTime(const Duration(seconds: 1))
        .fire<void>();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final firstTop = tester.getTopLeft(find.text('Stack One')).dy;
    final secondTop = tester.getTopLeft(find.text('Stack Two')).dy;
    final thirdTop = tester.getTopLeft(find.text('Stack Three')).dy;

    expect(secondTop, greaterThan(firstTop));
    expect(thirdTop, greaterThan(secondTop));

    await SuperOverlay.dismiss(status: DismissStatus.allToast);
    await tester.pumpAndSettle();
  });
}
