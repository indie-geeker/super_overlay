import '../config/enum_config.dart';
import '../data/show_param.dart';
import '../helper/overlay_manager.dart';
import '../kit/super_overlay_entry.dart';
import '../kit/view_utils.dart';
import '../widget/helper/toast_helper.dart';
import 'base_overlay.dart';
import 'toast_tool.dart';

class CustomToast extends BaseOverlay {
  CustomToast({required SuperOverlayEntry overlayEntry}) : super(overlayEntry);

  factory CustomToast.create() {
    CustomToast? toast;
    final entry = SuperOverlayEntry(builder: (_) => toast!.getWidget());
    toast = CustomToast(overlayEntry: entry);
    return toast;
  }

  void show(ShowToastParam param) {
    final overlayContext = OverlayManager.instance.contextToast;
    if (overlayContext == null) {
      throw StateError(
        'SuperOverlay is not initialized. Use SuperOverlayInit.init() in MaterialApp.builder.',
      );
    }

    if (!overlayEntry.mounted) {
      ViewUtils.addSafeUse(
        () => overlayOf(overlayContext).insert(overlayEntry),
      );
    }

    mainOverlay.show<void>(
      param: param.asCustomParam(),
      onMask: () {
        param.onMask?.call();
        if (!param.clickMaskDismiss) {
          return;
        }
        ToastTool.instance.dismiss();
      },
    );
  }

  Future<void> dismiss() async {
    await mainOverlay.dismiss<void>();
    remove();
  }

  void remove() {
    overlayEntry.remove();
  }
}

extension on ShowToastParam {
  ShowCustomParam asCustomParam() {
    return ShowCustomParam(
      builder: (context) =>
          ToastHelper(consumeEvent: consumeEvent, child: builder(context)),
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
      debounce: debounce,
      debounceTime: debounceTime,
      displayTime: null,
      tag: null,
      keepSingle: false,
      permanent: false,
      bindPage: false,
      bindWidget: null,
      ignoreArea: null,
      maskTriggerType: MaskTriggerType.up,
      controller: null,
      backType: BackType.ignore,
      onBack: null,
    );
  }
}
