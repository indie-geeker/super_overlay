import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

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
    originalCustomConfig = SuperOverlay.config.custom;
  });

  tearDown(() {
    SuperOverlay.config.custom = originalCustomConfig;
  });

  test('exports public configuration types from the package entrypoint', () {
    SuperOverlay.config.custom = const CustomDialogConfig(useAnimation: false);

    expect(SuperOverlay.config.custom.useAnimation, isFalse);
    expect(const AttachDialogConfig().bindPage, isTrue);
    expect(const LoadingConfig().leastLoadingTime, Duration.zero);
    expect(
      const NotifyConfig().displayTime,
      const Duration(milliseconds: 2500),
    );
    expect(const ToastConfig().displayTime, const Duration(milliseconds: 2000));
    expect(const CustomDialogConfig().awaitCompletion, AwaitCompletion.dismiss);
    expect(const AttachDialogConfig().awaitCompletion, AwaitCompletion.dismiss);
    expect(const LoadingConfig().awaitCompletion, AwaitCompletion.dismiss);
    expect(const NotifyConfig().awaitCompletion, AwaitCompletion.dismiss);
    expect(const ToastConfig().awaitCompletion, AwaitCompletion.none);
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
    SuperOverlay.config.custom = const CustomDialogConfig(
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
    expect(SuperOverlay.checkExist(tag: 'first'), isTrue);
    expect(SuperOverlay.checkExist(tag: 'second'), isTrue);

    await first.close();
    await second.close();
    await tester.pumpAndSettle();
    await first.closed;
    await second.closed;
  });

  testWidgets('dismiss waits for the configured close animation', (
    tester,
  ) async {
    SuperOverlay.config.custom = const CustomDialogConfig(
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
