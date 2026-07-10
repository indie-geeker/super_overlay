import 'dart:async';

import '../config/enum_config.dart';
import '../data/show_param.dart';
import '../helper/overlay_manager.dart';
import '../kit/super_overlay_entry.dart';
import '../kit/typedef.dart';
import 'base_overlay.dart';

class CustomLoading extends BaseOverlay {
  CustomLoading({required SuperOverlayEntry overlayEntry})
    : super(overlayEntry);

  Timer? _leastTimer;
  Timer? _displayTimer;
  bool _visible = false;
  bool _canDismiss = true;
  Future<void> Function()? _pendingDismiss;
  String? _tag;
  BackType _backType = BackType.normal;
  SuperOverlayOnBack? _onBack;

  bool get isVisible => _visible;
  bool matchesTag(String tag) => _visible && _tag == tag;
  BackType get backType => _backType;
  SuperOverlayOnBack? get onBack => _onBack;

  Future<T?> showLoading<T>({required ShowLoadingParam param}) {
    _visible = true;
    _canDismiss = param.leastLoadingTime == Duration.zero;
    _pendingDismiss = null;
    _tag = param.tag;
    _backType = param.backType;
    _onBack = param.onBack;
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
      _tag = null;
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
    _tag = null;
    _backType = BackType.normal;
    _onBack = null;
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
      awaitCompletion: awaitCompletion,
      debounce: false,
      debounceTime: Duration.zero,
      displayTime: displayTime,
      tag: null,
      keepSingle: false,
      permanent: false,
      bindPage: false,
      bindWidget: null,
      ignoreArea: null,
      maskTriggerType: MaskTriggerType.up,
      controller: controller,
      backType: backType,
      onBack: onBack,
    );
  }
}
