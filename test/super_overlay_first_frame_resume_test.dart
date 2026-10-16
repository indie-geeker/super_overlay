import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

void main() {
  for (final popup in [false, true]) {
    for (final closeWhileCovered in [false, true]) {
      testWidgets(
        '${popup ? 'popup' : 'dialog'} first-frame suspension ${closeWhileCovered ? 'rejects visible on close' : 'settles visible after resume'}',
        (tester) async {
          final integration = SuperOverlay.integration();
          final navigator = GlobalKey<NavigatorState>();
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            integration.dispose();
          });
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navigator,
              builder: integration.builder,
              navigatorObservers: [integration.observer],
              home: const Scaffold(body: Center(child: Text('base page'))),
            ),
          );
          Widget content(BuildContext context, OverlayHandle<void> overlay) =>
              const SizedBox(
                width: 160,
                height: 48,
                child: Text('retained content'),
              );
          final handle =
              popup
                  ? SuperOverlay.popup.show<void>(
                    targetContext: tester.element(find.text('base page')),
                    builder: content,
                  )
                  : SuperOverlay.dialog.show<void>(builder: content);
          var visibility = 'pending';
          Object? visibilityError;
          handle.visible.then<void>(
            (_) => visibility = 'visible',
            onError: (Object error, StackTrace _) {
              visibility = 'failed';
              visibilityError = error;
            },
          );
          // This callback precedes DialogScope's first rendered-frame callback.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            navigator.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('covering page')),
              ),
            );
          });
          await tester.pumpAndSettle();
          expect(handle.isVisible, isFalse);
          expect(visibility, 'pending');
          expect(find.text('retained content'), findsNothing);

          if (closeWhileCovered) {
            final closing = handle.close();
            await tester.pumpAndSettle();
            await closing;
            await handle.closed;
            expect(visibility, 'failed');
            expect(visibilityError, isA<StateError>());
          }
          navigator.currentState!.pop();
          // Resuming ownership must not settle visible before another frame.
          expect(visibility, closeWhileCovered ? 'failed' : 'pending');
          await tester.pumpAndSettle();
          expect(visibility, closeWhileCovered ? 'failed' : 'visible');
          expect(handle.isVisible, !closeWhileCovered);
          expect(
            find.text('retained content'),
            closeWhileCovered ? findsNothing : findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
