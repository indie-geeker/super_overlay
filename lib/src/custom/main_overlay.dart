import 'dart:async';

import 'package:flutter/material.dart';

import '../data/show_param.dart';
import '../helper/overlay_manager.dart';
import '../kit/super_overlay_entry.dart';
import '../widget/overlay_dialog_widget.dart';

class MainOverlay {
  MainOverlay({required this.overlayEntry});

  final SuperOverlayEntry overlayEntry;

  bool visible = true;
  Widget _widget = const SizedBox.shrink();
  Completer<dynamic>? _completer;
  VoidCallback? _onDismiss;

  Future<T?> show<T>({
    required ShowCustomParam param,
    required VoidCallback onMask,
  }) {
    _onDismiss = param.onDismiss;
    _widget = OverlayDialogWidget(
      alignment: param.alignment,
      usePenetrate: param.usePenetrate,
      maskColor: param.maskColor,
      maskWidget: param.maskWidget,
      onMask: onMask,
      child: Builder(builder: param.builder),
    );
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
