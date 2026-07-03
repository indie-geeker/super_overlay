import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

import '../config/enum_config.dart';
import '../data/show_param.dart';
import '../kit/debounce_utils.dart';
import 'custom_toast.dart';

class ToastTool {
  ToastTool._();

  static final ToastTool instance = ToastTool._();

  final Queue<_ToastRequest> _normalQueue = ListQueue<_ToastRequest>();
  final List<_ActiveToast> _activeToasts = <_ActiveToast>[];

  bool _normalShowing = false;
  _ActiveToast? _onlyRefreshToast;

  bool get isExist => _activeToasts.isNotEmpty || _normalQueue.isNotEmpty;

  Future<T?> show<T>(ShowToastParam param) {
    if (DebounceUtils.instance.banContinue(
      OverlayDebounceType.toast,
      debounce: param.debounce,
      duration: param.debounceTime,
    )) {
      return Future<T?>.value();
    }

    final request = _ToastRequest(param);
    switch (param.displayType) {
      case ToastDisplayType.normal:
        _normalQueue.addLast(request);
        if (!_normalShowing) {
          _showNextNormal();
        }
        break;
      case ToastDisplayType.last:
        dismiss(closeAll: true);
        _showStandalone(request);
        break;
      case ToastDisplayType.onlyRefresh:
        _showOnlyRefresh(request);
        break;
      case ToastDisplayType.multi:
        _showStandalone(request);
        break;
    }
    return request.future<T>();
  }

  Future<void> dismiss({bool closeAll = false}) async {
    if (closeAll) {
      reset();
      return;
    }

    if (_activeToasts.isEmpty) {
      return;
    }

    final active = _activeToasts.removeAt(0);
    active.timer.cancel();
    await active.toast.dismiss();
    active.completeDismiss();
  }

  void reset() {
    for (final active in _activeToasts) {
      active.timer.cancel();
      active.toast.remove();
      active.completeDismiss();
    }
    for (final request in _normalQueue) {
      request.completeDismiss();
    }
    _activeToasts.clear();
    _normalQueue.clear();
    _normalShowing = false;
    _onlyRefreshToast = null;
  }

  void _showNextNormal() {
    if (_normalQueue.isEmpty) {
      _normalShowing = false;
      return;
    }

    _normalShowing = true;
    final request = _normalQueue.removeFirst();
    final active = _showStandalone(
      request,
      onDismissed: () {
        _normalShowing = false;
        _showNextNormal();
      },
    );
    _onlyRefreshToast = active == _onlyRefreshToast ? null : _onlyRefreshToast;
  }

  void _showOnlyRefresh(_ToastRequest request) {
    final active = _onlyRefreshToast;
    if (active != null && _activeToasts.contains(active)) {
      active.timer.cancel();
      active.toast.show(request.param);
      active.attach(request);
      active.timer = _autoDismissTimer(active, request.param.displayTime);
      return;
    }

    dismiss(closeAll: true);
    _onlyRefreshToast = _showStandalone(request);
  }

  _ActiveToast _showStandalone(
    _ToastRequest request, {
    VoidCallback? onDismissed,
  }) {
    final toast = CustomToast.create();
    toast.show(_stackedParam(request.param, _activeToasts.length));
    final active = _ActiveToast(toast: toast, onDismissed: onDismissed);
    active.attach(request);
    active.timer = _autoDismissTimer(active, request.param.displayTime);
    _activeToasts.add(active);
    return active;
  }

  ShowToastParam _stackedParam(ShowToastParam param, int stackIndex) {
    if (param.displayType != ToastDisplayType.multi || stackIndex == 0) {
      return param;
    }

    final offset = _stackOffset(param.alignment, stackIndex);
    return ShowToastParam(
      builder:
          (context) => Transform.translate(
            offset: offset,
            child: param.builder(context),
          ),
      alignment: param.alignment,
      clickMaskDismiss: param.clickMaskDismiss,
      animationType: param.animationType,
      nonAnimationTypes: param.nonAnimationTypes,
      animationBuilder: param.animationBuilder,
      usePenetrate: param.usePenetrate,
      useAnimation: param.useAnimation,
      animationTime: param.animationTime,
      maskColor: param.maskColor,
      maskWidget: param.maskWidget,
      onDismiss: param.onDismiss,
      onMask: param.onMask,
      awaitCompletion: param.awaitCompletion,
      displayTime: param.displayTime,
      debounceTime: param.debounceTime,
      debounce: param.debounce,
      displayType: param.displayType,
      consumeEvent: param.consumeEvent,
    );
  }

  Offset _stackOffset(Alignment alignment, int stackIndex) {
    const gap = 56.0;
    final distance = gap * stackIndex;
    if (alignment.y > 0) {
      return Offset(0, -distance);
    }
    return Offset(0, distance);
  }

  Timer _autoDismissTimer(_ActiveToast active, Duration displayTime) {
    return Timer(displayTime, () async {
      if (!_activeToasts.remove(active)) {
        return;
      }
      if (_onlyRefreshToast == active) {
        _onlyRefreshToast = null;
      }
      await active.toast.dismiss();
      active.completeDismiss();
      active.onDismissed?.call();
    });
  }

  Duration _openDuration(ShowToastParam param) {
    if (!param.useAnimation ||
        param.nonAnimationTypes.contains(NonAnimationType.open)) {
      return Duration.zero;
    }
    return param.animationTime;
  }
}

class _ActiveToast {
  _ActiveToast({required this.toast, required this.onDismissed});

  final CustomToast toast;
  late Timer timer;
  final VoidCallback? onDismissed;
  final List<_ToastRequest> _requests = <_ToastRequest>[];

  void attach(_ToastRequest request) {
    _requests.add(request);
    request.completeAppear();
  }

  void completeDismiss() {
    for (final request in _requests) {
      request.completeDismiss();
    }
    _requests.clear();
  }
}

class _ToastRequest {
  _ToastRequest(this.param);

  final ShowToastParam param;
  final Completer<void> _appearCompleter = Completer<void>();
  final Completer<void> _dismissCompleter = Completer<void>();

  Future<T?> future<T>() {
    return switch (param.awaitCompletion) {
      AwaitCompletion.dismiss => _dismissCompleter.future.then((_) => null),
      AwaitCompletion.appear => _appearCompleter.future.then((_) => null),
      AwaitCompletion.none => Future<T?>.value(),
    };
  }

  void completeAppear() {
    if (_appearCompleter.isCompleted) {
      return;
    }

    if (param.awaitCompletion != AwaitCompletion.appear) {
      _appearCompleter.complete();
      return;
    }

    Timer(ToastTool.instance._openDuration(param), () {
      if (!_appearCompleter.isCompleted) {
        _appearCompleter.complete();
      }
    });
  }

  void completeDismiss() {
    if (!_appearCompleter.isCompleted) {
      _appearCompleter.complete();
    }
    if (!_dismissCompleter.isCompleted) {
      _dismissCompleter.complete();
    }
  }
}
