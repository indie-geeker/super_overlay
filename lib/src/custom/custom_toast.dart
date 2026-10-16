import 'package:flutter/widgets.dart';

import '../config/enum_config.dart';
import '../data/show_param.dart';
import '../helper/overlay_manager.dart';
import '../kit/super_overlay_entry.dart';
import '../kit/view_utils.dart';
import '../widget/default/toast_widget.dart';
import '../widget/helper/toast_helper.dart';
import '../widget/helper/toast_stack_layout.dart';
import 'base_overlay.dart';

class CustomToast extends BaseOverlay {
  CustomToast({
    required SuperOverlayEntry overlayEntry,
    required this.generation,
    required this.stackEntry,
  }) : super(overlayEntry);

  final int generation;
  final ToastStackEntry stackEntry;
  bool _insertionRequested = false;
  bool _removed = false;

  factory CustomToast.create({
    required int generation,
    required ToastStackEntry stackEntry,
  }) {
    CustomToast? toast;
    final entry = SuperOverlayEntry(builder: (_) => toast!.getWidget());
    toast = CustomToast(
      overlayEntry: entry,
      generation: generation,
      stackEntry: stackEntry,
    );
    return toast;
  }

  void show(ShowToastParam param, {required VoidCallback onMask}) {
    final overlayContext = OverlayManager.instance.contextToast;
    if (overlayContext == null) {
      throw StateError(
        'SuperOverlay is not initialized. Install integration.builder and integration.observer on your app.',
      );
    }

    // Insertion precedes mounting. A refresh in that interval must reuse the
    // entry, including when insertion itself is deferred until after build.
    if (!_insertionRequested && !_removed) {
      _insertionRequested = true;
      ViewUtils.addSafeUse(() {
        if (_removed || !OverlayManager.instance.ownsGeneration(generation)) {
          return;
        }
        overlayOf(overlayContext).insert(overlayEntry);
      });
    }

    mainOverlay.show<void>(
      param: param.asCustomParam(stackEntry),
      onMask: onMask,
    );
  }

  Future<void> dismiss() async {
    await mainOverlay.dismiss<void>();
    remove();
  }

  void remove() {
    _removed = true;
    stackEntry.remove();
    overlayEntry.remove();
  }

  @override
  Widget getWidget() =>
      ToastStackPosition(entry: stackEntry, child: super.getWidget());

  void disposeImmediately() {
    mainOverlay.disposeImmediately();
    remove();
  }
}

extension on ShowToastParam {
  ShowCustomParam asCustomParam(ToastStackEntry stackEntry) {
    return ShowCustomParam(
      builder: (context) {
        final content = builder(context);
        return ToastStackMeasure(
          entry: stackEntry,
          outerMargin:
              content is ToastWidget
                  ? ToastWidget.outerMargin
                  : EdgeInsets.zero,
          child: ToastHelper(consumeEvent: consumeEvent, child: content),
        );
      },
      alignment: alignment,
      avoidKeyboard: true,
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
      displayTime: null,
      tag: null,
      keepSingle: false,
      permanent: false,
      bindPage: false,
      bindWidget: null,
      ignoreArea: null,
      maskTriggerType: MaskTriggerType.up,
      controller: controller,
      backType: BackType.ignore,
      onBack: null,
    );
  }
}
