import '../config/enum_config.dart';
import '../data/show_param.dart';
import '../helper/overlay_manager.dart';
import '../kit/debounce_utils.dart';
import '../kit/super_overlay_entry.dart';
import 'base_overlay.dart';

class CustomNotify extends BaseOverlay {
  CustomNotify({required SuperOverlayEntry overlayEntry}) : super(overlayEntry);

  Object _callbackPresentation = Object();
  Object get callbackPresentation => _callbackPresentation;

  Future<T?> showNotify<T>({required ShowNotifyParam param}) {
    if (DebounceUtils.instance.banContinue(
      OverlayDebounceType.notify,
      debounce: param.debounce,
      duration: param.debounceTime,
    )) {
      return Future<T?>.value();
    }

    final push = OverlayManager.instance.pushNotify(this, param);
    if (push.reused && push.overlay != this) {
      overlayEntry.remove();
    }
    push.overlay._callbackPresentation = Object();
    final owner = OverlayManager.instance.captureNotifyCallbackOwner(
      overlay: push.overlay,
      generation: push.generation,
    );

    return push.overlay.mainOverlay.show<T>(
      param: param.asCustomParam(),
      onMask: owner.maskCallback(
        onMask: param.onMask,
        dismissible: param.clickMaskDismiss,
      ),
    );
  }

  Future<void> dismiss<T>({
    T? result,
    OverlayCloseType closeType = OverlayCloseType.normal,
  }) {
    return mainOverlay.dismiss<T>(result: result, closeType: closeType);
  }
}

extension on ShowNotifyParam {
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
      accessibilityMode: accessibilityMode,
      requestFocus: requestFocus,
      semanticsLabel: semanticsLabel,
      barrierSemanticsLabel: barrierSemanticsLabel,
      debounce: debounce,
      debounceTime: debounceTime,
      displayTime: displayTime,
      tag: tag,
      keepSingle: keepSingle,
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
