import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/main.dart';

void main() {
  testWidgets('home is organized by scenarios and advanced links', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    for (final label in ['常用场景', '交互增强', '高级能力']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final removed in [
      'Live Status',
      'Await 事件',
      'Show all notification types',
      'Overlay modes',
      'Live log',
    ]) {
      expect(find.text(removed), findsNothing);
    }
    expect(find.byTooltip('Notify'), findsNothing);
  });
}
