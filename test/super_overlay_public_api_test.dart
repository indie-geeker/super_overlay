import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

import 'overlay_test_support.dart';

Widget _buildApp(Widget child) {
  return MaterialApp(
    builder: SuperOverlay.init(),
    navigatorObservers: [SuperOverlay.observer],
    home: Scaffold(body: child),
  );
}

void main() {
  late CustomDialogConfig originalCustomConfig;

  setUp(() {
    originalCustomConfig = overlayConfig.custom;
  });

  tearDown(() {
    overlayConfig.custom = originalCustomConfig;
  });

  test('exports command policies from the package entrypoint', () {
    expect(OverlayCloseTarget.topMost, isA<OverlayCloseTarget>());
    expect(OverlaySurface.dialog, isA<OverlaySurface>());
    expect(OverlayPopupAlignmentMode.center, isA<OverlayPopupAlignmentMode>());
    expect(OverlayNotificationType.success, isA<OverlayNotificationType>());
    expect(SuperOverlay.close, isA<Function>());
  });

  test('exports init default builder types from the package entrypoint', () {
    SuperOverlayToastBuilder createToastBuilder() {
      Widget builder(String message) => Text('Toast $message');
      return builder;
    }

    SuperOverlayLoadingBuilder createLoadingBuilder() {
      Widget builder(String message) => Text('Loading $message');
      return builder;
    }

    final typedToastBuilder = createToastBuilder();
    final typedLoadingBuilder = createLoadingBuilder();
    final notifyStyle = NotifyStyle(
      successBuilder: (message) => Text('Success $message'),
    );

    expect(typedToastBuilder('Saved'), isA<Text>());
    expect(typedLoadingBuilder('Loading'), isA<Text>());
    expect(notifyStyle.successBuilder?.call('Done'), isA<Text>());
  });

  testWidgets('custom debounce uses the configured debounce duration', (
    tester,
  ) async {
    overlayConfig.custom = const CustomDialogConfig(
      debounce: true,
      debounceTime: Duration.zero,
      useAnimation: false,
    );

    await tester.pumpWidget(_buildApp(const SizedBox.shrink()));

    final first = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('First'),
      options: const OverlayDialogOptions(tag: 'first'),
    );
    final second = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Second'),
      options: const OverlayDialogOptions(tag: 'second'),
    );
    await tester.pump();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(first.isVisible, isTrue);
    expect(second.isVisible, isTrue);
    expect(SuperOverlay.exists(tag: 'first'), isTrue);
    expect(SuperOverlay.exists(tag: 'second'), isTrue);

    await first.close();
    await second.close();
    await tester.pumpAndSettle();
    await first.closed;
    await second.closed;
  });

  testWidgets('dismiss waits for the configured close animation', (
    tester,
  ) async {
    overlayConfig.custom = const CustomDialogConfig(
      animationTime: Duration(milliseconds: 200),
      nonAnimationTypes: [],
    );

    await tester.pumpWidget(_buildApp(const SizedBox.shrink()));

    final handle = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Animated'),
      options: const OverlayDialogOptions(tag: 'animated'),
    );
    await tester.pumpAndSettle();

    expect(handle.isVisible, isTrue);

    var completed = false;
    final close = handle.close().then((_) => completed = true);

    await tester.pump();
    expect(completed, isFalse);

    await tester.pump(const Duration(milliseconds: 100));
    expect(completed, isFalse);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await close;
    await handle.closed;

    expect(completed, isTrue);
    expect(find.text('Animated'), findsNothing);
    expect(handle.isVisible, isFalse);
  });
}
