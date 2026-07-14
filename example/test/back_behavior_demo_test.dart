import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

// ignore: avoid_relative_lib_imports
import '../lib/main.dart';

void main() {
  testWidgets('back demo makes dismiss block and passThrough observable', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.ensureVisible(find.text('打开生命周期案例'));
    await tester.tap(find.text('打开生命周期案例'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('OverlayBackBehavior.dismiss'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('OverlayBackBehavior.dismiss'), findsNothing);
    expect(find.text('Lifecycle Binding'), findsWidgets);

    await tester.tap(find.text('Back block'));
    await tester.pumpAndSettle();
    expect(find.text('OverlayBackBehavior.block'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('OverlayBackBehavior.block'), findsOneWidget);
    expect(find.text('Lifecycle Binding'), findsWidgets);
    await SuperOverlay.close(
      target: OverlayCloseTarget.dialog,
      tag: 'back-block',
      force: true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back passThrough'));
    await tester.pumpAndSettle();
    expect(find.text('OverlayBackBehavior.passThrough'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Lifecycle Binding'), findsNothing);
    expect(find.text('SuperOverlay Showcase'), findsOneWidget);
    expect(find.text('OverlayBackBehavior.passThrough'), findsNothing);
  });
}
