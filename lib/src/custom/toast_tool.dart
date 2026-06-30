import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

import '../config/enum_config.dart';
import '../data/show_param.dart';
import 'custom_toast.dart';

class ToastTool {
  ToastTool._();

  static final ToastTool instance = ToastTool._();

  final Queue<ShowToastParam> _normalQueue = ListQueue<ShowToastParam>();
  final List<_ActiveToast> _activeToasts = <_ActiveToast>[];

  bool _normalShowing = false;
  _ActiveToast? _onlyRefreshToast;

  bool get isExist => _activeToasts.isNotEmpty || _normalQueue.isNotEmpty;

  void show(ShowToastParam param) {
    switch (param.displayType) {
      case ToastDisplayType.normal:
        _normalQueue.addLast(param);
        if (!_normalShowing) {
          _showNextNormal();
        }
        break;
      case ToastDisplayType.last:
        dismiss(closeAll: true);
        _showStandalone(param);
        break;
      case ToastDisplayType.onlyRefresh:
        _showOnlyRefresh(param);
        break;
      case ToastDisplayType.multi:
        _showStandalone(param);
        break;
    }
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
  }

  void reset() {
    for (final active in _activeToasts) {
      active.timer.cancel();
      active.toast.remove();
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
    final param = _normalQueue.removeFirst();
    final active = _showStandalone(
      param,
      onDismissed: () {
        _normalShowing = false;
        _showNextNormal();
      },
    );
    _onlyRefreshToast = active == _onlyRefreshToast ? null : _onlyRefreshToast;
  }

  void _showOnlyRefresh(ShowToastParam param) {
    final active = _onlyRefreshToast;
    if (active != null && _activeToasts.contains(active)) {
      active.timer.cancel();
      active.toast.show(param);
      active.timer = _autoDismissTimer(active, param.displayTime);
      return;
    }

    dismiss(closeAll: true);
    _onlyRefreshToast = _showStandalone(param);
  }

  _ActiveToast _showStandalone(
    ShowToastParam param, {
    VoidCallback? onDismissed,
  }) {
    final toast = CustomToast.create();
    toast.show(_stackedParam(param, _activeToasts.length));
    final active = _ActiveToast(toast: toast, onDismissed: onDismissed);
    active.timer = _autoDismissTimer(active, param.displayTime);
    _activeToasts.add(active);
    return active;
  }

  ShowToastParam _stackedParam(ShowToastParam param, int stackIndex) {
    if (param.displayType != ToastDisplayType.multi || stackIndex == 0) {
      return param;
    }

    final offset = _stackOffset(param.alignment, stackIndex);
    return ShowToastParam(
      builder: (context) =>
          Transform.translate(offset: offset, child: param.builder(context)),
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
      active.onDismissed?.call();
    });
  }
}

class _ActiveToast {
  _ActiveToast({required this.toast, required this.onDismissed});

  final CustomToast toast;
  late Timer timer;
  final VoidCallback? onDismissed;
}
