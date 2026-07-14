import 'dart:async';

import '../config/enum_config.dart';
import '../data/show_param.dart';
import '../helper/overlay_manager.dart';
import '../kit/super_overlay_entry.dart';
import '../kit/typedef.dart';
import 'base_overlay.dart';

class CustomLoading extends BaseOverlay {
  CustomLoading({
    required SuperOverlayEntry overlayEntry,
    void Function()? onBackDispositionChanged,
  }) : _onBackDispositionChanged = onBackDispositionChanged,
       super(overlayEntry);

  final void Function()? _onBackDispositionChanged;

  Timer? _leastTimer;
  Timer? _displayTimer;
  bool _visible = false;
  bool _canDismiss = true;
  _LoadingDismissOperation? _pendingDismiss;
  _DeferredLoadingShow<dynamic>? _deferredShow;
  var _lifecycle = 0;
  String? _tag;
  String? _businessTag;
  BackType _backType = BackType.normal;
  SuperOverlayOnBack? _onBack;

  bool get isVisible => _visible;
  bool matchesTag(String tag) =>
      _visible && (_tag == tag || _businessTag == tag);
  bool get isDismissPending => _pendingDismiss != null || _deferredShow != null;
  bool matchesDismissTag(String tag) =>
      matchesTag(tag) ||
      _pendingDismiss?.matchesTag(tag) == true ||
      _deferredShow?.matchesTag(tag) == true;
  BackType get backType => _backType;
  SuperOverlayOnBack? get onBack => _onBack;

  Future<T?> showLoading<T>({required ShowLoadingParam param}) {
    final pending = _pendingDismiss;
    if (pending != null && pending.started) {
      _cancelDeferredShow();
      final deferred = _DeferredLoadingShow<T>(
        lifecycle: _lifecycle,
        param: param,
      );
      _deferredShow = deferred;
      unawaited(_resumeDeferredShow(pending, deferred));
      return deferred.future;
    }

    return _showLoadingNow<T>(param: param);
  }

  Future<T?> _showLoadingNow<T>({required ShowLoadingParam param}) {
    _cancelDeferredShow();
    _lifecycle++;
    _settlePendingDismiss();
    _visible = true;
    _canDismiss = param.leastLoadingTime == Duration.zero;
    _tag = param.tag;
    _businessTag = param.businessTag;
    _backType = param.backType;
    _onBack = param.onBack;
    _onBackDispositionChanged?.call();
    _leastTimer?.cancel();
    _displayTimer?.cancel();

    if (!_canDismiss) {
      _leastTimer = Timer(param.leastLoadingTime, () {
        _leastTimer = null;
        _canDismiss = true;
        _startPendingDismiss();
      });
    }

    if (param.displayTime != null) {
      _displayTimer = Timer(param.displayTime!, () {
        _displayTimer = null;
        unawaited(dismiss());
      });
    }

    return mainOverlay.show<T>(
      param: param.asCustomParam(),
      onMask: () {
        param.onMask?.call();
        if (param.clickMaskDismiss) {
          dismiss(closeType: OverlayCloseType.mask);
        }
      },
    );
  }

  Future<void> dismiss({
    OverlayCloseType closeType = OverlayCloseType.normal,
    String? tag,
  }) {
    Future<void>? deferredClose;
    final deferred = _deferredShow;
    if (deferred != null && (tag == null || deferred.matchesTag(tag))) {
      _deferredShow = null;
      deferred.cancel();
      deferredClose = deferred.future.then<void>((_) {});
    }

    final pending = _pendingDismiss;
    if (pending != null && (tag == null || pending.matchesTag(tag))) {
      if (deferredClose != null) {
        return Future.wait<void>([
          pending.future,
          deferredClose,
        ]).then<void>((_) {});
      }
      return pending.future;
    }

    if (deferredClose != null) {
      return deferredClose;
    }

    if (!_visible || (tag != null && !matchesTag(tag))) {
      return Future<void>.value();
    }

    final operation = _LoadingDismissOperation(
      lifecycle: _lifecycle,
      closeType: closeType,
      tag: _tag,
      businessTag: _businessTag,
    );
    _pendingDismiss = operation;
    _onBackDispositionChanged?.call();
    if (_canDismiss) {
      _startPendingDismiss();
    }
    return operation.future;
  }

  Future<void> _resumeDeferredShow<T>(
    _LoadingDismissOperation pending,
    _DeferredLoadingShow<T> deferred,
  ) async {
    try {
      await pending.future;
    } catch (_) {
      _cancelDeferredShow(deferred);
      return;
    }

    if (!identical(_deferredShow, deferred) ||
        deferred.cancelled ||
        deferred.lifecycle != _lifecycle ||
        !mainOverlay.visible) {
      _cancelDeferredShow(deferred);
      return;
    }

    _deferredShow = null;
    try {
      final result = await _showLoadingNow<T>(param: deferred.param);
      deferred.complete(result);
    } catch (error, stackTrace) {
      deferred.fail(error, stackTrace);
    }
  }

  void _startPendingDismiss() {
    final operation = _pendingDismiss;
    if (operation == null || !operation.start()) {
      return;
    }
    unawaited(_runPendingDismiss(operation));
  }

  Future<void> _runPendingDismiss(_LoadingDismissOperation operation) async {
    if (!identical(_pendingDismiss, operation) ||
        operation.lifecycle != _lifecycle ||
        operation.cancelled) {
      operation.complete();
      return;
    }

    _visible = false;
    _tag = null;
    _businessTag = null;
    _leastTimer?.cancel();
    _leastTimer = null;
    _displayTimer?.cancel();
    _displayTimer = null;
    try {
      await mainOverlay.dismiss<void>(closeType: operation.closeType);
    } finally {
      if (identical(_pendingDismiss, operation)) {
        _pendingDismiss = null;
      }
      _onBackDispositionChanged?.call();
      operation.complete();
    }
  }

  void _settlePendingDismiss() {
    final operation = _pendingDismiss;
    _pendingDismiss = null;
    operation?.cancel();
    _onBackDispositionChanged?.call();
  }

  void _cancelDeferredShow([_DeferredLoadingShow<dynamic>? expected]) {
    final deferred = _deferredShow;
    if (deferred == null ||
        (expected != null && !identical(deferred, expected))) {
      return;
    }
    _deferredShow = null;
    deferred.cancel();
    _onBackDispositionChanged?.call();
  }

  void reset() {
    _lifecycle++;
    _cancelDeferredShow();
    _leastTimer?.cancel();
    _displayTimer?.cancel();
    _leastTimer = null;
    _displayTimer = null;
    _settlePendingDismiss();
    _visible = false;
    _canDismiss = true;
    _tag = null;
    _businessTag = null;
    _backType = BackType.normal;
    _onBack = null;
    _onBackDispositionChanged?.call();
  }

  void disposeHost() {
    reset();
    mainOverlay.disposeImmediately();
  }
}

class _DeferredLoadingShow<T> {
  _DeferredLoadingShow({required this.lifecycle, required this.param});

  final int lifecycle;
  final ShowLoadingParam param;
  final Completer<T?> _completer = Completer<T?>();
  bool cancelled = false;

  Future<T?> get future => _completer.future;

  bool matchesTag(String tag) => param.tag == tag || param.businessTag == tag;

  void cancel() {
    if (cancelled) {
      return;
    }
    cancelled = true;
    param.controller?.dismiss();
    complete(null);
  }

  void complete(T? result) {
    if (!_completer.isCompleted) {
      _completer.complete(result);
    }
  }

  void fail(Object error, StackTrace stackTrace) {
    param.controller?.dismiss();
    if (!_completer.isCompleted) {
      _completer.completeError(error, stackTrace);
    }
  }
}

class _LoadingDismissOperation {
  _LoadingDismissOperation({
    required this.lifecycle,
    required this.closeType,
    required this.tag,
    required this.businessTag,
  });

  final int lifecycle;
  final OverlayCloseType closeType;
  final String? tag;
  final String? businessTag;
  final Completer<void> _completer = Completer<void>();
  bool _started = false;
  bool cancelled = false;

  Future<void> get future => _completer.future;
  bool get started => _started;

  bool matchesTag(String value) => tag == value || businessTag == value;

  bool start() {
    if (_started || cancelled || _completer.isCompleted) {
      return false;
    }
    _started = true;
    return true;
  }

  void cancel() {
    cancelled = true;
    complete();
  }

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}

extension on ShowLoadingParam {
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
      debounce: false,
      debounceTime: Duration.zero,
      displayTime: displayTime,
      tag: null,
      keepSingle: false,
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
