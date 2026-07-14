part of '../super_overlay_core.dart';

/// Shows and controls command-style loading overlays.
class OverlayLoadingService {
  const OverlayLoadingService();

  /// Shows a loading overlay and returns a handle for closing it.
  OverlayHandle<void> show({
    String message = '',
    WidgetBuilder? builder,
    OverlayLoadingOptions options = const OverlayLoadingOptions(),
  }) {
    final manager = OverlayManager.instance;
    final generation = manager.requireActiveGeneration();
    final backType = _backTypeFor(options.backBehavior);
    manager.validateCommandRoute(
      generation: generation,
      bindToRoute: false,
      backType: backType,
      onBack: null,
      operation: 'SuperOverlay loading',
    );
    final hostBuilder = manager.loadingBuilderFor(generation);
    final controller = SuperOverlayController();
    final command = SuperOverlay._loading(
          message: message,
          builder:
              builder ??
              (hostBuilder == null ? null : (_) => hostBuilder(message)),
        )
        .withMask(dismissible: options.dismissOnMaskTap)
        .withLeastLoadingTime(options.minimumVisibleDuration)
        .withAccessibility(
          requestFocus: options.requestFocus,
          semanticsLabel: options.semanticsLabel,
          barrierSemanticsLabel: options.barrierSemanticsLabel,
        )
        .withController(controller)
        .withBack(type: backType)
        .withAwait(AwaitCompletion.dismiss);

    final identityTag = _commandTag('loading');
    command.withTag(identityTag)._withBusinessTag(options.tag);

    final displayDuration = options.displayDuration;
    if (displayDuration != null) {
      command.withDisplayTime(displayDuration);
    }

    final runtime = OverlayRuntimeResult<void>(
      visible: controller.visible,
      closed: command.fire<void>(),
      identityTag: identityTag,
    );
    return _overlayHandle<void>(
      generation: generation,
      visible: runtime.visible,
      closed: runtime.closed,
      status: DismissStatus.loading,
      tag: runtime.identityTag,
      close:
          ([void result]) => manager.dismiss<void>(
            status: DismissStatus.loading,
            tag: identityTag,
            generation: generation,
          ),
      isVisible:
          () => manager.checkExist(
            tag: identityTag,
            generation: generation,
            types: const {OverlayType.loading},
          ),
    );
  }

  /// Closes the active loading overlay.
  Future<void> close() {
    OverlayManager.instance.requireActiveGeneration();
    return SuperOverlay._dismiss(status: DismissStatus.loading);
  }
}

/// Shows command-style dialog overlays.
class OverlayDialogService {
  const OverlayDialogService();

  /// Shows a dialog overlay and returns a handle for its result.
  OverlayHandle<T> show<T>({
    required WidgetBuilder builder,
    OverlayDialogOptions options = const OverlayDialogOptions(),
  }) {
    return _show<T>(builder: builder, options: options);
  }

  OverlayHandle<T> _show<T>({
    required WidgetBuilder builder,
    required OverlayDialogOptions options,
    OverlayRouteOwner? routeOwner,
  }) {
    final manager = OverlayManager.instance;
    final generation = manager.requireActiveGeneration();
    final backType = _backTypeFor(options.backBehavior);
    final capturedOwner =
        routeOwner ??
        (options.bindToRoute
            ? manager.captureRootRouteOwner(
              generation: generation,
              operation: 'SuperOverlay dialog',
            )
            : null);
    manager.validateCommandRoute(
      generation: generation,
      bindToRoute: options.bindToRoute,
      backType: backType,
      onBack: null,
      operation: 'SuperOverlay dialog',
      routeOwner: capturedOwner,
    );
    final controller = SuperOverlayController();
    final command = SuperOverlay._custom(
          builder: builder,
          routeOwner: capturedOwner,
        )
        .withAlignment(options.alignment)
        .withMask(
          color: options.barrierColor,
          dismissible: options.dismissOnMaskTap,
        )
        .bindPage(options.bindToRoute)
        .withPenetrate(!options.consumeEvents)
        .withAccessibility(
          requestFocus: options.requestFocus,
          semanticsLabel: options.semanticsLabel,
          barrierSemanticsLabel: options.barrierSemanticsLabel,
        )
        .withController(controller)
        .withBack(type: backType)
        .withAwait(AwaitCompletion.dismiss);

    final bindToWidget = options.bindToWidget;
    if (bindToWidget != null) {
      command.bindWidget(bindToWidget);
    }

    final tag = options.tag;
    final identityTag = _commandTag('dialog');
    command.withTag(identityTag)._withBusinessTag(tag);

    final existing = _existingOverlayHandle<T>(
      generation: generation,
      status: DismissStatus.custom,
      tag: tag,
      strategy: options.strategy,
      type: OverlayType.custom,
      refresh: controller.refresh,
    );
    if (existing != null) {
      return existing;
    }

    final displayDuration = options.displayDuration;
    if (displayDuration != null) {
      command.withDisplayTime(displayDuration);
    }

    final lifecycle = _CommandOverlayLifecycle<T>(
      generation: generation,
      fire:
          () => OverlayRuntimeResult<T>(
            visible: controller.visible,
            closed: command.fire<T>(),
          ),
      status: DismissStatus.custom,
      tag: identityTag,
      replaceTag: tag,
      strategy: options.strategy,
    );
    lifecycle.start();
    return _overlayHandle<T>(
      generation: generation,
      visible: lifecycle.visible,
      closed: lifecycle.closed,
      status: DismissStatus.custom,
      tag: identityTag,
      close: lifecycle.close,
      refresh: controller.refresh,
      isVisible:
          () => manager.isDialogVisible(
            tag: identityTag,
            generation: generation,
            type: OverlayType.custom,
          ),
    );
  }
}

/// Shows command-style popup overlays.
class OverlayPopupService {
  const OverlayPopupService();

  /// Shows a popup overlay and returns a handle for its result.
  OverlayHandle<T> show<T>({
    BuildContext? targetContext,
    required WidgetBuilder builder,
    OverlayPopupOptions options = const OverlayPopupOptions(),
  }) {
    return _show<T>(
      targetContext: targetContext,
      builder: builder,
      options: options,
    );
  }

  OverlayHandle<T> _show<T>({
    BuildContext? targetContext,
    required WidgetBuilder builder,
    required OverlayPopupOptions options,
    OverlayRouteOwner? routeOwner,
  }) {
    final manager = OverlayManager.instance;
    final generation = manager.requireActiveGeneration();
    final backType = _backTypeFor(options.backBehavior);
    final capturedOwner =
        routeOwner ??
        (options.bindToRoute
            ? manager.captureRootRouteOwner(
              generation: generation,
              operation: 'SuperOverlay popup',
            )
            : null);
    manager.validateCommandRoute(
      generation: generation,
      bindToRoute: options.bindToRoute,
      backType: backType,
      onBack: null,
      operation: 'SuperOverlay popup',
      routeOwner: capturedOwner,
    );
    final controller = SuperOverlayController();
    final command = SuperOverlay._popup(
          targetContext: targetContext,
          builder: builder,
          routeOwner: capturedOwner,
        )
        .withAlignment(options.alignment)
        .withMask(dismissible: options.dismissOnMaskTap)
        .bindPage(options.bindToRoute)
        .withAccessibility(requestFocus: options.requestFocus)
        .withController(controller)
        .withBack(type: backType)
        .withAwait(AwaitCompletion.dismiss);

    final targetRectBuilder = options.targetRectBuilder;
    if (targetRectBuilder != null) {
      command.withTargetRect(targetRectBuilder);
    }
    final targetPointBuilder = options.targetPointBuilder;
    if (targetPointBuilder != null) {
      command.withTargetPoint(targetPointBuilder);
    }
    final alignmentMode = options.alignmentMode;
    if (alignmentMode != null) {
      command.withAlignmentMode(_popupAlignmentModeFor(alignmentMode));
    }
    final replacementBuilder = options.replacementBuilder;
    if (replacementBuilder != null) {
      command.withReplacement(replacementBuilder);
    }
    final adjustmentBuilder = options.adjustmentBuilder;
    if (adjustmentBuilder != null) {
      command.withAdjustment(adjustmentBuilder);
    }
    final scaleOriginBuilder = options.scaleOriginBuilder;
    if (scaleOriginBuilder != null) {
      command.withScaleOrigin(scaleOriginBuilder);
    }

    final tag = options.tag;
    final identityTag = _commandTag('popup');
    command.withTag(identityTag)._withBusinessTag(tag);

    final existing = _existingOverlayHandle<T>(
      generation: generation,
      status: DismissStatus.attach,
      tag: tag,
      strategy: options.strategy,
      type: OverlayType.attach,
      refresh: controller.refresh,
    );
    if (existing != null) {
      return existing;
    }
    final displayDuration = options.displayDuration;
    if (displayDuration != null) {
      command.withDisplayTime(displayDuration);
    }
    if (options.highlightTarget) {
      command.withHighlight(
        maskColor: options.highlightMaskColor,
        padding: options.highlightPadding,
        borderRadius: options.highlightBorderRadius,
      );
    }
    final maskIgnoreArea = options.maskIgnoreArea;
    if (maskIgnoreArea != null) {
      command.withMaskIgnoreArea(maskIgnoreArea);
    }

    final lifecycle = _CommandOverlayLifecycle<T>(
      generation: generation,
      fire:
          () => OverlayRuntimeResult<T>(
            visible: controller.visible,
            closed: command.fire<T>(),
          ),
      status: DismissStatus.attach,
      tag: identityTag,
      replaceTag: tag,
      strategy: options.strategy,
    );
    lifecycle.start();
    return _overlayHandle<T>(
      generation: generation,
      visible: lifecycle.visible,
      closed: lifecycle.closed,
      status: DismissStatus.attach,
      tag: identityTag,
      close: lifecycle.close,
      refresh: controller.refresh,
      isVisible:
          () => manager.isDialogVisible(
            tag: identityTag,
            generation: generation,
            type: OverlayType.attach,
          ),
    );
  }
}

/// Shows command-style notification overlays.
class OverlayNotifyService {
  const OverlayNotifyService();

  /// Shows a success notification.
  OverlayHandle<void> success(
    String message, {
    WidgetBuilder? builder,
    OverlayNotifyOptions options = const OverlayNotifyOptions(),
  }) {
    return _show(message, NotifyType.success, builder, options);
  }

  /// Shows a failure notification.
  OverlayHandle<void> failure(
    String message, {
    WidgetBuilder? builder,
    OverlayNotifyOptions options = const OverlayNotifyOptions(),
  }) {
    return _show(message, NotifyType.failure, builder, options);
  }

  /// Shows a warning notification.
  OverlayHandle<void> warning(
    String message, {
    WidgetBuilder? builder,
    OverlayNotifyOptions options = const OverlayNotifyOptions(),
  }) {
    return _show(message, NotifyType.warning, builder, options);
  }

  /// Shows an error notification.
  OverlayHandle<void> error(
    String message, {
    WidgetBuilder? builder,
    OverlayNotifyOptions options = const OverlayNotifyOptions(),
  }) {
    return _show(message, NotifyType.error, builder, options);
  }

  /// Shows an alert notification.
  OverlayHandle<void> alert(
    String message, {
    WidgetBuilder? builder,
    OverlayNotifyOptions options = const OverlayNotifyOptions(),
  }) {
    return _show(message, NotifyType.alert, builder, options);
  }

  OverlayHandle<void> _show(
    String message,
    NotifyType type,
    WidgetBuilder? builder,
    OverlayNotifyOptions options,
  ) {
    final manager = OverlayManager.instance;
    final generation = manager.requireActiveGeneration();
    final backType = _backTypeFor(options.backBehavior);
    manager.validateCommandRoute(
      generation: generation,
      bindToRoute: false,
      backType: backType,
      onBack: null,
      operation: 'SuperOverlay notification',
    );
    final hostStyle = manager.notifyStyleFor(generation);
    final styledWidget = hostStyle?.build(_notificationTypeFor(type), message);
    final controller = SuperOverlayController();
    final command = SuperOverlay._notification(
          message: message,
          type: type,
          builder:
              builder ?? (styledWidget == null ? null : (_) => styledWidget),
        )
        .withAlignment(options.alignment)
        .withController(controller)
        .withBack(type: backType)
        .withAwait(AwaitCompletion.dismiss);

    final tag = options.tag;
    final identityTag = _commandTag('notify');
    command.withTag(identityTag)._withBusinessTag(tag);

    final existing = _existingOverlayHandle<void>(
      generation: generation,
      status: DismissStatus.notify,
      tag: tag,
      strategy: options.strategy,
      type: OverlayType.notify,
    );
    if (existing != null) {
      return existing;
    }
    final displayDuration = options.displayDuration;
    if (displayDuration != null) {
      command.withDisplayTime(displayDuration);
    }

    final lifecycle = _CommandOverlayLifecycle<void>(
      generation: generation,
      fire:
          () => OverlayRuntimeResult<void>(
            visible: controller.visible,
            closed: command.fire<void>(),
          ),
      status: DismissStatus.notify,
      tag: identityTag,
      replaceTag: tag,
      strategy: options.strategy,
    );
    lifecycle.start();
    return _overlayHandle<void>(
      generation: generation,
      visible: lifecycle.visible,
      closed: lifecycle.closed,
      status: DismissStatus.notify,
      tag: identityTag,
      close: lifecycle.close,
      isVisible:
          () => manager.checkExist(
            tag: identityTag,
            generation: generation,
            types: const {OverlayType.notify},
          ),
    );
  }
}

class _OverlayToastService {
  const _OverlayToastService();

  OverlayHandle<void> show(
    String message, {
    WidgetBuilder? builder,
    OverlayToastOptions options = const OverlayToastOptions(),
  }) {
    final manager = OverlayManager.instance;
    final generation = manager.requireActiveGeneration();
    final hostBuilder = manager.toastBuilderFor(generation);
    final controller = SuperOverlayController();
    final command = SuperOverlay._toastCommand(
          message,
          builder:
              builder ??
              (hostBuilder == null ? null : (_) => hostBuilder(message)),
        )
        .withAlignment(options.alignment)
        .withDisplayTime(options.displayDuration)
        .withDisplayType(_toastDisplayTypeFor(options.displayPolicy))
        .withConsumeEvent(options.consumeEvents)
        .withController(controller)
        .withAwait(AwaitCompletion.dismiss);

    final tag = options.tag;
    final identityTag = _commandTag('toast');
    command.withTag(identityTag)._withBusinessTag(tag);

    switch (options.strategy) {
      case OverlayStrategy.stack:
        break;
      case OverlayStrategy.replaceExisting:
        break;
      case OverlayStrategy.keepExisting:
        command.withKeepSingle();
    }

    final lifecycle = _CommandOverlayLifecycle<void>(
      generation: generation,
      fire: () => command._fireCommand<void>(generation),
      status: DismissStatus.toast,
      tag: identityTag,
      replaceTag: tag,
      strategy: options.strategy,
    );
    lifecycle.start();
    return _overlayHandle<void>(
      generation: generation,
      visible: lifecycle.visible,
      closed: lifecycle.closed,
      status: DismissStatus.toast,
      tag: identityTag,
      close: lifecycle.close,
      refresh: controller.refresh,
      isVisible:
          () =>
              !lifecycle.isQueued &&
              ToastTool.instance.isActiveTag(
                lifecycle.activeTag,
                generation: generation,
              ),
    );
  }
}

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
  VoidCallback? refresh,
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
        () => OverlayManager.instance.refreshForGeneration(
          generation,
          refresh ?? () {},
        ),
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

  Future<void> get visible => _visible.future;
  Future<T?> get closed => _closed.future;
  bool get isQueued => _fireStarted && !_visible.isCompleted;
  String get activeTag => _identityTag;

  void start() {
    unawaited(_run());
  }

  Future<void> close([T? result]) {
    if (!_visible.isCompleted && !_fireStarted) {
      _closeRequested = true;
      _closeResult = result;
      return _closed.future.then((_) {});
    }

    return OverlayManager.instance.dismiss<T>(
      status: status,
      tag: _identityTag,
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
    await OverlayManager.instance.dismiss(
      status: status,
      tag: replaceTag,
      force: true,
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

  final closed = OverlayManager.instance.existingClosedFuture<T>(
    tag: tag,
    type: type,
    generation: generation,
  );
  if (closed == null) {
    return null;
  }

  final visible = OverlayManager.instance.existingVisibleFuture(
    tag: tag,
    type: type,
    generation: generation,
  );

  final existingRefresh = OverlayManager.instance.existingRefresh(
    tag: tag,
    type: type,
    generation: generation,
  );

  return _overlayHandle<T>(
    generation: generation,
    visible: visible,
    closed: closed,
    status: status,
    tag: tag,
    refresh: existingRefresh ?? refresh,
    isVisible:
        () => switch (type) {
          OverlayType.custom || OverlayType.attach => OverlayManager.instance
              .isDialogVisible(tag: tag, generation: generation, type: type),
          _ => OverlayManager.instance.checkExist(
            tag: tag,
            generation: generation,
            types: {type},
          ),
        },
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
