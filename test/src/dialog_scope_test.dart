import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/src/kit/overlay_controller.dart';
import 'package:super_overlay/src/widget/helper/dialog_scope.dart';

void main() {
  testWidgets('DialogScope rebinds refresh when controller changes', (
    tester,
  ) async {
    final firstController = SuperOverlayController();
    final secondController = SuperOverlayController();
    var activeController = firstController;
    var count = 0;
    StateSetter? setHostState;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return DialogScope(
              controller: activeController,
              builder: (_) => Text('Count $count'),
            );
          },
        ),
      ),
    );

    expect(find.text('Count 0'), findsOneWidget);

    count = 1;
    firstController.refresh();
    await tester.pump();

    expect(find.text('Count 0'), findsNothing);
    expect(find.text('Count 1'), findsOneWidget);

    setHostState!(() {
      activeController = secondController;
    });
    await tester.pump();

    count = 2;
    firstController.refresh();
    await tester.pump();

    expect(find.text('Count 1'), findsOneWidget);
    expect(find.text('Count 2'), findsNothing);

    secondController.refresh();
    await tester.pump();

    expect(find.text('Count 1'), findsNothing);
    expect(find.text('Count 2'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    secondController.refresh();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
