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
      refresh: controller.refresh,
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
    CapturedThemes? themes,
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
          themes: themes,
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
          () => manager.isCommandIdentityVisible(
            identityTag: identityTag,
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
    CapturedThemes? themes,
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
          themes: themes,
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
          () => manager.isCommandIdentityVisible(
            identityTag: identityTag,
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
    command.withDisplayTime(options.displayDuration);

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
      refresh: controller.refresh,
      isVisible:
          () => manager.isCommandIdentityVisible(
            identityTag: identityTag,
            generation: generation,
            type: OverlayType.notify,
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
      refresh: lifecycle.refresh,
      isVisible:
          () =>
              !lifecycle.isQueued &&
              ToastTool.instance.isActiveIdentityTag(
                lifecycle.activeTag,
                generation: generation,
              ),
    );
  }
}
