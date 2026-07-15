import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/main.dart';

void main() {
  testWidgets('confirmation dialog reports bool through handle.closed', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.ensureVisible(find.text('Open Confirmation Dialog'));
    await tester.tap(find.text('Open Confirmation Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm this action?'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('handle.closed result: true'), findsOneWidget);
    expect(find.text('Confirm this action?'), findsNothing);

    await tester.tap(find.text('Open Confirmation Dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('handle.closed result: false'), findsOneWidget);
    expect(find.text('Confirm this action?'), findsNothing);
  });
}
