import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

void main() {
  for (final surface in ['dialog', 'popup', 'notification']) {
    testWidgets(
      '$surface remains operable during text, direction, window and inset changes',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 800);
        addTearDown(tester.view.reset);
        final settings = ValueNotifier(false);
        final integration = SuperOverlay.integration();
        late BuildContext target;
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [integration.observer],
            builder:
                (context, child) => ValueListenableBuilder<bool>(
                  valueListenable: settings,
                  builder:
                      (_, expanded, __) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(expanded ? 2 : 1),
                          viewInsets: EdgeInsets.only(
                            bottom: expanded ? 220 : 0,
                          ),
                        ),
                        child: Directionality(
                          textDirection:
                              expanded ? TextDirection.rtl : TextDirection.ltr,
                          child: integration.builder(context, child),
                        ),
                      ),
                ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Builder(
                    builder: (context) {
                      target = context;
                      return const SizedBox(width: 100, height: 40);
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        late final OverlayHandle<void> handle;
        Widget content(BuildContext _) => Material(
          child: SizedBox(
            width: 220,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Long content must stay readable when text and window settings change.',
                  key: ValueKey('dynamic-content'),
                ),
                TextButton(
                  key: const ValueKey('dynamic-close'),
                  onPressed: () => handle.close(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
        handle = switch (surface) {
          // Dialog content owns keyboard avoidance; AlertDialog handles the
          // changing viewInsets without changing the package's alignment API.
          'dialog' => SuperOverlay.dialog.show<void>(
            builder: (context, _) => AlertDialog(content: content(context)),
          ),
          'popup' => SuperOverlay.popup.show<void>(
            targetContext: target,
            builder: (context, _) => (content)(context),
          ),
          _ => SuperOverlay.notify.success(
            'dynamic',
            builder: content,
            options: const OverlayNotifyOptions(displayDuration: null),
          ),
        };
        await tester.pumpAndSettle();
        await handle.visible;
        settings.value = true;
        tester.view.physicalSize = const Size(600, 900);
        await tester.pumpAndSettle();
        final context = tester.element(
          find.byKey(const ValueKey('dynamic-content')),
        );
        expect(Directionality.of(context), TextDirection.rtl);
        expect(MediaQuery.textScalerOf(context).scale(10), 20);
        final rect = tester.getRect(
          find.byKey(const ValueKey('dynamic-close')),
        );
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(600));
        expect(rect.bottom, lessThanOrEqualTo(680));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('dynamic-close')));
        await tester.pumpAndSettle();
        await handle.closed;
        expect(handle.isVisible, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        integration.dispose();
        settings.dispose();
      },
    );
  }
}
