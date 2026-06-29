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
      duration: const Duration(milliseconds: 300),
    )) {
      return Future<T?>.value();
    }

    final tag = OverlayManager.instance.pushCustom(this, param);
    return mainOverlay.show<T>(
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
          tag: tag,
          closeType: OverlayCloseType.mask,
        );
      },
    );
  }

  Future<void> dismiss<T>({
    T? result,
    OverlayCloseType closeType = OverlayCloseType.normal,
  }) {
    return mainOverlay.dismiss<T>(result: result, closeType: closeType);
  }
}
