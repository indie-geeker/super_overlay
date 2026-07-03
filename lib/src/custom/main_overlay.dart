import 'dart:async';

import 'package:flutter/material.dart';

import '../config/enum_config.dart';
import '../data/show_param.dart';
import '../helper/overlay_manager.dart';
import '../kit/super_overlay_entry.dart';
import '../kit/view_utils.dart';
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
  VoidCallback? _refresh;
  OverlayDialogWidgetController? _dialogController;

  Future<T?> show<T>({
    required ShowCustomParam param,
    required VoidCallback onMask,
  }) {
    _onDismiss = param.onDismiss;
    _refresh = param.controller?.refresh;
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

    return _completionFuture<T>(param);
  }

  Future<T?> showAttach<T>({
    required ShowAttachParam param,
    required VoidCallback onMask,
  }) {
    _onDismiss = param.onDismiss;
    _refresh = param.controller?.refresh;
    _dialogController = null;
    _widget = AttachDialogWidget(param: param, onMask: onMask);
    overlayEntry.markNeedsBuild();

    return _completionFuture<T>(param);
  }

  Future<T?> _completionFuture<T>(ShowCustomParam param) {
    final previousCompleter = _completer;
    if (previousCompleter != null && !previousCompleter.isCompleted) {
      previousCompleter.complete(null);
    }
    _completer = null;

    if (param.awaitCompletion == AwaitCompletion.appear) {
      return Future<T?>.delayed(_openDuration(param), () => null);
    }

    if (param.awaitCompletion == AwaitCompletion.none) {
      final completer = Completer<T?>();
      ViewUtils.addSafeUse(() {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });
      return completer.future;
    }

    final completer = Completer<T?>();
    _completer = completer;
    return completer.future;
  }

  VoidCallback? get currentRefresh => _refresh;

  Future<T?>? currentClosedFuture<T>() {
    final completer = _completer;
    if (completer == null) {
      return null;
    }
    return completer.future.then((value) => value as T?);
  }

  Duration _openDuration(ShowCustomParam param) {
    if (!param.useAnimation ||
        param.nonAnimationTypes.contains(NonAnimationType.open)) {
      return Duration.zero;
    }
    return param.animationTime;
  }

  Future<void> dismiss<T>({
    T? result,
    OverlayCloseType closeType = OverlayCloseType.normal,
  }) async {
    _onDismiss?.call();
    _onDismiss = null;
    await _dialogController?.dismiss(closeType: closeType);
    _dialogController = null;
    _refresh = null;
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
