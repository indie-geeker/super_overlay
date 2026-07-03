import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

Widget _buildCommandOverlayApp(Widget child) {
  return MaterialApp(
    builder: SuperOverlay.init(),
    navigatorObservers: [SuperOverlay.observer],
    home: child,
  );
}

void main() {
  testWidgets('toast command shows a message and returns a handle', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.toast('Saved');

    await tester.pump();
    await handle.visible;
    expect(find.text('Saved'), findsOneWidget);
    expect(handle.isVisible, isTrue);

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    expect(find.text('Saved'), findsNothing);
    expect(handle.isVisible, isFalse);
  });

  testWidgets('loading command can be shown and closed through its handle', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.loading.show(message: 'Syncing');

    await tester.pump();
    expect(find.text('Syncing'), findsOneWidget);
    expect(handle.isVisible, isTrue);

    final closed = expectLater(handle.closed, completes);
    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    await closed;
    expect(find.text('Syncing'), findsNothing);
    expect(handle.isVisible, isFalse);
  });

  testWidgets('dialog command exposes a closed future with the result', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.dialog.show<String>(
      builder: (_) => const Center(child: Text('Confirm changes')),
      options: const OverlayDialogOptions(tag: 'confirm-dialog'),
    );

    await tester.pump();
    expect(find.text('Confirm changes'), findsOneWidget);
    expect(handle.isVisible, isTrue);

    final closed = expectLater(handle.closed, completion('confirmed'));
    final close = handle.close('confirmed');
    await tester.pumpAndSettle();
    await close;
    await closed;
    expect(find.text('Confirm changes'), findsNothing);
    expect(handle.isVisible, isFalse);
  });

  testWidgets('popup command shows content from a target context', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildCommandOverlayApp(
        Center(
          child: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  SuperOverlay.popup.show<void>(
                    targetContext: context,
                    builder: (_) => const Text('Popup action'),
                  );
                },
                child: const Text('Open popup'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open popup'));
    await tester.pump();

    expect(find.text('Popup action'), findsOneWidget);
  });

  testWidgets('notify success command shows a success notification', (
    tester,
  ) async {
    await tester.pumpWidget(_buildCommandOverlayApp(const SizedBox.shrink()));

    final handle = SuperOverlay.notify.success('Saved');

    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);
    expect(handle.isVisible, isTrue);

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    expect(find.text('Saved'), findsNothing);
    expect(handle.isVisible, isFalse);
  });
}
