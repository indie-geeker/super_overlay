import 'dart:async';

import '../config/enum_config.dart';
import '../data/show_param.dart';
import '../helper/overlay_manager.dart';
import '../kit/super_overlay_entry.dart';
import 'base_overlay.dart';

class CustomLoading extends BaseOverlay {
  CustomLoading({required SuperOverlayEntry overlayEntry})
    : super(overlayEntry);

  Timer? _leastTimer;
  Timer? _displayTimer;
  bool _visible = false;
  bool _canDismiss = true;
  Future<void> Function()? _pendingDismiss;

  bool get isVisible => _visible;

  Future<T?> showLoading<T>({required ShowLoadingParam param}) {
    _visible = true;
    _canDismiss = param.leastLoadingTime == Duration.zero;
    _pendingDismiss = null;
    _leastTimer?.cancel();
    _displayTimer?.cancel();

    if (!_canDismiss) {
      _leastTimer = Timer(param.leastLoadingTime, () {
        _canDismiss = true;
        final pending = _pendingDismiss;
        _pendingDismiss = null;
        pending?.call();
      });
    }

    if (param.displayTime != null) {
      _displayTimer = Timer(param.displayTime!, dismiss);
    }

    return mainOverlay.show<T>(
      param: param.asCustomParam(),
      onMask: () {
        param.onMask?.call();
        if (param.clickMaskDismiss) {
          dismiss(closeType: OverlayCloseType.mask);
        }
      },
    );
  }

  Future<void> dismiss({
    OverlayCloseType closeType = OverlayCloseType.normal,
  }) async {
    Future<void> realDismiss() async {
      if (!_visible) {
        return;
      }
      _visible = false;
      _displayTimer?.cancel();
      await mainOverlay.dismiss<void>(closeType: closeType);
    }

    if (!_canDismiss) {
      _pendingDismiss = realDismiss;
      return;
    }

    await realDismiss();
  }

  void reset() {
    _leastTimer?.cancel();
    _displayTimer?.cancel();
    _leastTimer = null;
    _displayTimer = null;
    _pendingDismiss = null;
    _visible = false;
    _canDismiss = true;
  }
}

extension on ShowLoadingParam {
  ShowCustomParam asCustomParam() {
    return ShowCustomParam(
      builder: builder,
      alignment: alignment,
      clickMaskDismiss: clickMaskDismiss,
      animationType: animationType,
      nonAnimationTypes: nonAnimationTypes,
      animationBuilder: animationBuilder,
      usePenetrate: usePenetrate,
      useAnimation: useAnimation,
      animationTime: animationTime,
      maskColor: maskColor,
      maskWidget: maskWidget,
      onDismiss: onDismiss,
      onMask: onMask,
      debounce: false,
      displayTime: displayTime,
      tag: null,
      keepSingle: false,
      permanent: false,
      bindPage: false,
      bindWidget: null,
      ignoreArea: null,
      maskTriggerType: MaskTriggerType.up,
      controller: null,
      backType: backType,
      onBack: onBack,
    );
  }
}
