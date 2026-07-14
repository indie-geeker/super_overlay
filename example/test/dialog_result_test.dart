import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/main.dart';

void main() {
  testWidgets('confirmation dialog reports bool through handle.closed', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.ensureVisible(find.text('打开确认弹窗'));
    await tester.tap(find.text('打开确认弹窗'));
    await tester.pumpAndSettle();

    expect(find.text('确认本次操作？'), findsOneWidget);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(find.text('handle.closed 返回结果：true'), findsOneWidget);
    expect(find.text('确认本次操作？'), findsNothing);

    await tester.tap(find.text('打开确认弹窗'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('handle.closed 返回结果：false'), findsOneWidget);
    expect(find.text('确认本次操作？'), findsNothing);
  });
}
