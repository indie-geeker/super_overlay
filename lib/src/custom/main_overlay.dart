import 'dart:async';

import 'package:flutter/material.dart';

import '../config/enum_config.dart';
import '../data/show_param.dart';
import '../helper/overlay_manager.dart';
import '../kit/overlay_controller.dart';
import '../kit/super_overlay_entry.dart';
import '../kit/view_utils.dart';
import '../widget/attach_dialog_widget.dart';
import '../widget/helper/dialog_scope.dart';
import '../widget/helper/overlay_accessibility_scope.dart';
import '../widget/overlay_dialog_widget.dart';

class MainOverlay {
  MainOverlay({required this.overlayEntry});

  final SuperOverlayEntry overlayEntry;

  bool _visible = true;
  Widget _widget = const SizedBox.shrink();
  Completer<dynamic>? _completer;
  VoidCallback? _onDismiss;
  VoidCallback? _refresh;
  SuperOverlayController? _controller;
  OverlayDialogWidgetController? _dialogController;
  AttachDialogWidgetController? _attachController;
  ValueNotifier<Rect?>? _attachTargetRect;
  WeakReference<FocusNode>? _focusRestoreTarget;
  bool _focusRestoreTargetCaptured = false;
  int _focusRestoreTargetToken = 0;
  Type? _resultType;
  bool Function(Object? value)? _acceptsResult;

  bool get visible => _visible;

  set visible(bool value) {
    _visible = value;
    _controller?.setPresentationEnabled(value);
  }

  Future<T?> show<T>({
    required ShowCustomParam param,
    required VoidCallback onMask,
  }) {
    _captureFocusRestoreTarget();
    _replaceController(param.controller);
    _resultType = T;
    _acceptsResult = (value) => value is T;
    _onDismiss = param.onDismiss;
    _refresh = param.controller?.refresh;
    _dialogController = OverlayDialogWidgetController();
    _attachController = null;
    _attachTargetRect = null;
    _widget = OverlayAccessibilityScope(
      mode: param.accessibilityMode,
      requestFocus: param.requestFocus,
      semanticsLabel: param.semanticsLabel,
      handlesEscape: param.backType != BackType.ignore || param.onBack != null,
      focusRestoreTarget: _focusRestoreTarget,
      child: OverlayDialogWidget(
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
        barrierDismissible: param.clickMaskDismiss,
        barrierSemanticsLabel: param.barrierSemanticsLabel,
        onMask: onMask,
        child: DialogScope(
          controller: param.controller,
          builder: param.builder,
          liveRegion:
              param.accessibilityMode == OverlayAccessibilityMode.liveRegion,
        ),
      ),
    );
    overlayEntry.markNeedsBuild();

    return _completionFuture<T>(param);
  }

  Future<T?> showAttach<T>({
    required ShowAttachParam param,
    required VoidCallback onMask,
    required Future<void> Function() onTargetUnavailable,
  }) {
    _captureFocusRestoreTarget();
    _replaceController(param.controller);
    _resultType = T;
    _acceptsResult = (value) => value is T;
    _onDismiss = param.onDismiss;
    _refresh = param.controller?.refresh;
    _dialogController = null;
    _attachController = AttachDialogWidgetController();
    final attachTargetRect = ValueNotifier<Rect?>(null);
    _attachTargetRect = attachTargetRect;
    _widget = OverlayAccessibilityScope(
      mode: param.accessibilityMode,
      requestFocus: param.requestFocus,
      semanticsLabel: param.semanticsLabel,
      handlesEscape: param.backType != BackType.ignore || param.onBack != null,
      focusRestoreTarget: _focusRestoreTarget,
      child: AttachDialogWidget(
        param: param,
        controller: _attachController!,
        targetRectListenable: attachTargetRect,
        onMask: onMask,
        onTargetUnavailable: onTargetUnavailable,
      ),
    );
    overlayEntry.markNeedsBuild();

    return _completionFuture<T>(param);
  }

  void _captureFocusRestoreTarget() {
    _focusRestoreTargetToken++;
    if (_focusRestoreTargetCaptured) {
      return;
    }
    _focusRestoreTargetCaptured = true;
    final primaryFocus = FocusManager.instance.primaryFocus;
    _focusRestoreTarget =
        primaryFocus == null ? null : WeakReference<FocusNode>(primaryFocus);
  }

  void _scheduleFocusRestoreTargetClear() {
    final token = ++_focusRestoreTargetToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (token != _focusRestoreTargetToken) {
        return;
      }
      _focusRestoreTarget = null;
      _focusRestoreTargetCaptured = false;
    });
  }

  void _clearFocusRestoreTarget() {
    _focusRestoreTargetToken++;
    _focusRestoreTarget = null;
    _focusRestoreTargetCaptured = false;
  }

  void _replaceController(SuperOverlayController? controller) {
    if (!identical(_controller, controller)) {
      _controller?.dismiss();
    }
    _controller = controller;
    controller?.setPresentationEnabled(visible);
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
  Future<void>? get currentVisibleFuture => _controller?.visible;

  void updateAttachTargetRect(Rect targetRect) {
    final listenable = _attachTargetRect;
    if (listenable != null && listenable.value != targetRect) {
      listenable.value = targetRect;
    }
  }

  Future<T?>? currentClosedFuture<T>({String? tag}) {
    final completer = _completer;
    if (completer == null) {
      return null;
    }
    final resultType = _resultType;
    if (resultType != null && resultType != T) {
      throw StateError(
        'Overlay tag "${tag ?? '<unknown>'}" uses result type $resultType '
        'and cannot be reused as $T.',
      );
    }
    return completer.future.then((value) => value as T?);
  }

  void validateDismissResult<T>({required String? tag, required T? result}) {
    final resultType = _resultType;
    final acceptsResult = _acceptsResult;
    if (result == null ||
        resultType == null ||
        acceptsResult == null ||
        acceptsResult(result)) {
      return;
    }
    throw StateError(
      'Overlay tag "${tag ?? '<unknown>'}" uses result type $resultType '
      'and cannot be closed with $T.',
    );
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
    await _attachController?.dismiss(closeType: closeType);
    _dialogController = null;
    _attachController = null;
    _attachTargetRect = null;
    _refresh = null;
    _controller?.dismiss();
    _controller = null;
    _widget = const SizedBox.shrink();
    overlayEntry.markNeedsBuild();
    _scheduleFocusRestoreTargetClear();

    final completer = _completer;
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
    _completer = null;
    _resultType = null;
    _acceptsResult = null;
  }

  void disposeImmediately() {
    visible = false;
    _onDismiss = null;
    _dialogController = null;
    _attachController = null;
    _attachTargetRect = null;
    _clearFocusRestoreTarget();
    _refresh = null;
    _controller?.dismiss();
    _controller = null;
    _widget = const SizedBox.shrink();

    final completer = _completer;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
    _completer = null;
    _resultType = null;
    _acceptsResult = null;
  }

  Widget getWidget() => visible ? _widget : const SizedBox.shrink();
}
