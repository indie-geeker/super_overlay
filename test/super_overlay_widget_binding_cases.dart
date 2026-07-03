part of 'super_overlay_test.dart';

void registerWidgetBindingTests() {
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
                                builder:
                                    (_) => const Text('Widget Bound Dialog'),
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
