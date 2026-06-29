import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      builder: SuperOverlayInit.init(),
      navigatorObservers: [SuperOverlayInit.observer],
      home: Scaffold(body: child),
    );
  }

  testWidgets('initializes with SuperOverlayInit builder', (tester) async {
    await tester.pumpWidget(buildApp(const Text('home')));

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('custom overlay new API renders and dismisses by tag', (tester) async {
    Object? result;

    await tester.pumpWidget(
      buildApp(
        ElevatedButton(
          onPressed: () async {
            result = await SuperOverlay.show(
              builder: (_) => const Text('Dialog Content'),
            ).withTag('profile').withMask(dismissible: true).fire<String>();
          },
          child: const Text('Show'),
        ),
      ),
    );

    expect(find.text('Dialog Content'), findsNothing);

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(find.text('Dialog Content'), findsOneWidget);
    expect(SuperOverlay.checkExist(tag: 'profile'), isTrue);

    await SuperOverlay.dismiss(
      status: DismissStatus.auto,
      tag: 'profile',
      result: 'closed',
    );
    await tester.pumpAndSettle();

    expect(find.text('Dialog Content'), findsNothing);
    expect(SuperOverlay.checkExist(tag: 'profile'), isFalse);
    expect(result, 'closed');
  });

  testWidgets('mask click dismisses when enabled', (tester) async {
    await tester.pumpWidget(
      buildApp(
        ElevatedButton(
          onPressed: () {
            SuperOverlay.show(
              builder: (_) => const Text('Mask Dialog'),
            ).withMask(dismissible: true).fire<void>();
          },
          child: const Text('Show'),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(find.text('Mask Dialog'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Mask Dialog'), findsNothing);
  });

  testWidgets('loading, toast, popup, and notify call sites use new API', (tester) async {
    late BuildContext targetContext;

    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) {
            targetContext = context;
            return const Text('target');
          },
        ),
      ),
    );

    SuperOverlay.showLoading(msg: 'Loading...').fire<void>();
    SuperOverlay.showToast('Saved').fire<void>();
    SuperOverlay.showPopup(
      targetContext: targetContext,
      builder: (_) => const Text('Popup Menu'),
    ).fire<void>();
    SuperOverlay.showNotify(msg: 'Done', type: NotifyType.success).fire<void>();

    await tester.pump();
  });
}
