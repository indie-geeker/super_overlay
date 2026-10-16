import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';
import 'package:super_overlay/src/config/enum_config.dart';
import 'package:super_overlay/src/data/show_param.dart';
import 'package:super_overlay/src/helper/overlay_manager.dart';

import 'overlay_test_support.dart';

String _identity(OverlaySurface surface) {
  final kind = surface == OverlaySurface.notification ? 'notify' : surface.name;
  for (var i = 0; i < 100000; i++) {
    final value = '_super_overlay_command_${kind}_$i';
    if (SuperOverlay.exists(tag: value, surfaces: {surface})) return value;
  }
  throw StateError('No active $surface identity.');
}

class _Page extends Page<void> {
  const _Page({required this.child, required super.key});

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) => PageRouteBuilder<void>(
    settings: this,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, _, _) => child,
  );
}

class _Harness {
  final integration = SuperOverlay.integration();
  final targetKey = GlobalKey();
  late StateSetter update;
  late StateSetter updateTarget;
  late BuildContext ownerContext;
  bool hasOwnerRoute = true;
  bool hasTarget = true;

  Future<void> mount(WidgetTester tester) async {
    final observer = integration.navigatorObserver();
    await tester.pumpWidget(
      MaterialApp(
        builder: integration.builder,
        navigatorObservers: [integration.observer],
        home: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return Navigator(
              observers: [observer],
              pages: [
                const _Page(
                  key: ValueKey('retained-page'),
                  child: Scaffold(body: Text('Retained page')),
                ),
                if (hasOwnerRoute)
                  _Page(
                    key: const ValueKey('owner-page'),
                    child: Builder(
                      builder: (context) {
                        ownerContext = context;
                        return Scaffold(
                          body: StatefulBuilder(
                            builder: (_, setState) {
                              updateTarget = setState;
                              return hasTarget
                                  ? SizedBox(
                                    key: targetKey,
                                    width: 40,
                                    height: 40,
                                  )
                                  : const SizedBox.shrink();
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
              onDidRemovePage: (_) {},
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      integration.dispose();
    });
  }

  OverlayHandle<String> show(
    OverlaySurface surface,
    String label, {
    String? tag,
    bool routeOwned = false,
    bool widgetOwned = false,
    Duration? duration,
  }) {
    final facade = routeOwned ? SuperOverlay.of(ownerContext) : null;
    Widget content(BuildContext context, OverlayHandle<String> handle) =>
        SizedBox(width: 40, height: 40, child: Text(label));
    if (surface == OverlaySurface.dialog) {
      final options = OverlayDialogOptions(
        tag: tag,
        bindToRoute: routeOwned,
        bindToWidget: widgetOwned ? targetKey.currentContext : null,
        displayDuration: duration,
      );
      return facade?.dialog.show<String>(builder: content, options: options) ??
          SuperOverlay.dialog.show<String>(builder: content, options: options);
    }
    final target = widgetOwned ? targetKey.currentContext : null;
    final options = OverlayPopupOptions(
      tag: tag,
      bindToRoute: routeOwned,
      displayDuration: duration,
      targetPointBuilder: widgetOwned ? null : (_, _) => const Offset(200, 200),
    );
    return facade?.popup.show<String>(
          targetContext: target,
          builder: content,
          options: options,
        ) ??
        SuperOverlay.popup.show<String>(
          targetContext: target,
          builder: content,
          options: options,
        );
  }
}

void _configureAnimation(bool animated) {
  final custom = overlayConfig.custom;
  final attach = overlayConfig.attach;
  final notify = overlayConfig.notify;
  addTearDown(() {
    overlayConfig.custom = custom;
    overlayConfig.attach = attach;
    overlayConfig.notify = notify;
  });
  overlayConfig.custom = CustomDialogConfig(
    useAnimation: animated,
    animationTime: const Duration(milliseconds: 200),
    nonAnimationTypes: const [],
  );
  overlayConfig.attach = AttachDialogConfig(
    useAnimation: animated,
    animationTime: const Duration(milliseconds: 200),
    nonAnimationTypes: const [],
  );
  overlayConfig.notify = NotifyConfig(
    useAnimation: animated,
    animationTime: const Duration(milliseconds: 200),
    nonAnimationTypes: const [],
  );
}

ShowCustomParam _internalParam(
  String label, {
  String tag = 'internal',
  bool mask = true,
  bool keepSingle = false,
  bool permanent = false,
  VoidCallback? onMask,
  Duration? duration,
  BuildContext? widgetOwner,
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
  displayTime: duration,
  tag: tag,
  keepSingle: keepSingle,
  permanent: permanent,
  bindPage: false,
  bindWidget: widgetOwner,
  ignoreArea: null,
  maskTriggerType: MaskTriggerType.up,
  controller: null,
  backType: BackType.normal,
  onBack: null,
);

Future<String?> _showDuplicateRecord(
  OverlaySurface surface,
  String label, {
  Duration? duration,
  BuildContext? widgetOwner,
}) {
  final manager = OverlayManager.instance;
  final base = _internalParam(
    label,
    tag: 'same-explicit-identity',
    duration: duration,
    widgetOwner: widgetOwner,
    mask: false,
  );
  if (surface == OverlaySurface.dialog) {
    return manager.show<String>(param: base);
  }
  if (surface == OverlaySurface.popup) {
    return manager.showAttach<String>(
      param: ShowAttachParam(
        builder: base.builder,
        alignment: base.alignment,
        clickMaskDismiss: false,
        animationType: base.animationType,
        nonAnimationTypes: base.nonAnimationTypes,
        animationBuilder: null,
        usePenetrate: false,
        useAnimation: false,
        animationTime: base.animationTime,
        maskColor: base.maskColor,
        maskWidget: null,
        onDismiss: null,
        onMask: null,
        awaitCompletion: AwaitCompletion.dismiss,
        debounce: false,
        debounceTime: Duration.zero,
        displayTime: duration,
        tag: base.tag,
        keepSingle: false,
        permanent: false,
        bindPage: false,
        bindWidget: widgetOwner,
        ignoreArea: null,
        maskTriggerType: MaskTriggerType.up,
        controller: null,
        backType: BackType.normal,
        onBack: null,
        targetContext: widgetOwner,
        targetRectBuilder: null,
        targetPointBuilder: (_, _) => const Offset(200, 200),
        alignmentMode: PopupAlignmentMode.center,
        replacementBuilder: null,
        adjustmentBuilder: null,
        scaleOriginBuilder: null,
        maskIgnoreArea: null,
        highlight: null,
      ),
    );
  }
  return manager.showNotify<String>(
    param: ShowNotifyParam(
      builder: base.builder,
      alignment: base.alignment,
      clickMaskDismiss: false,
      animationType: base.animationType,
      nonAnimationTypes: base.nonAnimationTypes,
      animationBuilder: null,
      usePenetrate: false,
      useAnimation: false,
      animationTime: base.animationTime,
      maskColor: base.maskColor,
      maskWidget: null,
      onDismiss: null,
      onMask: null,
      awaitCompletion: AwaitCompletion.dismiss,
      debounce: false,
      debounceTime: Duration.zero,
      displayTime: duration,
      tag: base.tag,
      keepSingle: false,
      backType: BackType.normal,
      onBack: null,
    ),
  );
}

void main() {
  for (final surface in [
    OverlaySurface.dialog,
    OverlaySurface.popup,
    OverlaySurface.notification,
  ]) {
    final triggers =
        surface == OverlaySurface.notification
            ? ['timer']
            : ['timer', 'widget'];
    for (final trigger in triggers) {
      testWidgets(
        '$surface $trigger cleanup owns explicit duplicate identity record',
        (tester) async {
          final harness = _Harness();
          await harness.mount(tester);
          var firstClosed = false, secondClosed = false;
          _showDuplicateRecord(
            surface,
            'First explicit identity',
            duration: trigger == 'timer' ? const Duration(seconds: 1) : null,
            widgetOwner:
                trigger == 'widget' ? harness.targetKey.currentContext! : null,
          ).then((_) => firstClosed = true);
          await tester.pumpAndSettle();
          _showDuplicateRecord(
            surface,
            'Second explicit identity',
          ).then((_) => secondClosed = true);
          await tester.pumpAndSettle();
          if (trigger == 'timer') {
            await tester.pump(const Duration(seconds: 2));
          } else {
            harness.updateTarget(() => harness.hasTarget = false);
          }
          await tester.pumpAndSettle();
          expect(firstClosed, isTrue);
          expect(secondClosed, isFalse);
          expect(find.text('Second explicit identity'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final animated in [false, true]) {
    for (final collision in [false, true]) {
      for (final surface in [OverlaySurface.dialog, OverlaySurface.popup]) {
        testWidgets(
          '$surface deferred route cleanup keeps original ownership, animation=$animated collision=$collision',
          (tester) async {
            _configureAnimation(animated);
            final harness = _Harness();
            await harness.mount(tester);
            final old = harness.show(
              surface,
              'Old route owner',
              routeOwned: true,
            );
            await tester.pumpAndSettle();
            final identity = _identity(surface);
            OverlayHandle<String>? current;
            Future<void>? closing;
            // This callback precedes the route cleanup scheduled while the
            // declarative Navigator updates its page list in the next build.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              closing = old.close('first result');
              current = harness.show(
                surface,
                'Route-neutral replacement',
                tag: collision ? identity : 'unrelated',
              );
            });
            harness.update(() => harness.hasOwnerRoute = false);
            await tester.pump();
            await tester.pumpAndSettle();
            await closing;
            expect(await old.closed, 'first result');
            expect(current, isNotNull);
            expect(current!.isVisible, isTrue);
            await current!.visible;
            expect(find.text('Route-neutral replacement'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );

        testWidgets(
          '$surface active widget cleanup preserves another business identity, animation=$animated collision=$collision',
          (tester) async {
            _configureAnimation(animated);
            final harness = _Harness();
            await harness.mount(tester);
            final old = harness.show(
              surface,
              'Widget owner',
              widgetOwned: true,
            );
            await tester.pumpAndSettle();
            final identity = _identity(surface);
            final current = harness.show(
              surface,
              'Unbound survivor',
              tag: collision ? identity : 'unrelated',
            );
            await tester.pumpAndSettle();
            harness.updateTarget(() => harness.hasTarget = false);
            await tester.pumpAndSettle();
            await tester.pump(const Duration(seconds: 1));
            expect(await old.closed, isNull);
            expect(current.isVisible, isTrue);
            await current.visible;
            expect(tester.takeException(), isNull);
          },
        );
      }

      for (final surface in [
        OverlaySurface.dialog,
        OverlaySurface.popup,
        OverlaySurface.notification,
      ]) {
        for (final closeBeforeDeadline in [false, true]) {
          testWidgets(
            '$surface display deadline owns its record, animation=$animated collision=$collision earlyClose=$closeBeforeDeadline',
            (tester) async {
              _configureAnimation(animated);
              final harness = _Harness();
              await harness.mount(tester);
              const lifetime = Duration(seconds: 2);
              if (surface == OverlaySurface.notification) {
                final old = SuperOverlay.notify.alert(
                  'Timed notification',
                  options: const OverlayNotifyOptions(
                    displayDuration: lifetime,
                  ),
                );
                await tester.pumpAndSettle();
                final identity = _identity(surface);
                if (closeBeforeDeadline) {
                  final closing = old.close();
                  await tester.pumpAndSettle();
                  await closing;
                }
                final current = SuperOverlay.notify.alert(
                  'Persistent notification',
                  options: OverlayNotifyOptions(
                    tag: collision ? identity : 'unrelated',
                    displayDuration: null,
                  ),
                );
                await tester.pump(const Duration(seconds: 3));
                await tester.pumpAndSettle();
                await old.closed;
                expect(current.isVisible, isTrue);
                await current.visible;
              } else {
                final old = harness.show(
                  surface,
                  'Timed content',
                  duration: lifetime,
                );
                await tester.pumpAndSettle();
                final identity = _identity(surface);
                if (closeBeforeDeadline) {
                  final closing = old.close('first result');
                  await tester.pumpAndSettle();
                  await closing;
                }
                final current = harness.show(
                  surface,
                  'Persistent content',
                  tag: collision ? identity : 'unrelated',
                );
                await tester.pump(const Duration(seconds: 3));
                await tester.pumpAndSettle();
                expect(
                  await old.closed,
                  closeBeforeDeadline ? 'first result' : null,
                );
                expect(current.isVisible, isTrue);
                await current.visible;
              }
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
