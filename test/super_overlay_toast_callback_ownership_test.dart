import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';
import 'package:super_overlay/src/custom/toast_tool.dart';
import 'package:super_overlay/src/data/show_param.dart';
import 'package:super_overlay/src/helper/overlay_manager.dart';
import 'package:super_overlay/src/kit/overlay_controller.dart';
import 'package:super_overlay/src/widget/helper/mask_event.dart';

import 'overlay_test_support.dart';
import 'support/vm_heap.dart';

Future<void> _mount(WidgetTester tester, {bool animated = false}) async {
  final integration = SuperOverlay.integration();
  final original = overlayConfig.toast;
  // These internal configuration flags enable an otherwise inactive mask.
  overlayConfig.toast = ToastConfig(
    clickMaskDismiss: true,
    usePenetrate: false,
    nonAnimationTypes: animated ? const [] : const [NonAnimationType.close],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    integration.dispose();
    overlayConfig.toast = original;
  });
  await tester.pumpWidget(
    MaterialApp(
      builder: integration.builder,
      navigatorObservers: [integration.observer],
      home: const Scaffold(),
    ),
  );
}

OverlayHandle<void> _show(
  String label, {
  OverlayToastDisplayPolicy policy = OverlayToastDisplayPolicy.stack,
}) => SuperOverlay.toast(
  label,
  builder: (_) => SizedBox(width: 40, height: 40, child: Text(label)),
  options: OverlayToastOptions(
    displayPolicy: policy,
    displayDuration: const Duration(minutes: 1),
    alignment: Alignment.topCenter,
  ),
);

Future<void> _tapMask(WidgetTester tester) =>
    tester.tapAt(const Offset(20, 400));

class _InternalToast {
  _InternalToast(this.tag, this.closed);

  final String tag;
  final Future<void> closed;

  bool get isVisible =>
      SuperOverlay.exists(tag: tag, surfaces: const {OverlaySurface.toast});

  Future<void> close() => ToastTool.instance.dismissIdentityTag(
    generation: OverlayManager.instance.requireActiveGeneration(),
    tag: tag,
  );
}

_InternalToast _internal(
  String tag, {
  VoidCallback? onMask,
  ToastDisplayType display = ToastDisplayType.multi,
  bool dismissible = true,
}) {
  final config = overlayConfig.toast;
  final controller = SuperOverlayController();
  final closed = OverlayManager.instance.showToast<void>(
    param: ShowToastParam(
      builder: (_) => SizedBox(width: 40, height: 40, child: Text(tag)),
      alignment: Alignment.topCenter,
      clickMaskDismiss: dismissible,
      animationType: config.animationType,
      nonAnimationTypes: config.nonAnimationTypes,
      animationBuilder: null,
      usePenetrate: false,
      useAnimation: config.useAnimation,
      animationTime: config.animationTime,
      maskColor: config.maskColor,
      maskWidget: null,
      onDismiss: null,
      onMask: onMask,
      awaitCompletion: AwaitCompletion.dismiss,
      controller: controller,
      displayTime: const Duration(minutes: 1),
      debounceTime: config.debounceTime,
      debounce: false,
      displayType: display,
      consumeEvent: false,
      tag: tag,
      businessTag: null,
      keepSingle: false,
      replaceExisting: false,
    ),
  );
  return _InternalToast(tag, closed);
}

class _Payload {
  final bytes = List<int>.filled(4096, 1);
}

Future<VoidCallback> _retainMaskCallback(
  WidgetTester tester,
  List<WeakReference<_Payload>> references,
) async {
  final payload = _Payload();
  references.add(WeakReference(payload));
  SuperOverlay.toast(
    'payload',
    builder: (_) => Text('payload ${payload.bytes.length}'),
    options: const OverlayToastOptions(
      displayPolicy: OverlayToastDisplayPolicy.refreshActive,
      displayDuration: Duration(minutes: 1),
    ),
  );
  await tester.pumpAndSettle();
  return tester.widget<MaskEvent>(find.byType(MaskEvent)).onMask;
}

void main() {
  testWidgets('retained old Toast callbacks do not retain refreshed content', (
    tester,
  ) async {
    await _mount(tester);
    final references = <WeakReference<_Payload>>[];
    final callbacks = <VoidCallback>[];
    for (var i = 0; i < 20; i++) {
      callbacks.add(await _retainMaskCallback(tester, references));
    }
    await tester.runAsync(collectHeapCounts);
    expect(references.where((value) => value.target != null), hasLength(1));
    await SuperOverlay.close(target: OverlayCloseTarget.allToasts);
    await tester.pumpAndSettle();
    await tester.runAsync(collectHeapCounts);
    expect(references.where((value) => value.target != null), isEmpty);
    expect(callbacks, hasLength(20));
  });

  testWidgets('default Toast masks remain inert with multiple lanes', (
    tester,
  ) async {
    await _mount(tester);
    overlayConfig.toast = const ToastConfig();
    final first = _show('first');
    final second = _show('second');
    await tester.pumpAndSettle();
    await _tapMask(tester);
    await tester.pumpAndSettle();
    expect(first.isVisible, isTrue);
    expect(second.isVisible, isTrue);
  });

  testWidgets('configured Toast mask closes the tapped lane only', (
    tester,
  ) async {
    await _mount(tester);
    final first = _show('first');
    final second = _show('second');
    await tester.pumpAndSettle();
    await _tapMask(tester);
    await tester.pumpAndSettle();
    expect(first.isVisible, isTrue);
    expect(second.isVisible, isFalse);
    await second.closed;
  });

  testWidgets('closed Toast stale mask cannot dismiss another lane', (
    tester,
  ) async {
    await _mount(tester);
    final first = _show('old');
    await tester.pumpAndSettle();
    await first.close();
    overlayConfig.toast = const ToastConfig();
    final next = _show('new');
    expect(find.text('old'), findsOneWidget);
    expect(find.text('new'), findsNothing);
    await _tapMask(tester);
    await tester.pumpAndSettle();
    expect(next.isVisible, isTrue);
  });

  testWidgets('old refresh mask cannot close replacement presentation', (
    tester,
  ) async {
    await _mount(tester);
    final first = _show('old', policy: OverlayToastDisplayPolicy.refreshActive);
    await tester.pumpAndSettle();
    var firstClosed = false;
    first.closed.then((_) => firstClosed = true);
    overlayConfig.toast = const ToastConfig();
    final next = _show('new', policy: OverlayToastDisplayPolicy.refreshActive);
    expect(find.text('old'), findsOneWidget);
    expect(find.text('new'), findsNothing);
    await _tapMask(tester);
    await tester.pumpAndSettle();
    expect(next.isVisible, isTrue);
    expect(firstClosed, isFalse);
    final closing = next.close();
    await tester.pumpAndSettle();
    await closing;
    await first.closed;
    expect(firstClosed, isTrue);
  });

  testWidgets('current refresh mask settles historical shared lane futures', (
    tester,
  ) async {
    await _mount(tester);
    final first = _show('old', policy: OverlayToastDisplayPolicy.refreshActive);
    await tester.pumpAndSettle();
    final next = _show('new', policy: OverlayToastDisplayPolicy.refreshActive);
    await tester.pumpAndSettle();
    await _tapMask(tester);
    await tester.pumpAndSettle();
    expect(next.isVisible, isFalse);
    await Future.wait([first.closed, next.closed]);
  });

  testWidgets('closing Toast mask joins its lane without dismissing another', (
    tester,
  ) async {
    await _mount(tester, animated: true);
    final first = _show('first');
    final second = _show('second');
    await tester.pumpAndSettle();
    final closing = second.close();
    await _tapMask(tester);
    await tester.pumpAndSettle();
    await closing;
    expect(first.isVisible, isTrue);
    expect(second.isVisible, isFalse);
  });

  testWidgets('queue handoff leaves the next request safe from old mask', (
    tester,
  ) async {
    await _mount(tester);
    final first = _show('old', policy: OverlayToastDisplayPolicy.queue);
    await tester.pumpAndSettle();
    overlayConfig.toast = const ToastConfig();
    final next = _show('new', policy: OverlayToastDisplayPolicy.queue);
    await first.close();
    expect(find.text('old'), findsOneWidget);
    expect(find.text('new'), findsNothing);
    await _tapMask(tester);
    await tester.pumpAndSettle();
    await next.visible;
    expect(next.isVisible, isTrue);
  });

  testWidgets('reset stale Toast mask cannot dismiss a newly active request', (
    tester,
  ) async {
    await _mount(tester);
    _show('old');
    await tester.pumpAndSettle();
    await SuperOverlay.close(target: OverlayCloseTarget.allToasts);
    overlayConfig.toast = const ToastConfig();
    final next = _show('new');
    expect(find.text('old'), findsOneWidget);
    await _tapMask(tester);
    await tester.pumpAndSettle();
    expect(next.isVisible, isTrue);
  });

  testWidgets('Toast onMask reentry adding a lane only closes original owner', (
    tester,
  ) async {
    await _mount(tester);
    final first = _internal('first');
    _InternalToast? added;
    var calls = 0;
    final tapped = _internal(
      'tapped',
      onMask: () {
        calls++;
        added = _internal('added', dismissible: false);
      },
    );
    await tester.pumpAndSettle();
    await _tapMask(tester);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(first.isVisible, isTrue);
    expect(tapped.isVisible, isFalse);
    expect(added?.isVisible, isTrue);
  });

  testWidgets('Toast onMask refresh cannot close the replacement request', (
    tester,
  ) async {
    await _mount(tester);
    _InternalToast? next;
    var calls = 0;
    final first = _internal(
      'old',
      display: ToastDisplayType.onlyRefresh,
      onMask: () {
        calls++;
        next = _internal(
          'new',
          display: ToastDisplayType.onlyRefresh,
          dismissible: false,
        );
      },
    );
    await tester.pumpAndSettle();
    var sharedClosed = false;
    first.closed.then((_) => sharedClosed = true);
    await _tapMask(tester);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(next?.isVisible, isTrue);
    expect(sharedClosed, isFalse);
    final closing = next!.close();
    await tester.pumpAndSettle();
    await closing;
    await Future.wait([first.closed, next!.closed]);
    expect(sharedClosed, isTrue);
  });

  testWidgets('Toast onMask reset cannot close the newly created lane', (
    tester,
  ) async {
    await _mount(tester);
    _InternalToast? next;
    var calls = 0;
    _internal(
      'old',
      onMask: () {
        calls++;
        ToastTool.instance.reset();
        next = _internal('new', dismissible: false);
      },
    );
    await tester.pumpAndSettle();
    await _tapMask(tester);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(next?.isVisible, isTrue);
  });

  testWidgets('closing Toast does not rerun its old onMask callback', (
    tester,
  ) async {
    await _mount(tester, animated: true);
    final first = _internal('first');
    var calls = 0;
    final second = _internal('second', onMask: () => calls++);
    await tester.pumpAndSettle();
    final closing = second.close();
    await _tapMask(tester);
    await tester.pumpAndSettle();
    await closing;
    expect(calls, 0);
    expect(first.isVisible, isTrue);
  });

  testWidgets(
    'throwing Toast callback leaves other lanes and next tap intact',
    (tester) async {
      await _mount(tester);
      final first = _internal('first');
      var throwOnce = true;
      final second = _internal(
        'second',
        onMask: () {
          if (throwOnce) {
            throwOnce = false;
            throw StateError('mask callback failed');
          }
        },
      );
      await tester.pumpAndSettle();
      await _tapMask(tester);
      expect(tester.takeException(), isStateError);
      expect(first.isVisible, isTrue);
      expect(second.isVisible, isTrue);
      await _tapMask(tester);
      await tester.pumpAndSettle();
      expect(first.isVisible, isTrue);
      expect(second.isVisible, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
