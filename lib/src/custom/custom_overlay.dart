import '../config/enum_config.dart';
import '../data/show_param.dart';
import '../helper/overlay_manager.dart';
import '../kit/debounce_utils.dart';
import '../kit/super_overlay_entry.dart';
import 'base_overlay.dart';

class CustomOverlay extends BaseOverlay {
  CustomOverlay({required SuperOverlayEntry overlayEntry})
    : super(overlayEntry);

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

    return push.overlay.mainOverlay.show<T>(
      param: param,
      onMask: () {
        param.onMask?.call();
        if (!param.clickMaskDismiss || param.permanent) {
          return;
        }
        if (DebounceUtils.instance.banMaskContinue()) {
          return;
        }
        OverlayManager.instance.dismiss<void>(
          status: DismissStatus.custom,
          tag: push.tag,
          closeType: OverlayCloseType.mask,
        );
      },
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

    return push.overlay.mainOverlay.showAttach<T>(
      param: param,
      onMask: () {
        param.onMask?.call();
        if (!param.clickMaskDismiss || param.permanent) {
          return;
        }
        if (DebounceUtils.instance.banMaskContinue()) {
          return;
        }
        OverlayManager.instance.dismiss<void>(
          status: DismissStatus.attach,
          tag: push.tag,
          closeType: OverlayCloseType.mask,
        );
      },
      onTargetUnavailable:
          () => OverlayManager.instance.dismiss<void>(
            status: DismissStatus.attach,
            tag: push.tag,
            force: true,
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
