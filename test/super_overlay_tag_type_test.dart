import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

Widget _buildOverlayApp() {
  return MaterialApp(
    builder: SuperOverlay.init(),
    navigatorObservers: [SuperOverlay.observer],
    home: const Scaffold(body: SizedBox.shrink()),
  );
}

void main() {
  testWidgets('keepExisting rejects an incompatible tagged result type', (
    tester,
  ) async {
    await tester.pumpWidget(_buildOverlayApp());

    final first = SuperOverlay.dialog.show<String>(
      builder: (_) => const Text('Typed tag dialog'),
      options: const OverlayDialogOptions(tag: 'typed-tag'),
    );

    expect(
      () => SuperOverlay.dialog.show<int>(
        builder: (_) => const Text('Wrong typed dialog'),
        options: const OverlayDialogOptions(
          tag: 'typed-tag',
          strategy: OverlayStrategy.keepExisting,
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('typed-tag'),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Typed tag dialog'), findsOneWidget);
    expect(find.text('Wrong typed dialog'), findsNothing);

    final close = first.close('done');
    await tester.pumpAndSettle();
    await close;
    await expectLater(first.closed, completion('done'));
  });
}
