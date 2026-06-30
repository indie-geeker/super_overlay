import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

void main() {
  test('package entrypoint exports intended consumer API', () {
    final initBuilder = SuperOverlayInit.init();
    expect(initBuilder, isA<TransitionBuilder>());
    expect(SuperOverlayInit.observer, isNotNull);
    expect(SuperOverlay.config, isA<OverlayConfig>());

    final overlayConfig = OverlayConfig(
      custom: const CustomDialogConfig(),
      attach: const AttachDialogConfig(),
      loading: const LoadingConfig(),
      toast: const ToastConfig(),
      notify: const NotifyConfig(),
    );
    expect(overlayConfig.custom.awaitCompletion, AwaitCompletion.dismiss);

    final enumValues = <Object>[
      OverlayType.custom,
      OverlayType.attach,
      OverlayType.notify,
      OverlayType.loading,
      OverlayType.toast,
      DismissStatus.auto,
      DismissStatus.toast,
      DismissStatus.allToast,
      DismissStatus.loading,
      DismissStatus.custom,
      DismissStatus.attach,
      DismissStatus.dialog,
      DismissStatus.notify,
      DismissStatus.allCustom,
      DismissStatus.allAttach,
      DismissStatus.allDialog,
      DismissStatus.allNotify,
      ToastDisplayType.normal,
      ToastDisplayType.last,
      ToastDisplayType.onlyRefresh,
      ToastDisplayType.multi,
      AnimationType.fade,
      AnimationType.scale,
      AnimationType.size,
      AnimationType.centerFadeOtherSlide,
      AnimationType.centerScaleOtherSlide,
      MaskTriggerType.down,
      MaskTriggerType.move,
      MaskTriggerType.up,
      NonAnimationType.open,
      NonAnimationType.close,
      NonAnimationType.routeClose,
      NonAnimationType.maskClose,
      NonAnimationType.backClose,
      NonAnimationType.highlightMask,
      PopupAlignmentMode.inside,
      PopupAlignmentMode.center,
      PopupAlignmentMode.outside,
      AwaitCompletion.dismiss,
      AwaitCompletion.appear,
      AwaitCompletion.none,
      BackType.normal,
      BackType.block,
      BackType.ignore,
      NotifyType.success,
      NotifyType.failure,
      NotifyType.warning,
      NotifyType.error,
      NotifyType.alert,
    ];
    expect(enumValues, hasLength(49));

    final controller = SuperOverlayController();
    controller.refresh();
    controller.dismiss();

    final animationParam = AnimationParam(
      alignment: Alignment.center,
      animationTime: Duration.zero,
    );
    expect(animationParam.alignment, Alignment.center);

    final layoutInfo = PopupLayoutInfo(
      targetOffset: Offset.zero,
      targetSize: Size.zero,
      popupOffset: const Offset(4, 8),
      popupSize: const Size(120, 48),
    );
    const adjustment = PopupAdjustment(alignment: Alignment.topRight);

    Rect targetRectBuilder(Rect targetRect) => targetRect;
    Offset targetPointBuilder(Offset targetOffset, Size targetSize) {
      return targetOffset + targetSize.bottomRight(Offset.zero);
    }

    Widget replacementBuilder(PopupLayoutInfo _) {
      return const SizedBox.shrink();
    }

    PopupAdjustment adjustmentBuilder(PopupLayoutInfo _) => adjustment;
    Offset scaleOriginBuilder(Size popupSize) {
      return Offset(popupSize.width, 0);
    }

    expect(targetRectBuilder, isA<PopupTargetRectBuilder>());
    expect(targetPointBuilder, isA<PopupTargetPointBuilder>());
    expect(replacementBuilder, isA<PopupReplacementBuilder>());
    expect(adjustmentBuilder, isA<PopupAdjustmentBuilder>());
    expect(scaleOriginBuilder, isA<PopupScaleOriginBuilder>());
    expect(targetRectBuilder(const Rect.fromLTWH(0, 0, 10, 10)).width, 10);
    expect(
      targetPointBuilder(Offset.zero, const Size(10, 20)),
      const Offset(10, 20),
    );
    expect(replacementBuilder(layoutInfo), isA<SizedBox>());
    expect(adjustmentBuilder(layoutInfo).alignment, Alignment.topRight);
    expect(scaleOriginBuilder(const Size(10, 20)), const Offset(10, 0));

    Future<void> futureVoidCallback() async {}
    bool onBack() => true;
    Widget animationBuilder(
      AnimationController _,
      Widget child,
      AnimationParam animationParam,
    ) {
      expect(animationParam, isA<AnimationParam>());
      return child;
    }

    Widget toastBuilder(String message) => Text(message);
    Widget loadingBuilder(String message) => Text(message);
    Widget successBuilder(String message) => Text(message);
    final notifyStyle = NotifyStyle(successBuilder: successBuilder);

    expect(futureVoidCallback, isA<FutureVoidCallback>());
    expect(onBack, isA<SuperOverlayOnBack>());
    expect(futureVoidCallback(), completes);
    expect(onBack(), true);
    expect(animationBuilder, isA<AnimationBuilder>());
    expect(toastBuilder, isA<SuperOverlayToastBuilder>());
    expect(loadingBuilder, isA<SuperOverlayLoadingBuilder>());
    expect(toastBuilder('toast'), isA<Text>());
    expect(loadingBuilder('loading'), isA<Text>());
    expect(notifyStyle.build(NotifyType.success, 'done'), isA<Text>());
  });
}
