import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

class _AccessibilityHarness {
  const _AccessibilityHarness({
    required this.integration,
    required this.pageFocus,
    required this.targetContext,
  });

  final SuperOverlayIntegration integration;
  final FocusNode pageFocus;
  final BuildContext targetContext;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
    pageFocus.dispose();
  }
}

SemanticsNode? _semanticsNodeWithLabel(WidgetTester tester, String label) {
  // Flutter 3.29 does not yet expose rootPipelineOwner on the test binding.
  // ignore: deprecated_member_use
  final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (root == null) {
    return null;
  }
  SemanticsNode? match;

  bool visit(SemanticsNode node) {
    if (node.getSemanticsData().label == label) {
      match = node;
      return false;
    }
    node.visitChildren(visit);
    return match == null;
  }

  visit(root);
  return match;
}

bool _hasSemanticsFlag(SemanticsNode node, SemanticsFlag flag) {
  // Flutter 3.29 exposes only the bit-mask compatibility lookup.
  // ignore: deprecated_member_use
  return node.getSemanticsData().hasFlag(flag);
}

Future<_AccessibilityHarness> _pumpApp(
  WidgetTester tester, {
  VoidCallback? onPagePressed,
}) async {
  final integration = SuperOverlay.integration();
  final pageFocus = FocusNode(debugLabel: 'page control');
  late BuildContext targetContext;

  await tester.pumpWidget(
    MaterialApp(
      builder: integration.builder,
      navigatorObservers: <NavigatorObserver>[integration.observer],
      home: Scaffold(
        body: Builder(
          builder: (context) {
            targetContext = context;
            return Center(
              child: TextButton(
                focusNode: pageFocus,
                onPressed: onPagePressed ?? () {},
                child: const Text('Page control'),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  pageFocus.requestFocus();
  await tester.pump();

  return _AccessibilityHarness(
    integration: integration,
    pageFocus: pageFocus,
    targetContext: targetContext,
  );
}

Future<_AccessibilityHarness> _pumpAppWithRootEscape(
  WidgetTester tester,
  VoidCallback onEscape,
) async {
  final integration = SuperOverlay.integration();
  final pageFocus = FocusNode(debugLabel: 'page control');
  late BuildContext targetContext;
  final app = MaterialApp(
    builder: integration.builder,
    navigatorObservers: <NavigatorObserver>[integration.observer],
    home: Scaffold(
      body: Builder(
        builder: (context) {
          targetContext = context;
          return Center(
            child: TextButton(
              focusNode: pageFocus,
              onPressed: () {},
              child: const Text('Page control'),
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpWidget(
    CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): onEscape,
      },
      child: app,
    ),
  );
  await tester.pumpAndSettle();
  pageFocus.requestFocus();
  await tester.pump();
  return _AccessibilityHarness(
    integration: integration,
    pageFocus: pageFocus,
    targetContext: targetContext,
  );
}

void main() {
  testWidgets('modal dialog traps focus and restores the page focus', (
    tester,
  ) async {
    final harness = await _pumpApp(tester);
    final firstFocus = FocusNode(debugLabel: 'first dialog control');
    final secondFocus = FocusNode(debugLabel: 'second dialog control');
    final handle = SuperOverlay.dialog.show<void>(
      builder:
          (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextButton(
                focusNode: firstFocus,
                onPressed: () {},
                child: const Text('First dialog control'),
              ),
              TextButton(
                focusNode: secondFocus,
                onPressed: () {},
                child: const Text('Second dialog control'),
              ),
            ],
          ),
    );
    await tester.pumpAndSettle();

    expect(harness.pageFocus.hasFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(firstFocus.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(secondFocus.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(firstFocus.hasFocus, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(secondFocus.hasFocus, isTrue);

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;

    expect(harness.pageFocus.hasFocus, isTrue);

    firstFocus.dispose();
    secondFocus.dispose();
    await harness.dispose(tester);
  });

  testWidgets('non-modal dialog preserves newer page focus on close', (
    tester,
  ) async {
    final integration = SuperOverlay.integration();
    final firstPageFocus = FocusNode(debugLabel: 'first page control');
    final secondPageFocus = FocusNode(debugLabel: 'second page control');
    final dialogFocus = FocusNode(debugLabel: 'non-modal dialog control');

    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: <NavigatorObserver>[integration.observer],
        home: Scaffold(
          body: Column(
            children: <Widget>[
              TextButton(
                focusNode: firstPageFocus,
                onPressed: () {},
                child: const Text('First page control'),
              ),
              TextButton(
                focusNode: secondPageFocus,
                onPressed: () {},
                child: const Text('Second page control'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    firstPageFocus.requestFocus();
    await tester.pump();

    final handle = SuperOverlay.dialog.show<void>(
      builder:
          (_) => TextButton(
            focusNode: dialogFocus,
            onPressed: () {},
            child: const Text('Non-modal dialog control'),
          ),
      options: const OverlayDialogOptions(consumeEvents: false),
    );
    await tester.pumpAndSettle();
    dialogFocus.requestFocus();
    await tester.pump();
    secondPageFocus.requestFocus();
    await tester.pump();

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;

    expect(secondPageFocus.hasFocus, isTrue);
    expect(firstPageFocus.hasFocus, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
    firstPageFocus.dispose();
    secondPageFocus.dispose();
    dialogFocus.dispose();
  });

  testWidgets('non-modal dialog allows directional focus to exit', (
    tester,
  ) async {
    final integration = SuperOverlay.integration();
    final pageFocus = FocusNode(debugLabel: 'lower page control');
    final dialogFocus = FocusNode(debugLabel: 'upper non-modal control');

    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: <NavigatorObserver>[integration.observer],
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: TextButton(
              focusNode: pageFocus,
              onPressed: () {},
              child: const Text('Lower page control'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final handle = SuperOverlay.dialog.show<void>(
      builder:
          (_) => TextButton(
            focusNode: dialogFocus,
            onPressed: () {},
            child: const Text('Upper non-modal control'),
          ),
      options: const OverlayDialogOptions(
        alignment: Alignment.topCenter,
        consumeEvents: false,
      ),
    );
    await tester.pumpAndSettle();
    dialogFocus.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(pageFocus.hasFocus, isTrue);

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
    pageFocus.dispose();
    dialogFocus.dispose();
  });

  testWidgets('Escape uses the same dismiss behavior as system back', (
    tester,
  ) async {
    final harness = await _pumpApp(tester);
    final handle = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Escape dialog'),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await handle.closed;

    expect(find.text('Escape dialog'), findsNothing);
    expect(harness.pageFocus.hasFocus, isTrue);
    await harness.dispose(tester);
  });

  testWidgets('popup toast and notification do not steal page focus', (
    tester,
  ) async {
    final harness = await _pumpApp(tester);
    final popup = SuperOverlay.popup.show<void>(
      targetContext: harness.targetContext,
      builder: (_) => const Text('Non-modal popup'),
    );
    await tester.pumpAndSettle();

    expect(harness.pageFocus.hasFocus, isTrue);

    final toast = SuperOverlay.toast(
      'Live toast',
      options: const OverlayToastOptions(displayDuration: Duration(days: 1)),
    );
    final notify = SuperOverlay.notify.success(
      'Live notification',
      options: const OverlayNotifyOptions(displayDuration: null),
    );
    await tester.pumpAndSettle();

    expect(harness.pageFocus.hasFocus, isTrue);

    final closes = <Future<void>>[popup.close(), toast.close(), notify.close()];
    await tester.pumpAndSettle();
    await Future.wait(closes);
    await harness.dispose(tester);
  });

  testWidgets('loading captures focus and honors requestFocus false', (
    tester,
  ) async {
    final harness = await _pumpApp(tester);
    final loadingFocus = FocusNode(debugLabel: 'loading control');
    final loading = SuperOverlay.loading.show(
      builder:
          (_) => TextButton(
            focusNode: loadingFocus,
            onPressed: () {},
            child: const Text('Loading control'),
          ),
    );
    await tester.pumpAndSettle();

    expect(harness.pageFocus.hasFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(loadingFocus.hasFocus, isTrue);

    final closeLoading = loading.close();
    await tester.pumpAndSettle();
    await closeLoading;
    expect(harness.pageFocus.hasFocus, isTrue);

    final dialog = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Passive dialog'),
      options: const OverlayDialogOptions(requestFocus: false),
    );
    await tester.pumpAndSettle();
    expect(harness.pageFocus.hasFocus, isTrue);

    final closeDialog = dialog.close();
    await tester.pumpAndSettle();
    await closeDialog;
    loadingFocus.dispose();
    await harness.dispose(tester);
  });

  testWidgets('loading handoff without a frame restores page focus', (
    tester,
  ) async {
    final harness = await _pumpApp(tester);
    final first = SuperOverlay.loading.show(
      builder: (_) => const Text('First loading'),
    );
    await tester.pumpAndSettle();
    expect(harness.pageFocus.hasFocus, isFalse);

    await first.close();
    final second = SuperOverlay.loading.show(
      builder: (_) => const Text('Second loading'),
    );
    await tester.pumpAndSettle();

    final closeSecond = second.close();
    await tester.pumpAndSettle();
    await closeSecond;

    expect(harness.pageFocus.hasFocus, isTrue);
    await harness.dispose(tester);
  });

  testWidgets('loading handoff to requestFocus false restores page focus', (
    tester,
  ) async {
    final harness = await _pumpApp(tester);
    final first = SuperOverlay.loading.show(
      builder: (_) => const Text('Focused loading'),
    );
    await tester.pumpAndSettle();
    expect(harness.pageFocus.hasFocus, isFalse);

    await first.close();
    final second = SuperOverlay.loading.show(
      builder: (_) => const Text('Passive loading'),
      options: const OverlayLoadingOptions(requestFocus: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Passive loading'), findsOneWidget);
    expect(harness.pageFocus.hasFocus, isTrue);

    final closeSecond = second.close();
    await tester.pumpAndSettle();
    await closeSecond;
    await harness.dispose(tester);
  });

  testWidgets('closed loading does not reclaim newer page focus', (
    tester,
  ) async {
    final integration = SuperOverlay.integration();
    final firstPageFocus = FocusNode(debugLabel: 'first page control');
    final secondPageFocus = FocusNode(debugLabel: 'second page control');

    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: <NavigatorObserver>[integration.observer],
        home: Scaffold(
          body: Column(
            children: <Widget>[
              TextButton(
                focusNode: firstPageFocus,
                onPressed: () {},
                child: const Text('First page control'),
              ),
              TextButton(
                focusNode: secondPageFocus,
                onPressed: () {},
                child: const Text('Second page control'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    firstPageFocus.requestFocus();
    await tester.pump();

    final loading = SuperOverlay.loading.show(
      builder: (_) => const Text('Closing loading'),
    );
    await tester.pumpAndSettle();
    expect(firstPageFocus.hasFocus, isFalse);

    await loading.close();
    expect(firstPageFocus.hasFocus, isTrue);
    secondPageFocus.requestFocus();
    FocusManager.instance.applyFocusChangesIfNeeded();
    expect(secondPageFocus.hasFocus, isTrue);

    await tester.pump();
    expect(secondPageFocus.hasFocus, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
    firstPageFocus.dispose();
    secondPageFocus.dispose();
  });

  testWidgets('new loading presentation captures the current page focus', (
    tester,
  ) async {
    final integration = SuperOverlay.integration();
    final firstPageFocus = FocusNode(debugLabel: 'first page control');
    final secondPageFocus = FocusNode(debugLabel: 'second page control');

    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: <NavigatorObserver>[integration.observer],
        home: Scaffold(
          body: Column(
            children: <Widget>[
              TextButton(
                focusNode: firstPageFocus,
                onPressed: () {},
                child: const Text('First page control'),
              ),
              TextButton(
                focusNode: secondPageFocus,
                onPressed: () {},
                child: const Text('Second page control'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    firstPageFocus.requestFocus();
    await tester.pump();

    final first = SuperOverlay.loading.show(
      builder: (_) => const Text('First loading'),
    );
    await tester.pumpAndSettle();
    await first.close();
    expect(firstPageFocus.hasFocus, isTrue);

    secondPageFocus.requestFocus();
    FocusManager.instance.applyFocusChangesIfNeeded();
    expect(secondPageFocus.hasFocus, isTrue);

    final second = SuperOverlay.loading.show(
      builder: (_) => const Text('Second loading'),
    );
    await tester.pumpAndSettle();
    await second.close();

    expect(secondPageFocus.hasFocus, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
    firstPageFocus.dispose();
    secondPageFocus.dispose();
  });

  testWidgets('Escape honors block and passThrough policies', (tester) async {
    var rootEscapeCount = 0;
    final harness = await _pumpAppWithRootEscape(
      tester,
      () => rootEscapeCount++,
    );
    final blocked = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Blocked dialog'),
      options: const OverlayDialogOptions(
        backBehavior: OverlayBackBehavior.block,
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Blocked dialog'), findsOneWidget);
    expect(rootEscapeCount, 0);

    final closeBlocked = blocked.close();
    await tester.pumpAndSettle();
    await closeBlocked;

    final passThrough = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Pass-through dialog'),
      options: const OverlayDialogOptions(
        backBehavior: OverlayBackBehavior.passThrough,
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Pass-through dialog'), findsOneWidget);
    expect(rootEscapeCount, 1);

    final closePassThrough = passThrough.close();
    await tester.pumpAndSettle();
    await closePassThrough;
    await harness.dispose(tester);
  });

  testWidgets('popup handles Escape only while focus is inside it', (
    tester,
  ) async {
    var rootEscapeCount = 0;
    final harness = await _pumpAppWithRootEscape(
      tester,
      () => rootEscapeCount++,
    );
    final popupFocus = FocusNode(debugLabel: 'popup control');
    final popup = SuperOverlay.popup.show<void>(
      targetContext: harness.targetContext,
      builder:
          (_) => TextButton(
            focusNode: popupFocus,
            onPressed: () {},
            child: const Text('Popup control'),
          ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(rootEscapeCount, 1);
    expect(find.text('Popup control'), findsOneWidget);

    popupFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await popup.closed;

    expect(find.text('Popup control'), findsNothing);
    expect(rootEscapeCount, 1);
    expect(harness.pageFocus.hasFocus, isTrue);

    final requestedFocus = FocusNode(debugLabel: 'requested popup control');
    final requestedPopup = SuperOverlay.popup.show<void>(
      targetContext: harness.targetContext,
      builder:
          (_) => TextButton(
            focusNode: requestedFocus,
            onPressed: () {},
            child: const Text('Requested popup control'),
          ),
      options: const OverlayPopupOptions(requestFocus: true),
    );
    await tester.pumpAndSettle();
    expect(harness.pageFocus.hasFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(requestedFocus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(harness.pageFocus.hasFocus, isTrue);

    final closeRequestedPopup = requestedPopup.close();
    await tester.pumpAndSettle();
    await closeRequestedPopup;
    expect(harness.pageFocus.hasFocus, isTrue);

    popupFocus.dispose();
    requestedFocus.dispose();
    await harness.dispose(tester);
  });

  testWidgets('modal semantics block the page and expose the barrier', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final harness = await _pumpApp(tester);
    expect(_semanticsNodeWithLabel(tester, 'Page control'), isNotNull);

    final handle = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Semantic dialog content'),
      options: const OverlayDialogOptions(
        semanticsLabel: 'Account confirmation',
        barrierSemanticsLabel: 'Close account confirmation',
      ),
    );
    await tester.pumpAndSettle();

    expect(_semanticsNodeWithLabel(tester, 'Page control'), isNull);
    final routeNode = _semanticsNodeWithLabel(tester, 'Account confirmation')!;
    expect(_hasSemanticsFlag(routeNode, SemanticsFlag.scopesRoute), isTrue);
    final barrierNode =
        _semanticsNodeWithLabel(tester, 'Close account confirmation')!;
    expect(
      barrierNode.getSemanticsData().hasAction(SemanticsAction.dismiss),
      isTrue,
    );

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    expect(_semanticsNodeWithLabel(tester, 'Page control'), isNotNull);

    final localizedBarrierLabel =
        MaterialLocalizations.of(
          harness.targetContext,
        ).modalBarrierDismissLabel;
    final defaultBarrier = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Default barrier dialog'),
    );
    await tester.pumpAndSettle();
    final defaultBarrierNode =
        _semanticsNodeWithLabel(tester, localizedBarrierLabel)!;
    expect(
      defaultBarrierNode.getSemanticsData().hasAction(SemanticsAction.dismiss),
      isTrue,
    );
    final closeDefaultBarrier = defaultBarrier.close();
    await tester.pumpAndSettle();
    await closeDefaultBarrier;

    final loading = SuperOverlay.loading.show(
      builder: (_) => const Text('Semantic loading content'),
      options: const OverlayLoadingOptions(
        semanticsLabel: 'Blocking operation',
        barrierSemanticsLabel: 'Operation in progress',
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final loadingRouteNode =
        _semanticsNodeWithLabel(tester, 'Blocking operation')!;
    expect(
      _hasSemanticsFlag(loadingRouteNode, SemanticsFlag.scopesRoute),
      isTrue,
    );
    final loadingBarrierNode =
        _semanticsNodeWithLabel(tester, 'Operation in progress')!;
    expect(
      loadingBarrierNode.getSemanticsData().hasAction(SemanticsAction.dismiss),
      isFalse,
    );
    final closeLoading = loading.close();
    await tester.pumpAndSettle();
    await closeLoading;

    semantics.dispose();
    await harness.dispose(tester);
  });

  testWidgets('non-modal dialog preserves background semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var pagePressCount = 0;
    final harness = await _pumpApp(
      tester,
      onPagePressed: () => pagePressCount++,
    );

    final handle = SuperOverlay.dialog.show<void>(
      builder: (_) => const Text('Non-modal dialog content'),
      options: const OverlayDialogOptions(
        alignment: Alignment.topCenter,
        consumeEvents: false,
        semanticsLabel: 'Non-modal dialog',
      ),
    );
    await tester.pumpAndSettle();

    expect(_semanticsNodeWithLabel(tester, 'Page control'), isNotNull);
    final dialogNode = _semanticsNodeWithLabel(tester, 'Non-modal dialog')!;
    expect(_hasSemanticsFlag(dialogNode, SemanticsFlag.scopesRoute), isFalse);
    await tester.tap(find.text('Page control'));
    await tester.pump();
    expect(pagePressCount, 1);

    final close = handle.close();
    await tester.pumpAndSettle();
    await close;
    semantics.dispose();
    await harness.dispose(tester);
  });

  testWidgets('toast and notification semantics are live regions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final harness = await _pumpApp(tester);
    final toast = SuperOverlay.toast(
      'Accessible toast',
      options: const OverlayToastOptions(displayDuration: Duration(days: 1)),
    );
    final notify = SuperOverlay.notify.success(
      'Accessible notification',
      options: const OverlayNotifyOptions(displayDuration: null),
    );
    await tester.pumpAndSettle();

    final toastNode = _semanticsNodeWithLabel(tester, 'Accessible toast')!;
    final notifyNode =
        _semanticsNodeWithLabel(tester, 'Accessible notification')!;
    expect(_hasSemanticsFlag(toastNode, SemanticsFlag.isLiveRegion), isTrue);
    expect(_hasSemanticsFlag(notifyNode, SemanticsFlag.isLiveRegion), isTrue);

    final closes = <Future<void>>[toast.close(), notify.close()];
    await tester.pumpAndSettle();
    await Future.wait(closes);
    semantics.dispose();
    await harness.dispose(tester);
  });

  testWidgets('default feedback surfaces support RTL at text scale 2', (
    tester,
  ) async {
    final integration = SuperOverlay.integration();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: <NavigatorObserver>[integration.observer],
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: integration.builder(context, child),
            ),
          );
        },
        home: const Scaffold(body: Text('RTL page')),
      ),
    );
    await tester.pumpAndSettle();

    final loading = SuperOverlay.loading.show(message: 'Loading long text');
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    final closeLoading = loading.close();
    await tester.pumpAndSettle();
    await closeLoading;

    final toast = SuperOverlay.toast(
      'Toast long text',
      options: const OverlayToastOptions(displayDuration: Duration(days: 1)),
    );
    final notify = SuperOverlay.notify.success(
      'Notification long text',
      options: const OverlayNotifyOptions(displayDuration: null),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final closes = <Future<void>>[toast.close(), notify.close()];
    await tester.pumpAndSettle();
    await Future.wait(closes);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
  });

  testWidgets(
    'suspended scoped dialog releases focus semantics and back priority',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final integration = SuperOverlay.integration();
      final nestedObserver = integration.navigatorObserver();
      final navigatorKey = GlobalKey<NavigatorState>();
      final pageFocus = FocusNode(debugLabel: 'nested page control');
      final remountFocus = FocusNode(debugLabel: 'remount page control');
      final dialogFocus = FocusNode(debugLabel: 'scoped dialog control');
      final coveringFocus = FocusNode(debugLabel: 'covering page control');
      late BuildContext nestedContext;
      var rootEscapeCount = 0;

      await tester.pumpWidget(
        CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.escape):
                () => rootEscapeCount++,
          },
          child: MaterialApp(
            builder: integration.builder,
            navigatorObservers: <NavigatorObserver>[integration.observer],
            home: Scaffold(
              body: Navigator(
                key: navigatorKey,
                observers: <NavigatorObserver>[nestedObserver],
                onGenerateRoute:
                    (_) => MaterialPageRoute<void>(
                      builder:
                          (context) => Builder(
                            builder: (context) {
                              nestedContext = context;
                              return Scaffold(
                                body: Column(
                                  children: <Widget>[
                                    TextButton(
                                      focusNode: pageFocus,
                                      onPressed: () {},
                                      child: const Text('Nested page control'),
                                    ),
                                    TextButton(
                                      focusNode: remountFocus,
                                      onPressed: () {},
                                      child: const Text('Remount page control'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      pageFocus.requestFocus();
      await tester.pump();

      final dialog = SuperOverlay.of(nestedContext).dialog.show<void>(
        builder:
            (_) => TextButton(
              focusNode: dialogFocus,
              onPressed: () {},
              child: const Text('Scoped dialog control'),
            ),
        options: const OverlayDialogOptions(
          semanticsLabel: 'Scoped modal route',
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(dialogFocus.hasFocus, isTrue);
      expect(_semanticsNodeWithLabel(tester, 'Scoped modal route'), isNotNull);

      navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder:
              (_) => Scaffold(
                body: TextButton(
                  autofocus: true,
                  focusNode: coveringFocus,
                  onPressed: () {},
                  child: const Text('Nested covering page'),
                ),
              ),
        ),
      );
      await tester.pumpAndSettle();

      expect(dialog.isVisible, isFalse);
      expect(dialogFocus.hasFocus, isFalse);
      expect(coveringFocus.hasFocus, isTrue);
      expect(_semanticsNodeWithLabel(tester, 'Scoped modal route'), isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(rootEscapeCount, 1);
      expect(find.text('Nested covering page'), findsOneWidget);

      final handled = await navigatorKey.currentState!.maybePop();
      // Flutter versions differ on whether the outgoing route or restored page
      // owns focus while the overlay remounts. Keep that gap deterministic.
      remountFocus.requestFocus();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(handled, isTrue);
      expect(find.text('Nested covering page'), findsNothing);
      expect(dialog.isVisible, isTrue);
      expect(pageFocus.hasFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(dialogFocus.hasFocus, isTrue);

      final closeDialog = dialog.close();
      await tester.pumpAndSettle();
      await closeDialog;
      expect(pageFocus.hasFocus, isTrue);

      final loading = SuperOverlay.loading.show(
        builder: (_) => const Text('Root loading'),
      );
      await tester.pumpAndSettle();
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Another nested page')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Root loading'), findsOneWidget);
      expect(loading.isVisible, isTrue);

      final closeLoading = loading.close();
      await tester.pumpAndSettle();
      await closeLoading;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      nestedObserver.dispose();
      integration.dispose();
      pageFocus.dispose();
      remountFocus.dispose();
      dialogFocus.dispose();
      coveringFocus.dispose();
      semantics.dispose();
    },
  );
}
