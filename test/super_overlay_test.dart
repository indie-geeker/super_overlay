import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:super_overlay/super_overlay.dart';

void main() {
  SuperOverlay.config.enableDebounce = false;

  Widget buildApp(Widget child) {
    return MaterialApp(
      navigatorKey: SuperOverlay.navigatorKey,
      home: Scaffold(
        body: child,
      ),
    );
  }

  testWidgets('SuperOverlay Dialog shows and dismisses', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              SuperOverlay.show(content: const Text('Dialog Content'))
                .withMask(dismissible: true)
                .fire();
            },
            child: const Text('Show'),
          );
        }),
      ),
    );

    expect(find.text('Dialog Content'), findsNothing);
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    expect(find.text('Dialog Content'), findsOneWidget);

    // Tap outside to dismiss
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Dialog Content'), findsNothing);
  });

  testWidgets('SuperOverlay Loading shows default spinner', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              SuperOverlay.showLoading().fire();
            },
            child: const Text('Show'),
          );
        }),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Show'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('SuperOverlay Toast shows and auto dismisses', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              SuperOverlay.showToast(msg: 'Hello Toast')
                .withDuration(const Duration(milliseconds: 500))
                .fire();
            },
            child: const Text('Show'),
          );
        }),
      ),
    );

    expect(find.text('Hello Toast'), findsNothing);
    await tester.tap(find.text('Show'));
    await tester.pump(const Duration(milliseconds: 300));
    // Toast should be visible
    expect(find.text('Hello Toast'), findsOneWidget);

    // Wait for auto dismiss
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Hello Toast'), findsNothing);
  });

  testWidgets('SuperOverlay Popup attaches to widget', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildApp(
        Builder(builder: (context) {
          return Center(
            child: ElevatedButton(
              onPressed: () {
                SuperOverlay.showPopup(
                  targetContext: context,
                  content: const Text('Popup Content'),
                ).fire();
              },
              child: const Text('Show Popup'),
            ),
          );
        }),
      ),
    );

    expect(find.text('Popup Content'), findsNothing);
    await tester.tap(find.text('Show Popup'));
    await tester.pumpAndSettle();
    expect(find.text('Popup Content'), findsOneWidget);
  });

  testWidgets('SuperOverlay Debounce prevents multiple dialogs', (WidgetTester tester) async {
    SuperOverlay.config.enableDebounce = true;
    SuperOverlay.config.debounceDuration = const Duration(milliseconds: 300);
    SuperOverlay.resetDebounceTimer();
    
    int buildCount = 0;
    
    await tester.pumpWidget(buildApp(Container()));
    
    // Fire programmatically to simulate rapid calls that might bypass UI barriers
    for (int i = 0; i < 3; i++) {
      SuperOverlay.show(content: Builder(builder: (_) {
        buildCount++;
        return Text('Dialog $buildCount');
      })).withDebounce(true).fire();
    }

    await tester.pumpAndSettle();

    expect(find.text('Dialog 1'), findsOneWidget);
    expect(find.text('Dialog 2'), findsNothing);
    
    // Cleanup global state for next tests
    SuperOverlay.config.enableDebounce = false;
  });

  testWidgets('SuperOverlay Tags allow programmatic dismissal', (WidgetTester tester) async {
    SuperOverlay.config.enableDebounce = false;
    await tester.pumpWidget(
      buildApp(
        Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () {
              SuperOverlay.show(content: const Text('Tagged Dialog'))
                .withTag('my-tag')
                .fire();
            },
            child: const Text('Show'),
          );
        }),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    expect(find.text('Tagged Dialog'), findsOneWidget);

    SuperOverlay.dismiss(tag: 'my-tag');
    await tester.pumpAndSettle();
    expect(find.text('Tagged Dialog'), findsNothing);
  });

  testWidgets('SuperOverlay Highlight allows click through', (WidgetTester tester) async {
    SuperOverlay.config.enableDebounce = false;
    int targetClicks = 0;
    await tester.pumpWidget(
      buildApp(
        Builder(builder: (context) {
          return Center(
            child: Builder(
              builder: (highlightContext) {
                return ElevatedButton(
                  onPressed: () {
                    targetClicks++;
                    if (targetClicks == 1) {
                      SuperOverlay.show(content: const Text('Tutorial'))
                        .withAlignment(Alignment.topCenter)
                        .withHighlight(highlightContext)
                        .fire();
                    }
                  },
                  child: const Text('Target'),
                );
              }
            ),
          );
        }),
      ),
    );

    await tester.tap(find.text('Target'));
    await tester.pumpAndSettle();
    expect(find.text('Tutorial'), findsOneWidget);
    expect(targetClicks, 1);

    await tester.tap(find.text('Target'));
    await tester.pumpAndSettle();
    
    expect(targetClicks, 2);
  });
}
