part of 'super_overlay_test.dart';

void registerWidgetBindingTests() {
  testWidgets('widget-bound dialog closes when its target unmounts', (
    tester,
  ) async {
    var showTarget = true;
    StateSetter? setHostState;
    late OverlayHandle<void> handle;

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
                          handle = SuperOverlay.dialog.show<void>(
                            builder: (_) => const Text('Widget Bound Dialog'),
                            options: OverlayDialogOptions(
                              tag: 'widget-bound',
                              bindToWidget: targetContext,
                            ),
                          );
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
    expect(handle.isVisible, isTrue);

    setHostState!(() {
      showTarget = false;
    });
    await tester.pump();
    await tester.pump();
    await handle.closed;

    expect(find.text('Widget Bound Dialog'), findsNothing);
    expect(SuperOverlay.checkExist(tag: 'widget-bound'), isFalse);
    expect(handle.isVisible, isFalse);
  });
}
