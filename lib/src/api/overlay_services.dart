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
    final command = SuperOverlay.showLoading(msg: message, builder: builder)
        .withMask(dismissible: options.dismissOnMaskTap)
        .withLeastLoadingTime(options.minimumVisibleDuration)
        .withBack(type: _backTypeFor(options.backBehavior))
        .withAwait(AwaitCompletion.dismiss);

    final tag = options.tag;
    final effectiveTag = tag ?? _commandTag('loading');
    command.withTag(effectiveTag);

    final displayDuration = options.displayDuration;
    if (displayDuration != null) {
      command.withDisplayTime(displayDuration);
    }

    final closed = command.fire<void>();
    return _overlayHandle<void>(
      closed: closed,
      status: DismissStatus.loading,
      tag: effectiveTag,
      close:
          ([void result]) => SuperOverlay.dismiss<void>(
            status: DismissStatus.loading,
            tag: effectiveTag,
          ),
      isVisible:
          () => OverlayManager.instance.checkExist(
            tag: effectiveTag,
            types: const {OverlayType.loading},
          ),
    );
  }

  /// Closes the active loading overlay.
  Future<void> close() {
    return SuperOverlay.dismiss(status: DismissStatus.loading);
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
    final controller = SuperOverlayController();
    final command = SuperOverlay.show(builder: builder)
        .withAlignment(options.alignment)
        .withMask(
          color: options.barrierColor,
          dismissible: options.dismissOnMaskTap,
        )
        .bindPage(options.bindToRoute)
        .withController(controller)
        .withBack(type: _backTypeFor(options.backBehavior))
        .withAwait(AwaitCompletion.dismiss);

    final bindToWidget = options.bindToWidget;
    if (bindToWidget != null) {
      command.bindWidget(bindToWidget);
    }

    final tag = options.tag;
    final identityTag = _commandTag('dialog');
    command.withTag(identityTag)._withBusinessTag(tag);

    final existing = _existingOverlayHandle<T>(
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
      fire: () => _CommandFireResult<T>(closed: command.fire<T>()),
      status: DismissStatus.custom,
      tag: identityTag,
      replaceTag: tag,
      strategy: options.strategy,
    );
    lifecycle.start();
    return _overlayHandle<T>(
      visible: lifecycle.visible,
      closed: lifecycle.closed,
      status: DismissStatus.custom,
      tag: identityTag,
      close: lifecycle.close,
      refresh: controller.refresh,
      isVisible:
          () => OverlayManager.instance.checkExist(
            tag: identityTag,
            types: const {OverlayType.custom},
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
    final controller = SuperOverlayController();
    final command = SuperOverlay.showPopup(
          targetContext: targetContext,
          builder: builder,
        )
        .withAlignment(options.alignment)
        .withMask(dismissible: options.dismissOnMaskTap)
        .bindPage(options.bindToRoute)
        .withController(controller)
        .withBack(type: _backTypeFor(options.backBehavior))
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
      command.withAlignmentMode(alignmentMode);
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
      fire: () => _CommandFireResult<T>(closed: command.fire<T>()),
      status: DismissStatus.attach,
      tag: identityTag,
      replaceTag: tag,
      strategy: options.strategy,
    );
    lifecycle.start();
    return _overlayHandle<T>(
      visible: lifecycle.visible,
      closed: lifecycle.closed,
      status: DismissStatus.attach,
      tag: identityTag,
      close: lifecycle.close,
      refresh: controller.refresh,
      isVisible:
          () => OverlayManager.instance.checkExist(
            tag: identityTag,
            types: const {OverlayType.attach},
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
    final command = SuperOverlay.showNotify(
          msg: message,
          type: type,
          builder: builder,
        )
        .withAlignment(options.alignment)
        .withBack(type: _backTypeFor(options.backBehavior))
        .withAwait(AwaitCompletion.dismiss);

    final tag = options.tag;
    final identityTag = _commandTag('notify');
    command.withTag(identityTag)._withBusinessTag(tag);

    final existing = _existingOverlayHandle<void>(
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
      fire: () => _CommandFireResult<void>(closed: command.fire<void>()),
      status: DismissStatus.notify,
      tag: identityTag,
      replaceTag: tag,
      strategy: options.strategy,
    );
    lifecycle.start();
    return _overlayHandle<void>(
      visible: lifecycle.visible,
      closed: lifecycle.closed,
      status: DismissStatus.notify,
      tag: identityTag,
      close: lifecycle.close,
      isVisible:
          () => OverlayManager.instance.checkExist(
            tag: identityTag,
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
    final command = SuperOverlay.showToast(message, builder: builder)
        .withAlignment(options.alignment)
        .withDisplayTime(options.displayDuration)
        .withDisplayType(_toastDisplayTypeFor(options.displayPolicy))
        .withConsumeEvent(options.consumeEvents)
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
      fire: () {
        final result = command._fireCommand<void>();
        return _CommandFireResult<void>(
          visible: result.visible,
          closed: result.closed,
          dismissTag: result.dismissTag,
        );
      },
      status: DismissStatus.toast,
      tag: identityTag,
      replaceTag: tag,
      strategy: options.strategy,
    );
    lifecycle.start();
    return _overlayHandle<void>(
      visible: lifecycle.visible,
      closed: lifecycle.closed,
      status: DismissStatus.toast,
      tag: identityTag,
      close: lifecycle.close,
      isVisible:
          () =>
              !lifecycle.isQueued &&
              ToastTool.instance.isActiveTag(lifecycle.activeTag),
    );
  }
}

var _nextCommandTagId = 0;

String _commandTag(String kind) {
  return '_super_overlay_command_${kind}_${_nextCommandTagId++}';
}

OverlayHandle<T> _overlayHandle<T>({
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
        ([T? result]) =>
            SuperOverlay.dismiss<T>(status: status, tag: tag, result: result);
    return closeOverlay(result);
  }

  return OverlayHandle<T>(
    visible: visible ?? Future<void>.value(),
    closed: trackedClosed,
    close: requestClose,
    refresh: refresh ?? () {},
    isVisible: () => !isClosed && isVisible(),
  );
}

class _CommandFireResult<T> {
  _CommandFireResult({
    Future<void>? visible,
    required this.closed,
    this.dismissTag,
  }) : visible = visible ?? Future<void>.value();

  final Future<void> visible;
  final Future<T?> closed;
  final String? dismissTag;
}

class _CommandOverlayLifecycle<T> {
  _CommandOverlayLifecycle({
    required this.fire,
    required this.status,
    required this.tag,
    String? replaceTag,
    required this.strategy,
  }) : replaceTag = replaceTag ?? tag;

  final _CommandFireResult<T> Function() fire;
  final DismissStatus status;
  final String tag;
  final String replaceTag;
  final OverlayStrategy strategy;
  final Completer<void> _visible = Completer<void>();
  final Completer<T?> _closed = Completer<T?>();
  late String _dismissTag = tag;

  bool _closeRequested = false;
  bool _fireStarted = false;
  T? _closeResult;

  Future<void> get visible => _visible.future;
  Future<T?> get closed => _closed.future;
  bool get isQueued => _fireStarted && !_visible.isCompleted;
  String get activeTag => _dismissTag;

  void start() {
    unawaited(_run());
  }

  Future<void> close([T? result]) {
    if (!_visible.isCompleted && !_fireStarted) {
      _closeRequested = true;
      _closeResult = result;
      return _closed.future.then((_) {});
    }

    return SuperOverlay.dismiss<T>(
      status: status,
      tag: _dismissTag,
      result: result,
    );
  }

  Future<void> _run() async {
    try {
      if (strategy == OverlayStrategy.replaceExisting) {
        await SuperOverlay.dismiss(
          status: status,
          tag: replaceTag,
          force: true,
        );
      }

      if (_closeRequested) {
        if (!_visible.isCompleted) {
          _visible.complete();
        }
        if (!_closed.isCompleted) {
          _closed.complete(_closeResult);
        }
        return;
      }

      _fireStarted = true;
      final fired = fire();
      _dismissTag = fired.dismissTag ?? tag;
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
        _visible.complete();
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
}

OverlayHandle<T>? _existingOverlayHandle<T>({
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
  );
  if (closed == null) {
    return null;
  }

  final existingRefresh = OverlayManager.instance.existingRefresh(
    tag: tag,
    type: type,
  );

  return _overlayHandle<T>(
    closed: closed,
    status: status,
    tag: tag,
    refresh: existingRefresh ?? refresh,
    isVisible:
        () => OverlayManager.instance.checkExist(tag: tag, types: {type}),
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
