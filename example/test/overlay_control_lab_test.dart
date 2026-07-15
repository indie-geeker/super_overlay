import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

// ignore: avoid_relative_lib_imports
import '../lib/main.dart';

Future<void> _openControlLab(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  final entry = find.text('Open Control Lab');
  await tester.ensureVisible(entry);
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('control lab explains strategies through one repeated action', (
    tester,
  ) async {
    await _openControlLab(tester);

    expect(find.text('Overlay Control Lab'), findsWidgets);
    expect(find.text('How should repeated triggers behave?'), findsOneWidget);
    expect(find.text('How do you control a visible Overlay?'), findsOneWidget);
    expect(find.text('Await Lifecycle'), findsOneWidget);
    expect(find.text('Show all notification types'), findsNothing);

    await tester.tap(find.text('Simulate Two Triggers'));
    await tester.pumpAndSettle();
    expect(find.text('Login Prompt #1'), findsOneWidget);
    expect(find.text('Login Prompt #2'), findsOneWidget);
    await SuperOverlay.close(
      target: OverlayCloseTarget.allDialogs,
      tag: 'control-lab-auth',
      force: true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep Existing'));
    await tester.tap(find.text('Simulate Two Triggers'));
    await tester.pumpAndSettle();
    expect(find.text('Login Prompt #1'), findsOneWidget);
    expect(find.text('Login Prompt #2'), findsNothing);
    await SuperOverlay.close(
      target: OverlayCloseTarget.allDialogs,
      tag: 'control-lab-auth',
      force: true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Replace Existing'));
    await tester.tap(find.text('Simulate Two Triggers'));
    await tester.pumpAndSettle();
    expect(find.text('Login Prompt #1'), findsNothing);
    expect(find.text('Login Prompt #2'), findsOneWidget);

    await SuperOverlay.close(
      target: OverlayCloseTarget.allDialogs,
      tag: 'control-lab-auth',
      force: true,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('upload handle refresh is scoped and preserves external toast', (
    tester,
  ) async {
    await _openControlLab(tester);

    final external = SuperOverlay.toast(
      'External Business Toast',
      options: const OverlayToastOptions(
        tag: 'external-owner',
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    );
    await tester.pump();

    final start = find.text('Start Upload');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pump();
    expect(find.text('Upload progress 0%'), findsOneWidget);
    expect(find.text('External Business Toast'), findsOneWidget);

    await tester.tap(find.text('Advance Progress'));
    await tester.pump();
    expect(find.text('Upload progress 35%'), findsOneWidget);
    expect(find.text('External Business Toast'), findsOneWidget);

    await tester.tap(find.text('Cancel Upload'));
    await tester.pumpAndSettle();
    expect(find.text('Upload progress 35%'), findsNothing);
    expect(find.text('External Business Toast'), findsOneWidget);

    await external.close();
    await tester.pumpAndSettle();
  });

  testWidgets('await timeline exposes visible and closed milestones', (
    tester,
  ) async {
    await _openControlLab(tester);

    final start = find.text('Start Await Demo');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(find.text('1. Handle created'), findsOneWidget);
    expect(find.text('2. First frame visible'), findsOneWidget);

    await tester.tap(find.text('Close Await Overlay'));
    await tester.pumpAndSettle();
    expect(find.text('3. Overlay close requested'), findsOneWidget);
    expect(
      find.text('4. Overlay closed; closed Future completed'),
      findsOneWidget,
    );
  });

  testWidgets('leaving control lab only closes overlays owned by that page', (
    tester,
  ) async {
    await _openControlLab(tester);

    final external = SuperOverlay.toast(
      'External Page Overlay',
      options: const OverlayToastOptions(
        tag: 'external-owner',
        displayPolicy: OverlayToastDisplayPolicy.stack,
        displayDuration: Duration(minutes: 1),
      ),
    );
    await tester.pump();

    final start = find.text('Start Upload');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pump();
    expect(find.text('Upload progress 0%'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Upload progress 0%'), findsNothing);
    expect(find.text('External Page Overlay'), findsOneWidget);
    expect(external.isVisible, isTrue);

    await external.close();
    await tester.pumpAndSettle();
  });
}
