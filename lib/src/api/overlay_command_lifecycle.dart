part of '../super_overlay_core.dart';

var _nextCommandTagId = 0;

String _commandTag(String kind) {
  return '_super_overlay_command_${kind}_${_nextCommandTagId++}';
}

OverlayHandle<T> _overlayHandle<T>({
  required int generation,
  Future<void>? visible,
  required Future<T?> closed,
  required DismissStatus status,
  required bool Function() isVisible,
  String? tag,
  Future<void> Function([T? result])? close,
  required VoidCallback refresh,
}) {
  var isClosed = false;
  final trackedClosed = closed.whenComplete(() {
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

  return OverlayHandle<T>(
    visible: visible ?? Future<void>.value(),
    closed: trackedClosed,
    close: requestClose,
    refresh:
        () => OverlayManager.instance.refreshForGeneration(generation, refresh),
    isVisible:
        () =>
            !isClosed &&
            OverlayManager.instance.ownsGeneration(generation) &&
            isVisible(),
  );
}

class _CommandOverlayLifecycle<T> {
  _CommandOverlayLifecycle({
    required this.generation,
    required this.fire,
    required this.status,
    required this.tag,
    String? replaceTag,
    required this.strategy,
  }) : replaceTag = replaceTag ?? tag;

  final OverlayRuntimeResult<T> Function() fire;
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

  Future<void> get visible => _visible.future;
  Future<T?> get closed => _closed.future;
  bool get isQueued => _fireStarted && !_visible.isCompleted;
  String get activeTag => _identityTag;

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
      final result = await fired.closed;
      if (!_visible.isCompleted) {
        _failVisible();
      }
      if (!_closed.isCompleted) {
        _closed.complete(result);
      }
    } catch (error, stackTrace) {
      if (!_visible.isCompleted) {
        _visible.completeError(error, stackTrace);
      }
      if (!_closed.isCompleted) {
        _closed.completeError(error, stackTrace);
      }
    }
  }

  Future<OverlayRuntimeResult<T>?> _replaceAndFire() async {
    if (_closeRequested) {
      return _fireIfOpen();
    }
    await OverlayManager.instance.dismissReplacementMatches(
      status: status,
      businessTag: replaceTag,
      generation: generation,
    );
    return _fireIfOpen();
  }

  OverlayRuntimeResult<T>? _fireIfOpen() {
    if (_closeRequested) {
      if (!_visible.isCompleted) {
        _failVisible();
      }
      if (!_closed.isCompleted) {
        _closed.complete(_closeResult);
      }
      return null;
    }

    if (!OverlayManager.instance.ownsGeneration(generation)) {
      _failVisible();
      if (!_closed.isCompleted) {
        _closed.complete(_closeResult);
      }
      return null;
    }

    _fireStarted = true;
    OverlayManager.instance.requireActiveGenerationMatch(generation);
    return fire();
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
