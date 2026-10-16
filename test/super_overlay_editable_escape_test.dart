import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

class _EditableHarness {
  final integration = SuperOverlay.integration();
  final focus = FocusNode();
  var applicationDismissals = 0;

  Future<void> mount(
    WidgetTester tester, {
    required bool applicationAction,
  }) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      integration.dispose();
      focus.dispose();
    });
    Widget app = MaterialApp(
      builder: integration.builder,
      navigatorObservers: [integration.observer],
      home: const Scaffold(body: Text('base page')),
    );
    if (applicationAction) {
      app = Actions(
        actions: <Type, Action<Intent>>{
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              applicationDismissals++;
              return null;
            },
          ),
        },
        child: app,
      );
    }
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  OverlayHandle<void> show(String surface, OverlayBackBehavior behavior) {
    Widget content(BuildContext context) =>
        SizedBox(width: 240, child: TextField(focusNode: focus));
    return switch (surface) {
      'popup' => SuperOverlay.popup.show<void>(
        builder: (context, _) => content(context),
        options: OverlayPopupOptions(
          targetPointBuilder: (_, _) => const Offset(240, 180),
          backBehavior: behavior,
          requestFocus: true,
        ),
      ),
      'loading' => SuperOverlay.loading.show(
        builder: content,
        options: OverlayLoadingOptions(backBehavior: behavior),
      ),
      _ => SuperOverlay.dialog.show<void>(
        builder: (context, _) => content(context),
        options: OverlayDialogOptions(backBehavior: behavior),
      ),
    };
  }

  Future<void> focusField(WidgetTester tester) async {
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  }
}

void main() {
  for (final surface in ['dialog', 'popup', 'loading']) {
    for (final behavior in OverlayBackBehavior.values) {
      testWidgets(
        '$surface TextField Escape hides selection toolbar before ${behavior.name}',
        (tester) async {
          final harness = _EditableHarness();
          await harness.mount(tester, applicationAction: true);
          final handle = harness.show(surface, behavior);
          await harness.focusField(tester);
          await tester.enterText(find.byType(TextField), 'selection text');
          final field = tester.state<EditableTextState>(
            find.byType(EditableText),
          );
          field.widget.controller.selection = const TextSelection(
            baseOffset: 0,
            extentOffset: 9,
          );
          await tester.pumpAndSettle();
          expect(field.showToolbar(), isTrue);
          await tester.pumpAndSettle();
          expect(field.selectionOverlay!.toolbarIsVisible, isTrue);

          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(handle.isVisible, isTrue);
          expect(field.selectionOverlay!.toolbarIsVisible, isFalse);
          expect(harness.applicationDismissals, 0);
          expect(harness.focus.hasFocus, isTrue);

          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(handle.isVisible, behavior != OverlayBackBehavior.dismiss);
          expect(
            harness.applicationDismissals,
            behavior == OverlayBackBehavior.passThrough ? 1 : 0,
          );
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.macOS,
        }),
      );
    }
  }

  for (final surface in ['dialog', 'popup', 'loading']) {
    for (final applicationAction in [false, true]) {
      testWidgets(
        'passThrough $surface TextField forwards DismissIntent safely, application action=$applicationAction',
        (tester) async {
          final harness = _EditableHarness();
          await harness.mount(tester, applicationAction: applicationAction);
          final handle = harness.show(surface, OverlayBackBehavior.passThrough);
          await harness.focusField(tester);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(handle.isVisible, isTrue);
          expect(harness.applicationDismissals, applicationAction ? 1 : 0);
          expect(find.text('base page'), findsOneWidget);
        },
      );
    }
  }

  for (final behavior in [
    OverlayBackBehavior.dismiss,
    OverlayBackBehavior.block,
  ]) {
    testWidgets(
      'TextField Escape honors ${behavior.name} before application DismissIntent',
      (tester) async {
        final harness = _EditableHarness();
        await harness.mount(tester, applicationAction: true);
        final handle = harness.show('dialog', behavior);
        await harness.focusField(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(handle.isVisible, behavior == OverlayBackBehavior.block);
        expect(harness.applicationDismissals, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'passThrough TextField switches from lower consumer to application action after close',
    (tester) async {
      final harness = _EditableHarness();
      await harness.mount(tester, applicationAction: true);
      final lower = SuperOverlay.dialog.show<void>(
        builder: (_, _) => const Text('lower consumer'),
      );
      await tester.pumpAndSettle();
      final upper = harness.show('dialog', OverlayBackBehavior.passThrough);
      await harness.focusField(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(lower.isVisible, isFalse);
      expect(upper.isVisible, isTrue);
      expect(harness.applicationDismissals, 0);
      expect(harness.focus.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(upper.isVisible, isTrue);
      expect(harness.applicationDismissals, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
