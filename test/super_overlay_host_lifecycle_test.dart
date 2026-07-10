import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

Widget _buildHost({SuperOverlayToastBuilder? toastBuilder}) {
  return MaterialApp(
    builder: SuperOverlay.init(toastBuilder: toastBuilder),
    navigatorObservers: [SuperOverlay.observer],
    home: const Scaffold(body: SizedBox.shrink()),
  );
}

void main() {
  testWidgets('removing an init builder restores the default renderer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildHost(
        toastBuilder: (message) => Text('Custom host toast: $message'),
      ),
    );

    final custom = SuperOverlay.toast(
      'first',
      options: const OverlayToastOptions(displayDuration: Duration(minutes: 1)),
    );
    await tester.pump();
    expect(find.text('Custom host toast: first'), findsOneWidget);
    final customClose = custom.close();
    await tester.pumpAndSettle();
    await customClose;

    await tester.pumpWidget(_buildHost());

    final restored = SuperOverlay.toast(
      'restored default',
      options: const OverlayToastOptions(displayDuration: Duration(minutes: 1)),
    );
    await tester.pump();
    expect(find.text('Custom host toast: restored default'), findsNothing);
    expect(find.text('restored default'), findsOneWidget);
    final restoredClose = restored.close();
    await tester.pumpAndSettle();
    await restoredClose;
  });

  testWidgets('disposing the host settles every active command handle', (
    tester,
  ) async {
    late BuildContext targetContext;
    await tester.pumpWidget(
      MaterialApp(
        builder: SuperOverlay.init(),
        navigatorObservers: [SuperOverlay.observer],
        home: Scaffold(
          body: Builder(
            builder: (context) {
              targetContext = context;
              return const SizedBox(width: 80, height: 40);
            },
          ),
        ),
      ),
    );

    final handles = <OverlayHandle<void>>[
      SuperOverlay.dialog.show<void>(builder: (_) => const Text('Host dialog')),
      SuperOverlay.loading.show(message: 'Host loading'),
      SuperOverlay.popup.show<void>(
        targetContext: targetContext,
        builder: (_) => const Text('Host popup'),
      ),
      SuperOverlay.notify.success(
        'Host notification',
        options: const OverlayNotifyOptions(displayDuration: null),
      ),
      SuperOverlay.toast(
        'Host toast',
        options: const OverlayToastOptions(
          displayPolicy: OverlayToastDisplayPolicy.stack,
          displayDuration: Duration(minutes: 1),
        ),
      ),
    ];
    await tester.pump();
    await Future.wait(handles.map((handle) => handle.visible));

    final closed = List<bool>.filled(handles.length, false);
    for (var index = 0; index < handles.length; index++) {
      handles[index].closed.then((_) => closed[index] = true);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.idle();

    expect(closed, everyElement(isTrue));
    expect(handles.map((handle) => handle.isVisible), everyElement(isFalse));
    expect(SuperOverlay.exists(), isFalse);
  });
}
