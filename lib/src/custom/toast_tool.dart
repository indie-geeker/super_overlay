import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

import '../config/enum_config.dart';
import '../data/show_param.dart';
import '../helper/overlay_manager.dart';
import '../kit/debounce_utils.dart';
import '../kit/overlay_runtime_result.dart';
import '../widget/helper/toast_stack_layout.dart';
import 'custom_toast.dart';

enum _ToastTagMatch { any, identity, business }

class ToastTool {
  ToastTool._();

  static final ToastTool instance = ToastTool._();

  final Queue<_ToastRequest> _normalQueue = ListQueue<_ToastRequest>();
  final List<_ActiveToast> _activeToasts = <_ActiveToast>[];
  final Set<_ActiveToast> _inFlightToasts = <_ActiveToast>{};
  final ToastStackLayout _stackLayout = ToastStackLayout();

  int? _normalLaneGeneration;
  _ActiveToast? _onlyRefreshToast;

  bool isExist(int generation) {
    return _normalQueue.any((request) => request.generation == generation) ||
        _activeToasts.any((active) => active.generation == generation) ||
        _inFlightToasts.any((active) => active.generation == generation);
  }

  bool hasTag(String tag, {required int generation}) {
    return _normalQueue.any(
          (request) =>
              request.generation == generation && request.matchesTag(tag),
        ) ||
        _activeToasts.any(
          (active) => active.generation == generation && active.matchesTag(tag),
        ) ||
        _inFlightToasts.any(
          (active) => active.generation == generation && active.matchesTag(tag),
        );
  }

  bool isActiveTag(String tag, {required int generation}) {
    return _activeToasts.any(
      (active) => active.generation == generation && active.matchesTag(tag),
    );
  }

  bool isActiveIdentityTag(String tag, {required int generation}) {
    return _activeToasts.any(
      (active) =>
          active.generation == generation &&
          active.matchesTag(tag, match: _ToastTagMatch.identity),
    );
  }

  Future<T?> show<T>(ShowToastParam param, {required int generation}) {
    return showCommand<T>(param, generation: generation).closed;
  }

  OverlayRuntimeResult<T> showCommand<T>(
    ShowToastParam param, {
    required int generation,
  }) {
    OverlayManager.instance.requireActiveGenerationMatch(generation);
    if (DebounceUtils.instance.banContinue(
      OverlayDebounceType.toast,
      debounce: param.debounce,
      duration: param.debounceTime,
    )) {
      return OverlayRuntimeResult<T>(
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
            await dismiss(generation: generation, tag: lookupTag);
            if (!OverlayManager.instance.ownsGeneration(generation)) {
              _failBeforeFirstFrame(visible);
              return null;
            }
            final result = _show<T>(param, generation);
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
        return OverlayRuntimeResult<T>(
          visible: visible.future,
          closed: closed,
          refresh: param.controller?.refresh,
        );
      } else if (param.keepSingle) {
        final existing = _findTaggedRequest(
          lookupTag,
          generation,
          match:
              param.businessTag == null
                  ? _ToastTagMatch.any
                  : _ToastTagMatch.business,
        );
        if (existing != null) {
          return OverlayRuntimeResult<T>.lazyClosed(
            visible: existing.visible,
            closed:
                existing.param.awaitCompletion == AwaitCompletion.dismiss
                    ? _closedReader<T>(existing.dismissalSignal)
                    : existing.future<T>,
            identityTag: existing.param.tag,
            refresh: existing.param.controller?.refresh,
          );
        }
      }
    }

    return _show<T>(param, generation);
  }

  OverlayRuntimeResult<T> _show<T>(ShowToastParam param, int generation) {
    OverlayManager.instance.requireActiveGenerationMatch(generation);
    final request = _ToastRequest(param, generation);
    switch (param.displayType) {
      case ToastDisplayType.normal:
        _normalQueue.addLast(request);
        if (_normalLaneGeneration == null) {
          _showNextNormal(generation);
        }
        break;
      case ToastDisplayType.last:
        reset(generation: generation);
        _showStandalone(request);
        break;
      case ToastDisplayType.onlyRefresh:
        _showOnlyRefresh(request);
        break;
      case ToastDisplayType.multi:
        _showStandalone(request);
        break;
    }
    return OverlayRuntimeResult<T>.lazyClosed(
      visible: request.visible,
      closed:
          param.awaitCompletion == AwaitCompletion.dismiss
              ? _closedReader<T>(request.dismissalSignal)
              : request.future<T>,
      identityTag: request.param.tag,
      refresh: request.param.controller?.refresh,
    );
  }

  Future<void> dismiss({
    required int generation,
    bool closeAll = false,
    String? tag,
  }) async {
    if (closeAll) {
      reset(generation: generation);
      return;
    }

    if (tag != null) {
      await _dismissTagged(tag, generation);
      return;
    }

    _ActiveToast? active;
    for (final candidate in _activeToasts) {
      if (candidate.generation == generation) {
        active = candidate;
        break;
      }
    }
    if (active == null) {
      return;
    }

    await _dismissActive(active);
  }

  Future<void> dismissIdentityTag({
    required int generation,
    required String tag,
  }) {
    return _dismissTagged(tag, generation, match: _ToastTagMatch.identity);
  }

  Future<void> dismissBusinessTag({
    required int generation,
    required String tag,
  }) {
    return _dismissTagged(tag, generation, match: _ToastTagMatch.business);
  }

  void reset({int? generation}) {
    bool matchesGeneration(int candidate) {
      return generation == null || candidate == generation;
    }

    final activeToasts = <_ActiveToast>{
      ..._activeToasts.where((active) => matchesGeneration(active.generation)),
      ..._inFlightToasts.where(
        (active) => matchesGeneration(active.generation),
      ),
    };
    for (final active in activeToasts) {
      _finalizeImmediately(active);
    }

    final queued = _normalQueue
        .where((request) => matchesGeneration(request.generation))
        .toList(growable: false);
    for (final request in queued) {
      _normalQueue.remove(request);
      request.completeDismiss();
    }

    if (generation == null || _normalLaneGeneration == generation) {
      _normalLaneGeneration = null;
    }
    if (generation == null || _onlyRefreshToast?.generation == generation) {
      _onlyRefreshToast = null;
    }
  }

  Future<void> _dismissTagged(
    String tag,
    int generation, {
    _ToastTagMatch match = _ToastTagMatch.any,
  }) async {
    final queued = _normalQueue
        .where(
          (request) =>
              request.generation == generation &&
              request.matchesTag(tag, match: match),
        )
        .toList(growable: false);
    for (final request in queued) {
      _normalQueue.remove(request);
      request.completeDismiss();
    }

    final activeToasts = _activeToasts
        .where(
          (active) =>
              active.generation == generation &&
              active.matchesTag(tag, match: match),
        )
        .toList(growable: false);
    final inFlightToasts = _inFlightToasts
        .where(
          (active) =>
              active.generation == generation &&
              active.matchesTag(tag, match: match),
        )
        .toList(growable: false);
    for (final active in activeToasts) {
      await _dismissActive(active);
    }
    for (final active in inFlightToasts) {
      final dismissal = active.dismissal;
      if (dismissal != null) {
        await dismissal;
      }
    }
  }

  _ToastRequest? _findTaggedRequest(
    String tag,
    int generation, {
    _ToastTagMatch match = _ToastTagMatch.any,
  }) {
    for (final active in _activeToasts.reversed) {
      if (active.generation != generation) {
        continue;
      }
      final request = active.requestForTag(tag, match: match);
      if (request != null) {
        return request;
      }
    }
    final queued = _normalQueue.toList(growable: false);
    for (var index = queued.length - 1; index >= 0; index--) {
      final request = queued[index];
      if (request.generation == generation &&
          request.matchesTag(tag, match: match)) {
        return request;
      }
    }
    return null;
  }

  void _showNextNormal(int generation) {
    if (!OverlayManager.instance.ownsGeneration(generation)) {
      return;
    }

    _ToastRequest? request;
    for (final candidate in _normalQueue) {
      if (candidate.generation == generation) {
        request = candidate;
        break;
      }
    }
    if (request == null) {
      if (_normalLaneGeneration == generation) {
        _normalLaneGeneration = null;
      }
      return;
    }

    _normalQueue.remove(request);
    _normalLaneGeneration = generation;
    _showStandalone(
      request,
      onDismissed: () {
        if (_normalLaneGeneration != generation ||
            !OverlayManager.instance.ownsGeneration(generation)) {
          return;
        }
        _normalLaneGeneration = null;
        _showNextNormal(generation);
      },
    );
  }

  void _showOnlyRefresh(_ToastRequest request) {
    final active = _onlyRefreshToast;
    if (active != null &&
        active.generation == request.generation &&
        _activeToasts.contains(active)) {
      active.timer.cancel();
      active.toast.stackEntry.alignment = request.param.alignment;
      active.attach(request);
      active.toast.show(
        request.param,
        onMask: _ToastCallbackOwner(active).maskCallback(
          onMask: request.param.onMask,
          dismissible: request.param.clickMaskDismiss,
        ),
      );
      active.timer = _autoDismissTimer(active, request.param.displayTime);
      return;
    }

    reset(generation: request.generation);
    _onlyRefreshToast = _showStandalone(request);
  }

  _ActiveToast _showStandalone(
    _ToastRequest request, {
    VoidCallback? onDismissed,
  }) {
    OverlayManager.instance.requireActiveGenerationMatch(request.generation);
    final toast = CustomToast.create(
      generation: request.generation,
      stackEntry: _stackLayout.add(request.param.alignment),
    );
    final active = _ActiveToast(
      generation: request.generation,
      toast: toast,
      onDismissed: onDismissed,
    );
    active.attach(request);
    toast.show(
      request.param,
      onMask: _ToastCallbackOwner(active).maskCallback(
        onMask: request.param.onMask,
        dismissible: request.param.clickMaskDismiss,
      ),
    );
    active.timer = _autoDismissTimer(active, request.param.displayTime);
    _activeToasts.add(active);
    return active;
  }

  Future<void> _dismissActive(_ActiveToast active) {
    final existing = active.dismissal;
    if (existing != null) {
      return existing;
    }
    final dismissal = active.beginDismissal();
    unawaited(_runDismissActive(active));
    return dismissal;
  }

  Future<void> _runDismissActive(_ActiveToast active) async {
    if (!active.beginFinalization()) {
      return;
    }
    _prepareFinalization(active, trackInFlight: true);
    try {
      await active.toast.dismiss();
    } catch (error, stackTrace) {
      active.completeDismissalError(error, stackTrace);
    } finally {
      _completeFinalization(active, advanceLane: true);
    }
  }

  void _finalizeImmediately(_ActiveToast active) {
    active.invalidate();
    active.beginFinalization();
    _prepareFinalization(active, trackInFlight: false);
    active.toast.disposeImmediately();
    _completeFinalization(active, advanceLane: false);
  }

  void _prepareFinalization(
    _ActiveToast active, {
    required bool trackInFlight,
  }) {
    _activeToasts.remove(active);
    if (trackInFlight) {
      _inFlightToasts.add(active);
    } else {
      _inFlightToasts.remove(active);
    }
    if (identical(_onlyRefreshToast, active)) {
      _onlyRefreshToast = null;
    }
    active.timer.cancel();
  }

  void _completeFinalization(_ActiveToast active, {required bool advanceLane}) {
    _inFlightToasts.remove(active);
    active.completeDismiss();
    active.completeDismissal();
    if (!active.finishFinalization()) {
      return;
    }
    if (advanceLane &&
        !active.invalidated &&
        OverlayManager.instance.ownsGeneration(active.generation)) {
      active.notifyDismissed();
    }
  }

  Timer _autoDismissTimer(_ActiveToast active, Duration displayTime) {
    return Timer(displayTime, () {
      if (!_activeToasts.contains(active) ||
          !OverlayManager.instance.ownsGeneration(active.generation)) {
        return;
      }
      unawaited(_dismissActive(active));
    });
  }

  Duration _openDuration(ShowToastParam param) {
    if (!param.useAnimation ||
        param.nonAnimationTypes.contains(NonAnimationType.open)) {
      return Duration.zero;
    }
    return param.animationTime;
  }

  void _failBeforeFirstFrame(Completer<void> visible) {
    if (!visible.isCompleted) {
      visible.completeError(
        StateError('The overlay closed before its first rendered frame.'),
      );
    }
  }
}

// Allocate this closure outside the request/content factory's lexical scope.
// Unobserved refresh commands must not register listeners on the shared lane.
Future<T?> Function() _closedReader<T>(Future<void> signal) =>
    () => signal.then<T?>((_) => null);

// Callback ownership is narrower than the shared lane-close signal. A refresh
// keeps historical close futures alive, but replaces the interactive content.
class _ToastCallbackOwner {
  _ToastCallbackOwner(_ActiveToast active)
    : _active = WeakReference(active),
      _presentation = active.callbackPresentation,
      _generation = active.generation;

  final WeakReference<_ActiveToast> _active;
  final Object _presentation;
  final int _generation;

  _ActiveToast? get _current {
    final active = _active.target;
    if (active == null ||
        !OverlayManager.instance.ownsGeneration(_generation) ||
        !identical(active.callbackPresentation, _presentation)) {
      return null;
    }
    final tool = ToastTool.instance;
    return tool._activeToasts.contains(active) ||
            tool._inFlightToasts.contains(active)
        ? active
        : null;
  }

  VoidCallback maskCallback({
    required VoidCallback? onMask,
    required bool dismissible,
  }) => () {
    final active = _current;
    if (active == null) return;
    if (active.dismissal != null) {
      if (dismissible) unawaited(ToastTool.instance._dismissActive(active));
      return;
    }
    onMask?.call();
    if (!dismissible || !identical(_current, active)) return;
    unawaited(ToastTool.instance._dismissActive(active));
  };
}

class _ActiveToast {
  _ActiveToast({
    required this.generation,
    required this.toast,
    required this.onDismissed,
  });

  final int generation;
  final CustomToast toast;
  late Timer timer;
  final VoidCallback? onDismissed;
  final Completer<void> _contentDismissed = Completer<void>();
  _ToastRequest? _currentRequest;
  Object callbackPresentation = Object();
  Completer<void>? _dismissCompleter;
  bool invalidated = false;
  bool _finalizationStarted = false;
  bool _finalized = false;
  bool _dismissNotificationSent = false;

  Future<void>? get dismissal => _dismissCompleter?.future;

  void attach(_ToastRequest request) {
    if (request.generation != generation) {
      throw StateError(
        'Cannot attach a toast request from another generation.',
      );
    }
    request.shareDismissal(_contentDismissed.future);
    _currentRequest = request;
    callbackPresentation = Object();
    request.completeAppear();
  }

  void invalidate() {
    invalidated = true;
  }

  Future<void> beginDismissal() {
    return (_dismissCompleter ??= Completer<void>()).future;
  }

  void completeDismissal() {
    final completer = _dismissCompleter ??= Completer<void>();
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  void completeDismissalError(Object error, StackTrace stackTrace) {
    final completer = _dismissCompleter ??= Completer<void>();
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
  }

  bool beginFinalization() {
    if (_finalizationStarted || _finalized) {
      return false;
    }
    _finalizationStarted = true;
    return true;
  }

  bool finishFinalization() {
    if (_finalized) {
      return false;
    }
    _finalized = true;
    return true;
  }

  void notifyDismissed() {
    if (_dismissNotificationSent) {
      return;
    }
    _dismissNotificationSent = true;
    onDismissed?.call();
  }

  void completeDismiss() {
    // Queued requests may have exposed their own future before attaching.
    _currentRequest?.completeDismiss();
    _currentRequest = null;
    if (!_contentDismissed.isCompleted) {
      _contentDismissed.complete();
    }
  }

  bool matchesTag(String tag, {_ToastTagMatch match = _ToastTagMatch.any}) {
    return _currentRequest?.matchesTag(tag, match: match) ?? false;
  }

  _ToastRequest? requestForTag(
    String tag, {
    _ToastTagMatch match = _ToastTagMatch.any,
  }) {
    final request = _currentRequest;
    if (request != null && request.matchesTag(tag, match: match)) {
      return request;
    }
    return null;
  }
}

class _ToastRequest {
  _ToastRequest(this.param, this.generation);

  final ShowToastParam param;
  final int generation;
  final Completer<void> _appearCompleter = Completer<void>();
  final Completer<void> _dismissCompleter = Completer<void>();
  Future<void>? _sharedDismissal;

  void shareDismissal(Future<void> dismissed) {
    _sharedDismissal = dismissed;
    if (param.awaitCompletion == AwaitCompletion.appear) {
      // Preserve early-close settlement without retaining this content request.
      final appear = _appearCompleter;
      unawaited(
        dismissed.then<void>((_) {
          if (!appear.isCompleted) appear.complete();
        }),
      );
    }
  }

  bool matchesTag(String tag, {_ToastTagMatch match = _ToastTagMatch.any}) {
    return switch (match) {
      _ToastTagMatch.identity => param.tag == tag,
      _ToastTagMatch.business => param.businessTag == tag,
      _ToastTagMatch.any => param.tag == tag || param.businessTag == tag,
    };
  }

  Future<void> get visible =>
      param.controller?.visible ?? _appearCompleter.future;

  Future<void> get dismissalSignal =>
      _sharedDismissal ?? _dismissCompleter.future;

  Future<T?> future<T>() {
    return switch (param.awaitCompletion) {
      AwaitCompletion.dismiss => (_sharedDismissal ?? _dismissCompleter.future)
          .then((_) => null),
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
    param.controller?.dismiss();
    if (!_appearCompleter.isCompleted) {
      _appearCompleter.complete();
    }
    if (!_dismissCompleter.isCompleted) {
      _dismissCompleter.complete();
    }
  }
}
