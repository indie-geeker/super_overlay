import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';
import 'package:super_overlay/src/custom/custom_loading.dart';
import 'package:super_overlay/src/custom/toast_tool.dart';
import 'package:super_overlay/src/data/show_param.dart';
import 'package:super_overlay/src/helper/overlay_manager.dart';
import 'package:super_overlay/src/kit/overlay_controller.dart';
import 'package:super_overlay/src/kit/super_overlay_entry.dart';
import 'package:super_overlay/src/kit/view_utils.dart';
import 'package:super_overlay/src/widget/animation/size_animation.dart';
import 'package:super_overlay/src/widget/helper/mask_event.dart';
import 'package:super_overlay/src/widget/helper/toast_helper.dart';

import 'overlay_test_support.dart';

void main() {
  tearDown(() {
    ToastTool.instance.reset();
  });

  test('ShowCustomParam copyWith preserves and replaces every field', () {
    var dismissed = false;
    var masked = false;
    var backed = false;
    final controller = SuperOverlayController();
    final replacementController = SuperOverlayController();
    final base = ShowCustomParam(
      builder: (_) => const Text('base'),
      alignment: Alignment.center,
      clickMaskDismiss: true,
      animationType: AnimationType.fade,
      nonAnimationTypes: const [NonAnimationType.close],
      animationBuilder: null,
      usePenetrate: false,
      useAnimation: true,
      animationTime: const Duration(milliseconds: 200),
      maskColor: Colors.black,
      maskWidget: const Text('mask'),
      onDismiss: () => dismissed = true,
      onMask: () => masked = true,
      awaitCompletion: AwaitCompletion.dismiss,
      debounce: true,
      debounceTime: const Duration(milliseconds: 300),
      displayTime: const Duration(seconds: 1),
      tag: 'base',
      businessTag: 'base-business',
      keepSingle: false,
      permanent: false,
      bindPage: true,
      bindWidget: null,
      ignoreArea: const Rect.fromLTWH(1, 2, 3, 4),
      maskTriggerType: MaskTriggerType.up,
      controller: controller,
      backType: BackType.normal,
      onBack: () {
        backed = true;
        return true;
      },
    );

    final copy = base.copyWith(
      builder: (_) => const Text('copy'),
      alignment: Alignment.bottomRight,
      clickMaskDismiss: false,
      animationType: AnimationType.scale,
      nonAnimationTypes: const [NonAnimationType.open],
      animationBuilder: (controller, child, param) => child,
      usePenetrate: true,
      useAnimation: false,
      animationTime: const Duration(milliseconds: 80),
      maskColor: Colors.red,
      maskWidget: const Text('new mask'),
      onDismiss: () => dismissed = true,
      onMask: () => masked = true,
      awaitCompletion: AwaitCompletion.appear,
      debounce: false,
      debounceTime: Duration.zero,
      displayTime: const Duration(seconds: 2),
      tag: 'copy',
      businessTag: 'copy-business',
      keepSingle: true,
      permanent: true,
      bindPage: false,
      bindWidget: null,
      ignoreArea: const Rect.fromLTWH(5, 6, 7, 8),
      maskTriggerType: MaskTriggerType.down,
      controller: replacementController,
      backType: BackType.block,
      onBack: () {
        backed = true;
        return false;
      },
    );

    expect(copy.builder, isNot(same(base.builder)));
    expect(copy.alignment, Alignment.bottomRight);
    expect(copy.clickMaskDismiss, isFalse);
    expect(copy.animationType, AnimationType.scale);
    expect(copy.nonAnimationTypes, const [NonAnimationType.open]);
    expect(copy.animationBuilder, isNotNull);
    expect(copy.usePenetrate, isTrue);
    expect(copy.useAnimation, isFalse);
    expect(copy.animationTime, const Duration(milliseconds: 80));
    expect(copy.maskColor, Colors.red);
    expect(copy.maskWidget, isA<Text>());
    copy.onDismiss?.call();
    copy.onMask?.call();
    expect(dismissed, isTrue);
    expect(masked, isTrue);
    expect(copy.awaitCompletion, AwaitCompletion.appear);
    expect(copy.debounce, isFalse);
    expect(copy.debounceTime, Duration.zero);
    expect(copy.displayTime, const Duration(seconds: 2));
    expect(copy.tag, 'copy');
    expect(copy.businessTag, 'copy-business');
    expect(copy.keepSingle, isTrue);
    expect(copy.permanent, isTrue);
    expect(copy.bindPage, isFalse);
    expect(copy.ignoreArea, const Rect.fromLTWH(5, 6, 7, 8));
    expect(copy.maskTriggerType, MaskTriggerType.down);
    expect(copy.controller, same(replacementController));
    expect(copy.backType, BackType.block);
    expect(copy.onBack?.call(), isFalse);
    expect(backed, isTrue);

    final fallback = base.copyWith();
    expect(fallback.alignment, base.alignment);
    expect(fallback.controller, same(controller));
    expect(fallback.tag, 'base');
  });

  test('NotifyStyle routes every notification type to its builder', () {
    final style = NotifyStyle(
      successBuilder: (message) => Text('success $message'),
      failureBuilder: (message) => Text('failure $message'),
      warningBuilder: (message) => Text('warning $message'),
      errorBuilder: (message) => Text('error $message'),
      alertBuilder: (message) => Text('alert $message'),
    );

    for (final type in OverlayNotificationType.values) {
      final widget = style.build(type, 'message');
      expect(widget, isA<Text>());
      expect((widget! as Text).data, '${type.name} message');
    }
  });

  test('AnimationParam stores animation callbacks', () {
    var forwarded = false;
    var dismissed = false;
    final param = AnimationParam(
      alignment: Alignment.center,
      animationTime: const Duration(milliseconds: 120),
      onForward: () => forwarded = true,
      onDismiss: () => dismissed = true,
    );

    param.onForward?.call();
    param.onDismiss?.call();

    expect(param.alignment, Alignment.center);
    expect(param.animationTime, const Duration(milliseconds: 120));
    expect(forwarded, isTrue);
    expect(dismissed, isTrue);
  });

  test(
    'SuperOverlayController refresh listener is removable and dismissible',
    () {
      final controller = SuperOverlayController();
      var refreshes = 0;
      void listener() => refreshes++;

      controller.setListener(listener);
      controller.refresh();
      expect(refreshes, 1);

      controller.removeListener(() {});
      controller.refresh();
      expect(refreshes, 2);

      controller.removeListener(listener);
      controller.refresh();
      expect(refreshes, 2);

      controller.setListener(listener);
      controller.dismiss();
      controller.refresh();
      expect(refreshes, 2);
    },
  );

  test('CustomLoading reset restores default lifecycle state', () {
    final loading = CustomLoading(
      overlayEntry: SuperOverlayEntry(builder: (_) => const SizedBox.shrink()),
    );

    loading.reset();

    expect(loading.isVisible, isFalse);
    expect(loading.matchesTag('missing'), isFalse);
    expect(loading.backType, BackType.normal);
    expect(loading.onBack, isNull);
  });

  test('ViewUtils runs immediately outside a frame', () async {
    var immediate = 0;
    ViewUtils.addSafeUse(() => immediate++);
    expect(immediate, 1);

    var safeCompleted = false;
    await ViewUtils.awaitSafeUse(onPostFrame: () => safeCompleted = true);
    expect(safeCompleted, isTrue);
  });

  testWidgets('SizeAnimation chooses axis from alignment', (tester) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 1),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizeAnimation(
          controller: controller,
          alignment: Alignment.centerLeft,
          child: const Text('horizontal'),
        ),
      ),
    );
    expect(
      tester.widget<SizeTransition>(find.byType(SizeTransition)).axis,
      Axis.horizontal,
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizeAnimation(
          controller: controller,
          alignment: Alignment.topCenter,
          child: const Text('vertical'),
        ),
      ),
    );
    expect(
      tester.widget<SizeTransition>(find.byType(SizeTransition)).axis,
      Axis.vertical,
    );
  });

  testWidgets('MaskEvent honors down move and up trigger modes', (
    tester,
  ) async {
    Future<int> trigger(
      MaskTriggerType type,
      Offset first, [
      Offset? second,
    ]) async {
      var count = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MaskEvent(
            maskTriggerType: type,
            onMask: () => count++,
            child: const SizedBox(width: 80, height: 80),
          ),
        ),
      );
      final gesture = await tester.startGesture(first);
      if (second != null) {
        await gesture.moveTo(second);
      }
      await gesture.up();
      return count;
    }

    expect(await trigger(MaskTriggerType.down, const Offset(10, 10)), 1);
    expect(
      await trigger(
        MaskTriggerType.move,
        const Offset(10, 10),
        const Offset(20, 20),
      ),
      1,
    );
    expect(await trigger(MaskTriggerType.up, const Offset(10, 10)), 1);
  });

  testWidgets('ToastHelper can pass through or consume pointer events', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox.expand(),
            ),
            const Align(
              alignment: Alignment.center,
              child: ToastHelper(
                consumeEvent: false,
                child: SizedBox(width: 100, height: 100, child: Text('toast')),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('toast'), warnIfMissed: false);
    expect(taps, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox.expand(),
            ),
            const Align(
              alignment: Alignment.center,
              child: ToastHelper(
                consumeEvent: true,
                child: SizedBox(width: 100, height: 100, child: Text('toast')),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('toast'));
    expect(taps, 1);
  });

  testWidgets('ToastTool covers direct show tag debounce and dismiss flows', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(builder: SuperOverlay.init(), home: const SizedBox.shrink()),
    );
    final generation = OverlayManager.instance.requireActiveGeneration();

    final direct = ToastTool.instance.show<void>(
      _toastParam(
        'direct toast',
        tag: 'direct',
        awaitCompletion: AwaitCompletion.none,
      ),
      generation: generation,
    );
    await direct;
    await tester.pump();

    expect(ToastTool.instance.isExist(generation), isTrue);
    expect(ToastTool.instance.hasTag('direct', generation: generation), isTrue);
    expect(
      ToastTool.instance.isActiveTag('direct', generation: generation),
      isTrue,
    );

    final debounced = ToastTool.instance.showCommand<void>(
      _toastParam('debounced toast', tag: 'debounced', debounce: true),
      generation: generation,
    );
    final blocked = ToastTool.instance.showCommand<void>(
      _toastParam('blocked toast', tag: 'blocked', debounce: true),
      generation: generation,
    );
    await debounced.visible;
    await blocked.visible;
    await tester.pump();
    expect(find.text('blocked toast'), findsNothing);

    final replacing = ToastTool.instance.showCommand<void>(
      _toastParam('replacement toast', tag: 'direct', replaceExisting: true),
      generation: generation,
    );
    await replacing.visible;
    await tester.pumpAndSettle();
    expect(find.text('direct toast'), findsNothing);
    expect(find.text('replacement toast'), findsOneWidget);

    final kept = ToastTool.instance.showCommand<void>(
      _toastParam('ignored keep toast', tag: 'direct', keepSingle: true),
      generation: generation,
    );
    await kept.visible;
    await tester.pump();
    expect(find.text('ignored keep toast'), findsNothing);

    final queued = ToastTool.instance.showCommand<void>(
      _toastParam(
        'queued toast',
        tag: 'queued',
        displayType: ToastDisplayType.normal,
      ),
      generation: generation,
    );
    expect(ToastTool.instance.hasTag('queued', generation: generation), isTrue);
    await ToastTool.instance.dismiss(generation: generation, tag: 'queued');
    await queued.closed;

    final auto = ToastTool.instance.showCommand<void>(
      _toastParam(
        'auto toast',
        tag: 'auto',
        displayTime: const Duration(milliseconds: 10),
      ),
      generation: generation,
    );
    await auto.visible;
    await tester.pump(const Duration(milliseconds: 20));
    await auto.closed;
    expect(ToastTool.instance.hasTag('auto', generation: generation), isFalse);

    await ToastTool.instance.dismiss(generation: generation);
    ToastTool.instance.reset();
    expect(ToastTool.instance.isExist(generation), isFalse);
  });
}

ShowToastParam _toastParam(
  String message, {
  String? tag,
  bool debounce = false,
  bool keepSingle = false,
  bool replaceExisting = false,
  ToastDisplayType displayType = ToastDisplayType.multi,
  AwaitCompletion awaitCompletion = AwaitCompletion.dismiss,
  Duration displayTime = const Duration(seconds: 1),
}) {
  return ShowToastParam(
    builder: (_) => Text(message),
    alignment: Alignment.bottomCenter,
    clickMaskDismiss: false,
    animationType: AnimationType.fade,
    nonAnimationTypes: const [NonAnimationType.open, NonAnimationType.close],
    animationBuilder: null,
    usePenetrate: true,
    useAnimation: true,
    animationTime: const Duration(milliseconds: 1),
    maskColor: Colors.transparent,
    maskWidget: null,
    onDismiss: null,
    onMask: null,
    awaitCompletion: awaitCompletion,
    displayTime: displayTime,
    debounceTime: const Duration(seconds: 1),
    debounce: debounce,
    displayType: displayType,
    consumeEvent: false,
    tag: tag,
    keepSingle: keepSingle,
    replaceExisting: replaceExisting,
  );
}
