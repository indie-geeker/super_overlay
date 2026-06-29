import 'dart:async';

import 'package:flutter/material.dart';

import '../data/show_param.dart';
import '../helper/overlay_manager.dart';
import '../kit/super_overlay_entry.dart';
import '../widget/attach_dialog_widget.dart';
import '../widget/helper/dialog_scope.dart';
import '../widget/overlay_dialog_widget.dart';

class MainOverlay {
  MainOverlay({required this.overlayEntry});

  final SuperOverlayEntry overlayEntry;

  bool visible = true;
  Widget _widget = const SizedBox.shrink();
  Completer<dynamic>? _completer;
  VoidCallback? _onDismiss;
  OverlayDialogWidgetController? _dialogController;

  Future<T?> show<T>({
    required ShowCustomParam param,
    required VoidCallback onMask,
  }) {
    _onDismiss = param.onDismiss;
    _dialogController = OverlayDialogWidgetController();
    _widget = OverlayDialogWidget(
      controller: _dialogController!,
      alignment: param.alignment,
      usePenetrate: param.usePenetrate,
      useAnimation: param.useAnimation,
      animationTime: param.animationTime,
      animationType: param.animationType,
      nonAnimationTypes: param.nonAnimationTypes,
      animationBuilder: param.animationBuilder,
      maskColor: param.maskColor,
      maskWidget: param.maskWidget,
      maskTriggerType: param.maskTriggerType,
      ignoreArea: param.ignoreArea,
      onMask: onMask,
      child: DialogScope(controller: param.controller, builder: param.builder),
    );
    overlayEntry.markNeedsBuild();

    final completer = Completer<T?>();
    _completer = completer;
    return completer.future;
  }

  Future<T?> showAttach<T>({
    required ShowAttachParam param,
    required VoidCallback onMask,
  }) {
    _onDismiss = param.onDismiss;
    _dialogController = null;
    _widget = AttachDialogWidget(param: param, onMask: onMask);
    overlayEntry.markNeedsBuild();

    final completer = Completer<T?>();
    _completer = completer;
    return completer.future;
  }

  Future<void> dismiss<T>({
    T? result,
    OverlayCloseType closeType = OverlayCloseType.normal,
  }) async {
    _onDismiss?.call();
    _onDismiss = null;
    await _dialogController?.dismiss(closeType: closeType);
    _dialogController = null;
    _widget = const SizedBox.shrink();
    overlayEntry.markNeedsBuild();

    final completer = _completer;
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
    _completer = null;
  }

  Widget getWidget() => Offstage(offstage: !visible, child: _widget);
}
