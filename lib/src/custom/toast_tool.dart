import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

import '../config/enum_config.dart';
import '../data/show_param.dart';
import '../kit/debounce_utils.dart';
import 'custom_toast.dart';

class ToastShowResult<T> {
  const ToastShowResult({
    required this.visible,
    required this.closed,
    this.dismissTag,
  });

  final Future<void> visible;
  final Future<T?> closed;
  final String? dismissTag;
}

class ToastTool {
  ToastTool._();

  static final ToastTool instance = ToastTool._();

  final Queue<_ToastRequest> _normalQueue = ListQueue<_ToastRequest>();
  final List<_ActiveToast> _activeToasts = <_ActiveToast>[];

  bool _normalShowing = false;
  _ActiveToast? _onlyRefreshToast;

  bool get isExist => _activeToasts.isNotEmpty || _normalQueue.isNotEmpty;
  bool hasTag(String tag) {
    return _normalQueue.any((request) => request.matchesTag(tag)) ||
        _activeToasts.any((active) => active.matchesTag(tag));
  }

  bool isActiveTag(String tag) {
    return _activeToasts.any((active) => active.matchesTag(tag));
  }

  Future<T?> show<T>(ShowToastParam param) {
    return showCommand<T>(param).closed;
  }

  ToastShowResult<T> showCommand<T>(ShowToastParam param) {
    if (DebounceUtils.instance.banContinue(
      OverlayDebounceType.toast,
      debounce: param.debounce,
      duration: param.debounceTime,
    )) {
      return ToastShowResult<T>(
        visible: Future<void>.value(),
        closed: Future<T?>.value(),
      );
    }

    final lookupTag = param.businessTag ?? param.tag;
    if (lookupTag != null) {
      if (param.replaceExisting) {
        final visible = Completer<void>();
        final closed = () async {
          try {
            await dismiss(tag: lookupTag);
            final result = _show<T>(param);
            unawaited(
              result.visible.then(
                (_) {
                  if (!visible.isCompleted) {
                    visible.complete();
                  }
                },
                onError: (Object error, StackTrace stackTrace) {
                  if (!visible.isCompleted) {
                    visible.completeError(error, stackTrace);
                  }
                },
              ),
            );
            return await result.closed;
          } catch (error, stackTrace) {
            if (!visible.isCompleted) {
              visible.completeError(error, stackTrace);
            }
            rethrow;
          }
        }();
        return ToastShowResult<T>(visible: visible.future, closed: closed);
      } else if (param.keepSingle) {
        final existing = _findTaggedRequest(lookupTag);
        if (existing != null) {
          return ToastShowResult<T>(
            visible: existing.visible,
            closed: existing.future<T>(),
            dismissTag: existing.param.tag,
          );
        }
      }
    }

    return _show<T>(param);
  }

  ToastShowResult<T> _show<T>(ShowToastParam param) {
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
    return ToastShowResult<T>(
      visible: request.visible,
      closed: request.future<T>(),
      dismissTag: request.param.tag,
    );
  }

  Future<void> dismiss({bool closeAll = false, String? tag}) async {
    if (closeAll) {
      reset();
      return;
    }

    if (tag != null) {
      await _dismissTagged(tag);
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

  Future<void> _dismissTagged(String tag) async {
    final queued = _normalQueue
        .where((request) => request.matchesTag(tag))
        .toList(growable: false);
    for (final request in queued) {
      _normalQueue.remove(request);
      request.completeDismiss();
    }

    final activeToasts = _activeToasts
        .where((active) => active.matchesTag(tag))
        .toList(growable: false);
    for (final active in activeToasts) {
      if (!_activeToasts.remove(active)) {
        continue;
      }
      if (_onlyRefreshToast == active) {
        _onlyRefreshToast = null;
      }
      active.timer.cancel();
      await active.toast.dismiss();
      active.completeDismiss();
      active.onDismissed?.call();
    }
  }

  _ToastRequest? _findTaggedRequest(String tag) {
    for (final active in _activeToasts.reversed) {
      final request = active.requestForTag(tag);
      if (request != null) {
        return request;
      }
    }
    final queued = _normalQueue.toList(growable: false);
    for (var index = queued.length - 1; index >= 0; index--) {
      final request = queued[index];
      if (request.matchesTag(tag)) {
        return request;
      }
    }
    return null;
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
      tag: param.tag,
      businessTag: param.businessTag,
      keepSingle: param.keepSingle,
      replaceExisting: param.replaceExisting,
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

  bool matchesTag(String tag) {
    return _requests.any((request) => request.matchesTag(tag));
  }

  _ToastRequest? requestForTag(String tag) {
    for (final request in _requests.reversed) {
      if (request.matchesTag(tag)) {
        return request;
      }
    }
    return null;
  }
}

class _ToastRequest {
  _ToastRequest(this.param);

  final ShowToastParam param;
  final Completer<void> _appearCompleter = Completer<void>();
  final Completer<void> _dismissCompleter = Completer<void>();

  bool matchesTag(String tag) => param.tag == tag || param.businessTag == tag;
  Future<void> get visible => _appearCompleter.future;

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
