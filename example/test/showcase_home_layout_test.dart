import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/main.dart';

void main() {
  testWidgets('home is organized by scenarios and advanced links', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    for (final label in [
      'Common Scenarios',
      'Interaction Guidance',
      'Advanced Capabilities',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    for (final removed in [
      'Live Status',
      'Await Events',
      'Show all notification types',
      'Overlay modes',
      'Live log',
    ]) {
      expect(find.text(removed), findsNothing);
    }
    expect(find.byTooltip('Notify'), findsNothing);
  });
}
