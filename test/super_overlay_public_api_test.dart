import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

Widget _buildApp(Widget child) {
  return MaterialApp(
    builder: SuperOverlayInit.init(),
    navigatorObservers: [SuperOverlayInit.observer],
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

    SuperOverlay.show(
      builder: (_) => const Text('First'),
    ).withTag('first').fire<void>();
    SuperOverlay.show(
      builder: (_) => const Text('Second'),
    ).withTag('second').fire<void>();
    await tester.pump();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);

    await SuperOverlay.dismiss(status: DismissStatus.allDialog, force: true);
    await tester.pump();
  });

  testWidgets('dismiss waits for the configured close animation', (
    tester,
  ) async {
    SuperOverlay.config.custom = const CustomDialogConfig(
      animationTime: Duration(milliseconds: 200),
      nonAnimationTypes: [],
    );

    await tester.pumpWidget(_buildApp(const SizedBox.shrink()));

    SuperOverlay.show(
      builder: (_) => const Text('Animated'),
    ).withTag('animated').fire<void>();
    await tester.pumpAndSettle();

    var completed = false;
    final dismiss = SuperOverlay.dismiss(
      tag: 'animated',
    ).then((_) => completed = true);

    await tester.pump();
    expect(completed, isFalse);

    await tester.pump(const Duration(milliseconds: 100));
    expect(completed, isFalse);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await dismiss;

    expect(completed, isTrue);
    expect(find.text('Animated'), findsNothing);
  });
}
