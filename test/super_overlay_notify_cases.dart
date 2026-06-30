part of 'super_overlay_test.dart';

void registerNotifyOverlayTests() {
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
}
