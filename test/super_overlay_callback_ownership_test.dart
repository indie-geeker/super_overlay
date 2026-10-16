import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';
import 'package:super_overlay/src/config/enum_config.dart'
    show PopupAlignmentMode;
import 'package:super_overlay/src/data/show_param.dart';
import 'package:super_overlay/src/helper/overlay_manager.dart';
import 'package:super_overlay/src/widget/helper/mask_event.dart';

import 'overlay_test_support.dart';
import 'support/vm_heap.dart';

Future<void> _mount(WidgetTester tester) async {
  final integration = SuperOverlay.integration();
  final loading = overlayConfig.loading;
  final custom = overlayConfig.custom;
  final attach = overlayConfig.attach;
  final notify = overlayConfig.notify;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
    overlayConfig.loading = loading;
    overlayConfig.custom = custom;
    overlayConfig.attach = attach;
    overlayConfig.notify = notify;
  });
  await tester.pumpWidget(
    MaterialApp(
      builder: integration.builder,
      navigatorObservers: [integration.observer],
      home: const Scaffold(),
    ),
  );
}

String _identity(OverlaySurface surface) {
  final kind = surface == OverlaySurface.notification ? 'notify' : surface.name;
  for (var i = 0; i < 100000; i++) {
    final tag = '_super_overlay_command_${kind}_$i';
    if (SuperOverlay.exists(tag: tag, surfaces: {surface})) return tag;
  }
  throw StateError('Missing $surface command identity');
}

OverlayHandle<void> _show(
  OverlaySurface surface,
  String label, {
  String? tag,
  bool mask = false,
  OverlayBackBehavior back = OverlayBackBehavior.block,
}) {
  final child = SizedBox(width: 40, height: 40, child: Text(label));
  return switch (surface) {
    OverlaySurface.loading => SuperOverlay.loading.show(
      builder: (_) => child,
      options: OverlayLoadingOptions(
        tag: tag,
        dismissOnMaskTap: mask,
        backBehavior: back,
      ),
    ),
    OverlaySurface.dialog => SuperOverlay.dialog.show<void>(
      builder: (_, _) => child,
      options: OverlayDialogOptions(tag: tag, dismissOnMaskTap: mask),
    ),
    OverlaySurface.popup => SuperOverlay.popup.show<void>(
      builder: (_, _) => child,
      options: OverlayPopupOptions(
        tag: tag,
        dismissOnMaskTap: mask,
        targetPointBuilder: (_, _) => const Offset(400, 300),
      ),
    ),
    OverlaySurface.notification => () {
      overlayConfig.notify = NotifyConfig(
        clickMaskDismiss: mask,
        usePenetrate: false,
      );
      return SuperOverlay.notify.alert(
        label,
        builder: (_) => child,
        options: OverlayNotifyOptions(tag: tag, displayDuration: null),
      );
    }(),
    _ => throw ArgumentError.value(surface),
  };
}

Future<void> _close(WidgetTester tester, OverlayHandle<void> handle) async {
  final closing = handle.close();
  await tester.pumpAndSettle();
  await closing;
}

class _CallbackPayload {
  final bytes = List<int>.filled(4096, 1);
}

OverlayHandle<void> _showPayload(
  OverlaySurface surface,
  List<WeakReference<_CallbackPayload>> references,
) {
  final payload = _CallbackPayload();
  references.add(WeakReference(payload));
  if (surface == OverlaySurface.notification) {
    overlayConfig.notify = const NotifyConfig(usePenetrate: false);
  }
  Widget builder(BuildContext context) => Text('${payload.bytes.length}');
  return switch (surface) {
    OverlaySurface.loading => SuperOverlay.loading.show(builder: builder),
    OverlaySurface.dialog => SuperOverlay.dialog.show<void>(
      builder: (context, _) => builder(context),
    ),
    OverlaySurface.popup => SuperOverlay.popup.show<void>(
      builder: (context, _) => builder(context),
      options: OverlayPopupOptions(
        targetPointBuilder: (_, _) => const Offset(400, 300),
      ),
    ),
    OverlaySurface.notification => SuperOverlay.notify.alert(
      'payload',
      builder: builder,
    ),
    _ => throw ArgumentError.value(surface),
  };
}

Future<void> _retainClosedCallback(
  WidgetTester tester,
  OverlaySurface surface,
  List<WeakReference<_CallbackPayload>> references,
  List<VoidCallback> callbacks,
) async {
  final handle = _showPayload(surface, references);
  await tester.pumpAndSettle();
  callbacks.add(tester.widget<MaskEvent>(find.byType(MaskEvent)).onMask);
  await _close(tester, handle);
  await handle.closed;
}

ShowCustomParam _customParam(
  String label, {
  String tag = 'internal',
  bool mask = true,
  bool keepSingle = false,
  bool permanent = false,
  VoidCallback? onMask,
}) => ShowCustomParam(
  builder: (_) => SizedBox(width: 40, height: 40, child: Text(label)),
  alignment: Alignment.center,
  clickMaskDismiss: mask,
  animationType: AnimationType.fade,
  nonAnimationTypes: const [],
  animationBuilder: null,
  usePenetrate: false,
  useAnimation: false,
  animationTime: const Duration(milliseconds: 200),
  maskColor: Colors.black54,
  maskWidget: null,
  onDismiss: null,
  onMask: onMask,
  awaitCompletion: AwaitCompletion.dismiss,
  requestFocus: false,
  debounce: false,
  debounceTime: Duration.zero,
  displayTime: null,
  tag: tag,
  keepSingle: keepSingle,
  permanent: permanent,
  bindPage: false,
  bindWidget: null,
  ignoreArea: null,
  maskTriggerType: MaskTriggerType.up,
  controller: null,
  backType: BackType.normal,
  onBack: null,
);

ShowAttachParam _attachParam(
  ShowCustomParam base, {
  Offset Function()? target,
}) => ShowAttachParam(
  builder: base.builder,
  alignment: base.alignment,
  clickMaskDismiss: base.clickMaskDismiss,
  animationType: base.animationType,
  nonAnimationTypes: base.nonAnimationTypes,
  animationBuilder: null,
  usePenetrate: base.usePenetrate,
  useAnimation: base.useAnimation,
  animationTime: base.animationTime,
  maskColor: base.maskColor,
  maskWidget: null,
  onDismiss: null,
  onMask: base.onMask,
  awaitCompletion: base.awaitCompletion,
  requestFocus: false,
  debounce: false,
  debounceTime: Duration.zero,
  displayTime: null,
  tag: base.tag,
  keepSingle: base.keepSingle,
  permanent: base.permanent,
  bindPage: false,
  bindWidget: null,
  ignoreArea: null,
  maskTriggerType: MaskTriggerType.up,
  controller: null,
  backType: BackType.normal,
  onBack: null,
  targetContext: null,
  targetRectBuilder: null,
  targetPointBuilder: (_, _) => target?.call() ?? const Offset(400, 300),
  alignmentMode: PopupAlignmentMode.center,
  replacementBuilder: null,
  adjustmentBuilder: null,
  scaleOriginBuilder: null,
  maskIgnoreArea: null,
  highlight: null,
);

Future<void> _showInternal(
  OverlaySurface surface,
  String label, {
  bool mask = true,
  bool keepSingle = false,
  bool permanent = false,
  VoidCallback? onMask,
}) {
  final manager = OverlayManager.instance;
  final base = _customParam(
    label,
    mask: mask,
    keepSingle: keepSingle,
    permanent: permanent,
    onMask: onMask,
  );
  return switch (surface) {
    OverlaySurface.dialog => manager.show<void>(param: base),
    OverlaySurface.popup => manager.showAttach<void>(param: _attachParam(base)),
    OverlaySurface.loading => manager.showLoading<void>(
      param: ShowLoadingParam(
        builder: base.builder,
        alignment: base.alignment,
        clickMaskDismiss: base.clickMaskDismiss,
        animationType: base.animationType,
        nonAnimationTypes: const [],
        animationBuilder: null,
        usePenetrate: false,
        useAnimation: false,
        animationTime: base.animationTime,
        maskColor: base.maskColor,
        maskWidget: null,
        onDismiss: null,
        onMask: onMask,
        awaitCompletion: AwaitCompletion.dismiss,
        requestFocus: false,
        displayTime: null,
        leastLoadingTime: Duration.zero,
        tag: 'internal',
        backType: BackType.normal,
        onBack: null,
      ),
    ),
    OverlaySurface.notification => manager.showNotify<void>(
      param: ShowNotifyParam(
        builder: base.builder,
        alignment: base.alignment,
        clickMaskDismiss: base.clickMaskDismiss,
        animationType: base.animationType,
        nonAnimationTypes: const [],
        animationBuilder: null,
        usePenetrate: false,
        useAnimation: false,
        animationTime: base.animationTime,
        maskColor: base.maskColor,
        maskWidget: null,
        onDismiss: null,
        onMask: onMask,
        awaitCompletion: AwaitCompletion.dismiss,
        requestFocus: false,
        debounce: false,
        debounceTime: Duration.zero,
        displayTime: null,
        tag: 'internal',
        keepSingle: keepSingle,
        backType: BackType.normal,
        onBack: null,
      ),
    ),
    _ => throw ArgumentError.value(surface),
  };
}

void main() {
  for (final phase in [
    'replace-before-frame',
    'close-before-frame',
    'closing',
  ]) {
    for (final back in OverlayBackBehavior.values) {
      for (final oldMask in [false, true]) {
        testWidgets(
          'old Loading mask preserves replacement: $phase $back mask=$oldMask',
          (tester) async {
            await _mount(tester);
            if (phase == 'closing') {
              overlayConfig.loading = const LoadingConfig(
                nonAnimationTypes: [],
              );
            }
            final old = _show(OverlaySurface.loading, 'old', mask: oldMask);
            await tester.pumpAndSettle();
            Future<void>? closing;
            if (phase != 'replace-before-frame') closing = old.close();
            final current = _show(
              OverlaySurface.loading,
              'current',
              back: back,
            );
            if (phase == 'closing') {
              await tester.pump(const Duration(milliseconds: 1));
            }
            await tester.tapAt(const Offset(20, 400));
            await tester.pumpAndSettle();
            await closing;
            await old.closed;
            expect(current.isVisible, isTrue);
            await current.visible;
            await _close(tester, current);
          },
        );
      }
    }
  }

  for (final surface in [
    OverlaySurface.dialog,
    OverlaySurface.popup,
    OverlaySurface.notification,
  ]) {
    for (final collide in [false, true]) {
      testWidgets(
        'old $surface mask cannot close new business collision=$collide',
        (tester) async {
          await _mount(tester);
          final old = _show(surface, 'old', mask: true);
          await tester.pumpAndSettle();
          final identity = _identity(surface);
          await old.close();
          final current = _show(
            surface,
            'current',
            tag: collide ? identity : 'other',
          );
          expect(find.text('old'), findsOneWidget);
          await tester.tapAt(const Offset(20, 400));
          await tester.pumpAndSettle();
          expect(current.isVisible, isTrue);
          await current.visible;
          await _close(tester, current);
        },
      );
    }
  }

  for (final collide in [false, true]) {
    testWidgets(
      'scheduled target failure owns original popup collision=$collide',
      (tester) async {
        await _mount(tester);
        var valid = true;
        final old = SuperOverlay.popup.show<void>(
          builder:
              (_, _) =>
                  const SizedBox(width: 40, height: 40, child: Text('old')),
          options: OverlayPopupOptions(
            targetPointBuilder:
                (_, _) =>
                    valid
                        ? const Offset(400, 300)
                        : const Offset(double.nan, 0),
          ),
        );
        await tester.pumpAndSettle();
        final identity = _identity(OverlaySurface.popup);
        OverlayHandle<void>? current;
        Future<void>? closing;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          closing = old.close();
          current = _show(
            OverlaySurface.popup,
            'current',
            tag: collide ? identity : 'other',
          );
        });
        addTearDown(tester.view.resetPhysicalSize);
        tester.view.physicalSize = const Size(810, 600);
        valid = false;
        await tester.pump();
        await tester.pumpAndSettle();
        await closing;
        expect(current, isNotNull);
        expect(current!.isVisible, isTrue);
        await current!.visible;
        await _close(tester, current!);
      },
    );
  }

  for (final surface in [
    OverlaySurface.loading,
    OverlaySurface.dialog,
    OverlaySurface.popup,
    OverlaySurface.notification,
  ]) {
    testWidgets('current $surface mask still closes its own surface', (
      tester,
    ) async {
      await _mount(tester);
      final current = _show(surface, 'current', mask: true);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 400));
      await tester.pumpAndSettle();
      await current.closed;
      expect(current.isVisible, isFalse);
    });

    testWidgets('global business tag close remains available for $surface', (
      tester,
    ) async {
      await _mount(tester);
      final current = _show(surface, 'current', tag: 'business');
      await tester.pumpAndSettle();
      final closing = SuperOverlay.close(
        target: OverlayCloseTarget.all,
        tag: 'business',
      );
      await tester.pumpAndSettle();
      await closing;
      await current.closed;
      expect(current.isVisible, isFalse);
    });

    testWidgets(
      'internal $surface onMask replacement cannot transfer ownership',
      (tester) async {
        await _mount(tester);
        Future<void>? replacement;
        final original = _showInternal(
          surface,
          'old',
          onMask:
              () => replacement = _showInternal(surface, 'new', mask: false),
        );
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(20, 400));
        await tester.pumpAndSettle();
        expect(find.text('new'), findsOneWidget);
        expect(replacement, isNotNull);
        final close = SuperOverlay.close(
          target: OverlayCloseTarget.all,
          force: true,
        );
        await tester.pumpAndSettle();
        await close;
        await original;
        await replacement;
      },
    );

    testWidgets(
      'closing internal $surface mask skips old application callback',
      (tester) async {
        await _mount(tester);
        var calls = 0;
        final original = _showInternal(surface, 'old', onMask: () => calls++);
        await tester.pumpAndSettle();
        final callback =
            tester.widget<MaskEvent>(find.byType(MaskEvent)).onMask;
        final closing = SuperOverlay.close(target: OverlayCloseTarget.all);
        final replacement = _showInternal(surface, 'new', mask: false);
        callback();
        await tester.pumpAndSettle();
        await closing;
        expect(calls, 0);
        expect(find.text('new'), findsOneWidget);
        final close = SuperOverlay.close(target: OverlayCloseTarget.all);
        await tester.pumpAndSettle();
        await close;
        await original;
        await replacement;
      },
    );

    testWidgets('retained internal $surface callback ignores later host', (
      tester,
    ) async {
      await _mount(tester);
      var calls = 0;
      final original = _showInternal(surface, 'old', onMask: () => calls++);
      await tester.pumpAndSettle();
      final callback = tester.widget<MaskEvent>(find.byType(MaskEvent)).onMask;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await original;
      await _mount(tester);
      final replacement = _show(surface, 'new');
      await tester.pumpAndSettle();
      callback();
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(replacement.isVisible, isTrue);
      await _close(tester, replacement);
    });
  }

  for (final surface in [
    OverlaySurface.dialog,
    OverlaySurface.popup,
    OverlaySurface.notification,
  ]) {
    testWidgets('internal keepSingle $surface replaces callback presentation', (
      tester,
    ) async {
      await _mount(tester);
      var calls = 0;
      final original = _showInternal(
        surface,
        'old',
        keepSingle: true,
        onMask: () => calls++,
      );
      await tester.pumpAndSettle();
      final replacement = _showInternal(
        surface,
        'new',
        keepSingle: true,
        mask: false,
      );
      await tester.tapAt(const Offset(20, 400));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('new'), findsOneWidget);
      final close = SuperOverlay.close(target: OverlayCloseTarget.all);
      await tester.pumpAndSettle();
      await close;
      await original;
      await replacement;
    });
  }

  for (final surface in [OverlaySurface.dialog, OverlaySurface.popup]) {
    testWidgets(
      'permanent internal $surface ignores mask but force still closes',
      (tester) async {
        await _mount(tester);
        final current = _showInternal(surface, 'permanent', permanent: true);
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(20, 400));
        await tester.pumpAndSettle();
        expect(find.text('permanent'), findsOneWidget);
        final close = SuperOverlay.close(
          target: OverlayCloseTarget.all,
          force: true,
        );
        await tester.pumpAndSettle();
        await close;
        await current;
      },
    );
  }

  for (final sameParam in [false, true]) {
    for (final firstReplacementValid in [false, true]) {
      testWidgets(
        'keepSingle target failure resets per presentation sameParam=$sameParam valid=$firstReplacementValid',
        (tester) async {
          await _mount(tester);
          var valid = true;
          Offset target() =>
              valid ? const Offset(400, 300) : const Offset(double.nan, 0);
          final param = _attachParam(
            _customParam('popup', keepSingle: true),
            target: target,
          );
          final original = OverlayManager.instance.showAttach<void>(
            param: param,
          );
          await tester.pumpAndSettle();
          var replacementClosed = false;
          Future<void>? replacement;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            valid = firstReplacementValid;
            replacement = OverlayManager.instance.showAttach<void>(
              param:
                  sameParam
                      ? param
                      : _attachParam(
                        _customParam('replacement', keepSingle: true),
                        target: target,
                      ),
            );
            replacement!.then((_) => replacementClosed = true);
          });
          addTearDown(tester.view.resetPhysicalSize);
          tester.view.physicalSize = const Size(810, 600);
          valid = false;
          await tester.pump();
          await tester.pumpAndSettle();
          if (firstReplacementValid) {
            expect(replacementClosed, isFalse);
            expect(
              SuperOverlay.exists(surfaces: const {OverlaySurface.popup}),
              isTrue,
            );
            valid = false;
            tester.view.physicalSize = const Size(820, 600);
            await tester.pump();
            await tester.pumpAndSettle();
          }
          expect(replacementClosed, isTrue);
          expect(
            SuperOverlay.exists(surfaces: const {OverlaySurface.popup}),
            isFalse,
          );
          await original;
          await replacement;
        },
      );
    }
  }

  for (final surface in [
    OverlaySurface.loading,
    OverlaySurface.dialog,
    OverlaySurface.popup,
    OverlaySurface.notification,
  ]) {
    testWidgets('retained $surface mask callback releases closed content', (
      tester,
    ) async {
      await _mount(tester);
      final references = <WeakReference<_CallbackPayload>>[];
      final callbacks = <VoidCallback>[];
      for (var i = 0; i < 8; i++) {
        await _retainClosedCallback(tester, surface, references, callbacks);
      }
      await tester.runAsync(collectHeapCounts);
      expect(
        references.where((reference) => reference.target != null),
        isEmpty,
      );
      for (final callback in callbacks) {
        callback();
      }
      expect(SuperOverlay.exists(surfaces: {surface}), isFalse);
    });
  }

  testWidgets('unavailable permanent popup still closes its own target owner', (
    tester,
  ) async {
    await _mount(tester);
    final closed = OverlayManager.instance.showAttach<void>(
      param: _attachParam(
        _customParam('permanent', permanent: true),
        target: () => const Offset(double.nan, 0),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      SuperOverlay.exists(surfaces: const {OverlaySurface.popup}),
      isFalse,
    );
    await closed;
  });

  testWidgets('mask ownership preserves shared dialog and popup debounce', (
    tester,
  ) async {
    await _mount(tester);
    final dialog = _show(OverlaySurface.dialog, 'dialog', mask: true);
    await tester.pumpAndSettle();
    final popup = _show(OverlaySurface.popup, 'popup', mask: true);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 400));
    await tester.pumpAndSettle();
    expect(popup.isVisible, isFalse);
    await tester.tapAt(const Offset(20, 400));
    await tester.pumpAndSettle();
    expect(dialog.isVisible, isTrue);
    await _close(tester, dialog);
  });
}
