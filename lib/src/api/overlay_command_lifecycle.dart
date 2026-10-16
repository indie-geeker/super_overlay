part of '../super_overlay_core.dart';

var _nextCommandTagId = 0;

String _commandTag(String kind) {
  return '_super_overlay_command_${kind}_${_nextCommandTagId++}';
}

OverlayHandle<T> _overlayHandle<T>({
  required int generation,
  Future<void>? visible,
  Future<T?>? closed,
  Future<T?> Function()? readClosed,
  required DismissStatus status,
  required bool Function() isVisible,
  String? tag,
  Future<void> Function([T? result])? close,
  required VoidCallback refresh,
}) {
  assert((closed == null) != (readClosed == null));
  var isClosed = false;
  Future<T?> trackClosed() => (closed ?? readClosed!()).whenComplete(() {
    isClosed = true;
  });
  Future<void> requestClose([T? result]) {
    if (isClosed) {
      return Future<void>.value();
    }

    final closeOverlay =
        close ??
        ([T? result]) => OverlayManager.instance.dismiss<T>(
          status: status,
          tag: tag,
          result: result,
          generation: generation,
        );
    return closeOverlay(result);
  }

  final visibleFuture = visible ?? Future<void>.value();
  void refreshOverlay() =>
      OverlayManager.instance.refreshForGeneration(generation, refresh);
  bool checkVisible() =>
      !isClosed &&
      OverlayManager.instance.ownsGeneration(generation) &&
      isVisible();
  if (readClosed != null) {
    return OverlayHandle<T>.lazyClosed(
      visible: visibleFuture,
      closed: trackClosed,
      close: requestClose,
      refresh: refreshOverlay,
      isVisible: checkVisible,
    );
  }
  return OverlayHandle<T>(
    visible: visibleFuture,
    closed: trackClosed(),
    close: requestClose,
    refresh: refreshOverlay,
    isVisible: checkVisible,
  );
}

// Keep Loading callbacks outside its default content factory's lexical scope.
OverlayHandle<void> _loadingHandle({
  required int generation,
  required String identityTag,
  required SuperOverlayController controller,
  required Future<void> closed,
}) {
  final manager = OverlayManager.instance;
  return _overlayHandle<void>(
    generation: generation,
    visible: controller.visible,
    closed: closed,
    status: DismissStatus.loading,
    tag: identityTag,
    refresh: controller.refresh,
    close:
        ([void result]) => manager.dismissCommandHandle<void>(
          status: DismissStatus.loading,
          identityTag: identityTag,
          generation: generation,
        ),
    isVisible:
        () => manager.isCommandIdentityVisible(
          identityTag: identityTag,
          generation: generation,
          type: OverlayType.loading,
        ),
  );
}

class _CommandOverlayLifecycle<T> {
  _CommandOverlayLifecycle({
    required this.generation,
    required OverlayRuntimeResult<T> Function() fire,
    required this.status,
    required this.tag,
    String? replaceTag,
    required this.strategy,
    OverlayRouteOwner? routeOwner,
    BuildContext? widgetOwner,
  }) : _fire = fire,
       _routeOwner = routeOwner,
       _widgetOwner = widgetOwner,
       replaceTag = replaceTag ?? tag {
    unawaited(
      _closed.future.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
    );
  }

  OverlayRuntimeResult<T> Function()? _fire;
  OverlayRouteOwner? _routeOwner;
  BuildContext? _widgetOwner;
  final int generation;
  final DismissStatus status;
  final String tag;
  final String replaceTag;
  final OverlayStrategy strategy;
  final Completer<void> _visible = Completer<void>();
  final Completer<T?> _closed = Completer<T?>();
  late String _identityTag = tag;

  bool _closeRequested = false;
  bool _fireStarted = false;
  T? _closeResult;
  VoidCallback? _runtimeRefresh;
  OverlayRuntimeResult<T>? _toastRuntime;
  bool _closedRequested = false;

  Future<void> get visible => _visible.future;
  Future<T?> get closed => readClosed();
  Future<T?> readClosed() {
    final runtime = _toastRuntime;
    if (runtime != null) return runtime.closed;
    _closedRequested = true;
    return _closed.future;
  }

  bool get isQueued => _fireStarted && !_visible.isCompleted;
  String get activeTag => _identityTag;

  bool isVisible() {
    if (status == DismissStatus.toast) {
      return !isQueued &&
          ToastTool.instance.isActiveIdentityTag(
            activeTag,
            generation: generation,
          );
    }
    return OverlayManager.instance.isCommandIdentityVisible(
      identityTag: activeTag,
      generation: generation,
      type: switch (status) {
        DismissStatus.attach => OverlayType.attach,
        DismissStatus.notify => OverlayType.notify,
        _ => OverlayType.custom,
      },
    );
  }

  void refresh() => _runtimeRefresh?.call();

  void start() {
    unawaited(_run());
  }

  Future<void> close([T? result]) {
    if (!_visible.isCompleted && !_fireStarted) {
      _closeRequested = true;
      _closeResult = result;
      return _closed.future.then((_) {});
    }

    return OverlayManager.instance.dismissCommandHandle<T>(
      status: status,
      identityTag: _identityTag,
      result: result,
      generation: generation,
    );
  }

  Future<void> _run() async {
    try {
      final fired =
          strategy == OverlayStrategy.replaceExisting
              ? await _replacementQueue.run(
                '$generation::$status::$replaceTag',
                _replaceAndFire,
              )
              : _fireIfOpen();
      if (fired == null) {
        return;
      }
      _identityTag = fired.identityTag ?? tag;
      _runtimeRefresh = fired.refresh;
      unawaited(
        fired.visible.then(
          (_) {
            if (!_visible.isCompleted) {
              _visible.complete();
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!_visible.isCompleted) {
              _visible.completeError(error, stackTrace);
            }
          },
        ),
      );
      if (status == DismissStatus.toast) {
        _toastRuntime = fired;
        if (_closedRequested) unawaited(_completeClosed(fired.closed));
        return;
      }
      await _completeClosed(fired.closed);
    } catch (error, stackTrace) {
      _fail(error, stackTrace);
    } finally {
      _fire = null;
      _routeOwner = null;
      _widgetOwner = null;
      if (_toastRuntime == null) _runtimeRefresh = null;
    }
  }

  Future<void> _completeClosed(Future<T?> closed) async {
    try {
      final result = await closed;
      if (!_visible.isCompleted) {
        _failVisible();
      }
      if (!_closed.isCompleted) {
        _closed.complete(result);
      }
    } catch (error, stackTrace) {
      _fail(error, stackTrace);
    } finally {
      _runtimeRefresh = null;
    }
  }

  void _fail(Object error, StackTrace stackTrace) {
    if (!_visible.isCompleted) _visible.completeError(error, stackTrace);
    if (!_closed.isCompleted) _closed.completeError(error, stackTrace);
  }

  Future<OverlayRuntimeResult<T>?> _replaceAndFire() async {
    if (!_canFire) {
      return _fireIfOpen();
    }
    await OverlayManager.instance.dismissReplacementMatches(
      status: status,
      businessTag: replaceTag,
      generation: generation,
    );
    return _fireIfOpen();
  }

  bool get _canFire {
    final manager = OverlayManager.instance;
    final owner = _routeOwner;
    final widgetOwner = _widgetOwner;
    return !_closeRequested &&
        manager.ownsGeneration(generation) &&
        (widgetOwner == null || widgetOwner.mounted) &&
        (owner == null ||
            manager.isCommandRouteOwnerAttached(
              generation: generation,
              routeOwner: owner,
            ));
  }

  OverlayRuntimeResult<T>? _fireIfOpen() {
    // A pending closed future must not retain the original content factory.
    final fire = _fire;
    _fire = null;
    final canFire = _canFire;
    // Once activated or cancelled, a retained handle must not retain its owners.
    _routeOwner = null;
    _widgetOwner = null;
    if (!canFire) {
      if (!_visible.isCompleted) {
        _failVisible();
      }
      if (!_closed.isCompleted) {
        _closed.complete(_closeResult);
      }
      return null;
    }

    _fireStarted = true;
    OverlayManager.instance.requireActiveGenerationMatch(generation);
    return fire!();
  }

  void _failVisible() {
    if (!_visible.isCompleted) {
      _visible.completeError(
        StateError('The overlay closed before its first rendered frame.'),
      );
    }
  }
}

final _replacementQueue = _OverlayOperationQueue();

class _OverlayOperationQueue {
  final Map<String, Future<void>> _tails = <String, Future<void>>{};

  Future<T> run<T>(String key, Future<T> Function() operation) async {
    final previous = _tails[key] ?? Future<void>.value();
    final release = Completer<void>();
    final tail = previous.then((_) => release.future);
    _tails[key] = tail;

    await previous;
    try {
      return await operation();
    } finally {
      if (!release.isCompleted) {
        release.complete();
      }
      if (identical(_tails[key], tail)) {
        _tails.remove(key);
      }
    }
  }
}

OverlayHandle<T>? _existingOverlayHandle<T>({
  required int generation,
  required DismissStatus status,
  required String? tag,
  required OverlayStrategy strategy,
  required OverlayType type,
  VoidCallback? refresh,
}) {
  if (tag == null || strategy != OverlayStrategy.keepExisting) {
    return null;
  }

  final manager = OverlayManager.instance;
  final existing = manager.existingCommandOverlay<T>(
    businessTag: tag,
    type: type,
    generation: generation,
  );
  if (existing == null) {
    return null;
  }

  final identityTag = existing.identityTag;

  return _overlayHandle<T>(
    generation: generation,
    visible: existing.visible,
    closed: existing.closed,
    status: status,
    tag: identityTag,
    close:
        ([T? result]) => manager.dismissCommandHandle<T>(
          status: status,
          identityTag: identityTag,
          result: result,
          generation: generation,
        ),
    refresh: existing.refresh ?? refresh ?? () {},
    isVisible:
        () => manager.isCommandIdentityVisible(
          identityTag: identityTag,
          generation: generation,
          type: type,
        ),
  );
}

BackType _backTypeFor(OverlayBackBehavior behavior) {
  return switch (behavior) {
    OverlayBackBehavior.dismiss => BackType.normal,
    OverlayBackBehavior.block => BackType.block,
    OverlayBackBehavior.passThrough => BackType.ignore,
  };
}

ToastDisplayType _toastDisplayTypeFor(OverlayToastDisplayPolicy policy) {
  return switch (policy) {
    OverlayToastDisplayPolicy.queue => ToastDisplayType.normal,
    OverlayToastDisplayPolicy.replaceLatest => ToastDisplayType.last,
    OverlayToastDisplayPolicy.refreshActive => ToastDisplayType.onlyRefresh,
    OverlayToastDisplayPolicy.stack => ToastDisplayType.multi,
  };
}

PopupAlignmentMode _popupAlignmentModeFor(OverlayPopupAlignmentMode mode) {
  return switch (mode) {
    OverlayPopupAlignmentMode.inside => PopupAlignmentMode.inside,
    OverlayPopupAlignmentMode.center => PopupAlignmentMode.center,
    OverlayPopupAlignmentMode.outside => PopupAlignmentMode.outside,
  };
}
