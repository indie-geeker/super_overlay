import '../data/show_param.dart';
import '../helper/overlay_manager.dart';
import '../kit/debounce_utils.dart';
import '../kit/super_overlay_entry.dart';
import 'base_overlay.dart';

class CustomOverlay extends BaseOverlay {
  CustomOverlay({required SuperOverlayEntry overlayEntry})
    : super(overlayEntry);

  Object _callbackPresentation = Object();
  Object get callbackPresentation => _callbackPresentation;

  Future<T?> show<T>({required ShowCustomParam param}) {
    final config = param.debounce;
    if (DebounceUtils.instance.banContinue(
      OverlayDebounceType.custom,
      debounce: config,
      duration: param.debounceTime,
    )) {
      return Future<T?>.value();
    }

    final push = OverlayManager.instance.pushCustom(this, param);
    if (push.reused && push.overlay != this) {
      overlayEntry.remove();
    }
    push.overlay._callbackPresentation = Object();
    final owner = OverlayManager.instance.captureCustomCallbackOwner(
      overlay: push.overlay,
      generation: push.generation,
    );

    return push.overlay.mainOverlay.show<T>(
      param: param,
      onMask: owner.maskCallback(
        onMask: param.onMask,
        dismissible: param.clickMaskDismiss && !param.permanent,
        debounce: true,
      ),
    );
  }

  Future<T?> showAttach<T>({required ShowAttachParam param}) {
    if (DebounceUtils.instance.banContinue(
      OverlayDebounceType.attach,
      debounce: param.debounce,
      duration: param.debounceTime,
    )) {
      return Future<T?>.value();
    }

    final push = OverlayManager.instance.pushAttach(this, param);
    if (push.reused && push.overlay != this) {
      overlayEntry.remove();
    }
    push.overlay._callbackPresentation = Object();
    final owner = OverlayManager.instance.captureCustomCallbackOwner(
      overlay: push.overlay,
      generation: push.generation,
    );

    return push.overlay.mainOverlay.showAttach<T>(
      param: param,
      onMask: owner.maskCallback(
        onMask: param.onMask,
        dismissible: param.clickMaskDismiss && !param.permanent,
        debounce: true,
      ),
      onTargetUnavailable: owner.closeUnavailableTarget,
    );
  }

  Future<void> dismiss<T>({
    T? result,
    OverlayCloseType closeType = OverlayCloseType.normal,
  }) {
    return mainOverlay.dismiss<T>(result: result, closeType: closeType);
  }
}
