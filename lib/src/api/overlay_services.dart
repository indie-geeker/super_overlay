part of '../super_overlay_core.dart';

/// Shows and controls the app's single loading surface.
class OverlayLoadingService {
  const OverlayLoadingService();

  /// Shows loading. A newer call replaces the previous loading surface.
  ///
  /// Each handle owns only its own call; closing an older handle cannot close
  /// its replacement. Showing or closing loading does not cancel business work.
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
    final identityTag = _commandTag('loading');
    final config = overlayConfig.loading;
    final closed = manager.showLoading<void>(
      param: ShowLoadingParam(
        builder:
            builder ??
            (_) =>
                hostBuilder?.call(message) ??
                config.builder?.call(message) ??
                LoadingWidget(message: message),
        alignment: config.alignment,
        clickMaskDismiss: options.dismissOnMaskTap,
        animationType: config.animationType,
        nonAnimationTypes: config.nonAnimationTypes,
        animationBuilder: null,
        usePenetrate: config.usePenetrate,
        useAnimation: config.useAnimation,
        animationTime: config.animationTime,
        maskColor: config.maskColor,
        maskWidget: config.maskWidget,
        onDismiss: null,
        onMask: null,
        awaitCompletion: AwaitCompletion.dismiss,
        accessibilityMode: OverlayAccessibilityMode.modal,
        requestFocus: options.requestFocus,
        semanticsLabel: options.semanticsLabel,
        barrierSemanticsLabel: options.barrierSemanticsLabel,
        controller: controller,
        displayTime: options.displayDuration,
        leastLoadingTime: options.minimumVisibleDuration,
        tag: identityTag,
        businessTag: options.tag,
        backType: backType,
        onBack: null,
      ),
    );
    return _loadingHandle(
      generation: generation,
      controller: controller,
      closed: closed,
      identityTag: identityTag,
    );
  }

  /// Runs [action] and always closes this call's loading afterward.
  ///
  /// Returns the action's result and propagates its errors. Work starts without
  /// waiting for a rendered frame. Overlapping calls run independently; the
  /// latest call owns the displayed loading. Dismissal does not cancel work.
  Future<T> run<T>(
    FutureOr<T> Function() action, {
    String message = '',
    WidgetBuilder? builder,
    OverlayLoadingOptions options = const OverlayLoadingOptions(),
  }) async {
    final handle = show(message: message, builder: builder, options: options);
    try {
      final result = await action();
      await handle.close();
      return result;
    } catch (_) {
      try {
        await handle.close();
      } catch (_) {
        // Preserve the action's error when cleanup also fails.
      }
      rethrow;
    }
  }

  /// Closes the app's currently active loading surface.
  Future<void> close() {
    OverlayManager.instance.requireActiveGeneration();
    return SuperOverlay._dismiss(status: DismissStatus.loading);
  }
}

/// Shows dialog overlays with typed results.
class OverlayDialogService {
  const OverlayDialogService();

  /// Shows a dialog. [builder] receives the dialog's own handle.
  OverlayHandle<T> show<T>({
    required OverlayWidgetBuilder<T> builder,
    OverlayDialogOptions options = const OverlayDialogOptions(),
  }) => _show<T>(builder: builder, options: options);

  OverlayHandle<T> _show<T>({
    required OverlayWidgetBuilder<T> builder,
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
    final existing = _existingOverlayHandle<T>(
      generation: generation,
      status: DismissStatus.custom,
      tag: options.tag,
      strategy: options.strategy,
      type: OverlayType.custom,
    );
    if (existing != null) return existing;
    final identityTag = _commandTag('dialog');
    late final OverlayHandle<T> handle;
    final lifecycle = _CommandOverlayLifecycle<T>(
      generation: generation,
      status: DismissStatus.custom,
      tag: identityTag,
      replaceTag: options.tag,
      strategy: options.strategy,
      routeOwner: capturedOwner,
      widgetOwner: options.bindToWidget,
      fire: () {
        final config = overlayConfig.custom;
        return OverlayRuntimeResult<T>(
          visible: controller.visible,
          closed: manager.show<T>(
            param: ShowCustomParam(
              builder: (context) => builder(context, handle),
              alignment: options.alignment,
              clickMaskDismiss: options.dismissOnMaskTap,
              animationType: config.animationType,
              nonAnimationTypes: config.nonAnimationTypes,
              animationBuilder: null,
              usePenetrate: !options.consumeEvents,
              useAnimation: config.useAnimation,
              animationTime: config.animationTime,
              maskColor: options.barrierColor ?? config.maskColor,
              maskWidget: config.maskWidget,
              onDismiss: null,
              onMask: null,
              awaitCompletion: AwaitCompletion.dismiss,
              accessibilityMode:
                  options.consumeEvents
                      ? OverlayAccessibilityMode.modal
                      : OverlayAccessibilityMode.popup,
              requestFocus: options.requestFocus,
              semanticsLabel: options.semanticsLabel,
              barrierSemanticsLabel: options.barrierSemanticsLabel,
              debounce: config.debounce,
              debounceTime: config.debounceTime,
              displayTime: options.displayDuration,
              tag: identityTag,
              businessTag: options.tag,
              keepSingle: false,
              permanent: false,
              bindPage: options.bindToRoute,
              bindWidget: options.bindToWidget,
              ignoreArea: null,
              maskTriggerType: config.maskTriggerType,
              controller: controller,
              backType: backType,
              onBack: null,
              routeOwner: capturedOwner,
              themes: themes,
            ),
          ),
        );
      },
    );
    handle = _overlayHandle<T>(
      generation: generation,
      visible: lifecycle.visible,
      closed: lifecycle.closed,
      status: DismissStatus.custom,
      tag: identityTag,
      close: lifecycle.close,
      refresh: controller.refresh,
      isVisible: lifecycle.isVisible,
    );
    lifecycle.start();
    return handle;
  }
}

/// Shows anchored popup overlays with typed results.
class OverlayPopupService {
  const OverlayPopupService();

  /// Shows a popup. [builder] receives the popup's own handle.
  ///
  /// [targetContext] must remain mounted while a replacement waits. It is
  /// checked before replacement cleanup and again before activation. If it
  /// unmounts, the pending popup is cancelled: [OverlayHandle.visible] fails
  /// with [StateError] and [OverlayHandle.closed] completes normally.
  OverlayHandle<T> show<T>({
    BuildContext? targetContext,
    required OverlayWidgetBuilder<T> builder,
    OverlayPopupOptions options = const OverlayPopupOptions(),
  }) => _show<T>(
    targetContext: targetContext,
    builder: builder,
    options: options,
  );

  OverlayHandle<T> _show<T>({
    BuildContext? targetContext,
    required OverlayWidgetBuilder<T> builder,
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
    final existing = _existingOverlayHandle<T>(
      generation: generation,
      status: DismissStatus.attach,
      tag: options.tag,
      strategy: options.strategy,
      type: OverlayType.attach,
    );
    if (existing != null) return existing;
    final identityTag = _commandTag('popup');
    late final OverlayHandle<T> handle;
    final lifecycle = _CommandOverlayLifecycle<T>(
      generation: generation,
      status: DismissStatus.attach,
      tag: identityTag,
      replaceTag: options.tag,
      strategy: options.strategy,
      routeOwner: capturedOwner,
      widgetOwner: targetContext,
      fire: () {
        final config = overlayConfig.attach;
        return OverlayRuntimeResult<T>(
          visible: controller.visible,
          closed: manager.showAttach<T>(
            param: ShowAttachParam(
              builder: (context) => builder(context, handle),
              alignment: options.alignment,
              clickMaskDismiss: options.dismissOnMaskTap,
              animationType: config.animationType,
              nonAnimationTypes: config.nonAnimationTypes,
              animationBuilder: null,
              usePenetrate: config.usePenetrate,
              useAnimation: config.useAnimation,
              animationTime: config.animationTime,
              maskColor:
                  options.highlightTarget
                      ? options.highlightMaskColor ?? config.maskColor
                      : Colors.transparent,
              maskWidget: config.maskWidget,
              onDismiss: null,
              onMask: null,
              awaitCompletion: AwaitCompletion.dismiss,
              accessibilityMode: OverlayAccessibilityMode.popup,
              requestFocus: options.requestFocus,
              debounce: config.debounce,
              debounceTime: config.debounceTime,
              displayTime: options.displayDuration,
              tag: identityTag,
              businessTag: options.tag,
              keepSingle: false,
              permanent: false,
              bindPage: options.bindToRoute,
              bindWidget: targetContext,
              ignoreArea: null,
              maskTriggerType: config.maskTriggerType,
              controller: controller,
              backType: backType,
              onBack: null,
              routeOwner: capturedOwner,
              themes: themes,
              targetContext: targetContext,
              targetRectBuilder: options.targetRectBuilder,
              targetPointBuilder: options.targetPointBuilder,
              alignmentMode:
                  options.alignmentMode == null
                      ? config.alignmentMode
                      : _popupAlignmentModeFor(options.alignmentMode!),
              replacementBuilder: options.replacementBuilder,
              adjustmentBuilder: options.adjustmentBuilder,
              scaleOriginBuilder: options.scaleOriginBuilder,
              maskIgnoreArea: options.maskIgnoreArea,
              highlight:
                  options.highlightTarget
                      ? HighlightConfig(
                        padding: options.highlightPadding,
                        borderRadius: options.highlightBorderRadius,
                      )
                      : null,
            ),
          ),
        );
      },
    );
    handle = _overlayHandle<T>(
      generation: generation,
      visible: lifecycle.visible,
      closed: lifecycle.closed,
      status: DismissStatus.attach,
      tag: identityTag,
      close: lifecycle.close,
      refresh: controller.refresh,
      isVisible: lifecycle.isVisible,
    );
    lifecycle.start();
    return handle;
  }
}

/// Shows app-wide notifications.
class OverlayNotifyService {
  const OverlayNotifyService();

  /// Shows a success notification.
  OverlayHandle<void> success(
    String message, {
    WidgetBuilder? builder,
    OverlayNotifyOptions options = const OverlayNotifyOptions(),
  }) => _show(message, OverlayNotificationType.success, builder, options);

  /// Shows a failure notification.
  OverlayHandle<void> failure(
    String message, {
    WidgetBuilder? builder,
    OverlayNotifyOptions options = const OverlayNotifyOptions(),
  }) => _show(message, OverlayNotificationType.failure, builder, options);

  /// Shows a warning notification.
  OverlayHandle<void> warning(
    String message, {
    WidgetBuilder? builder,
    OverlayNotifyOptions options = const OverlayNotifyOptions(),
  }) => _show(message, OverlayNotificationType.warning, builder, options);

  /// Shows an error notification.
  OverlayHandle<void> error(
    String message, {
    WidgetBuilder? builder,
    OverlayNotifyOptions options = const OverlayNotifyOptions(),
  }) => _show(message, OverlayNotificationType.error, builder, options);

  /// Shows an alert notification.
  OverlayHandle<void> alert(
    String message, {
    WidgetBuilder? builder,
    OverlayNotifyOptions options = const OverlayNotifyOptions(),
  }) => _show(message, OverlayNotificationType.alert, builder, options);

  OverlayHandle<void> _show(
    String message,
    OverlayNotificationType type,
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
    final controller = SuperOverlayController();
    final existing = _existingOverlayHandle<void>(
      generation: generation,
      status: DismissStatus.notify,
      tag: options.tag,
      strategy: options.strategy,
      type: OverlayType.notify,
    );
    if (existing != null) return existing;
    final identityTag = _commandTag('notify');
    final lifecycle = _CommandOverlayLifecycle<void>(
      generation: generation,
      status: DismissStatus.notify,
      tag: identityTag,
      replaceTag: options.tag,
      strategy: options.strategy,
      fire: () {
        final config = overlayConfig.notify;
        return OverlayRuntimeResult<void>(
          visible: controller.visible,
          closed: manager.showNotify<void>(
            param: ShowNotifyParam(
              builder:
                  builder ??
                  (_) =>
                      hostStyle?.build(type, message) ??
                      overlayConfig.notify.style?.build(type, message) ??
                      _notificationWidget(type, message),
              alignment: options.alignment,
              clickMaskDismiss: config.clickMaskDismiss,
              animationType: config.animationType,
              nonAnimationTypes: config.nonAnimationTypes,
              animationBuilder: null,
              usePenetrate: config.usePenetrate,
              useAnimation: config.useAnimation,
              animationTime: config.animationTime,
              maskColor: config.maskColor,
              maskWidget: config.maskWidget,
              onDismiss: null,
              onMask: null,
              awaitCompletion: AwaitCompletion.dismiss,
              controller: controller,
              debounce: config.debounce,
              debounceTime: config.debounceTime,
              displayTime: options.displayDuration,
              tag: identityTag,
              businessTag: options.tag,
              keepSingle: false,
              backType: backType,
              onBack: null,
            ),
          ),
        );
      },
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
      isVisible: lifecycle.isVisible,
    );
  }
}

Widget _notificationWidget(OverlayNotificationType type, String message) =>
    switch (type) {
      OverlayNotificationType.success => NotifySuccess(message: message),
      OverlayNotificationType.failure => NotifyFailure(message: message),
      OverlayNotificationType.warning => NotifyWarning(message: message),
      OverlayNotificationType.error => NotifyError(message: message),
      OverlayNotificationType.alert => NotifyAlert(message: message),
    };

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
    final identityTag = _commandTag('toast');
    final lifecycle = _CommandOverlayLifecycle<void>(
      generation: generation,
      status: DismissStatus.toast,
      tag: identityTag,
      replaceTag: options.tag,
      strategy: options.strategy,
      fire: () {
        final config = overlayConfig.toast;
        final result = ToastTool.instance.showCommand<void>(
          ShowToastParam(
            builder:
                builder ??
                (_) =>
                    hostBuilder?.call(message) ??
                    config.builder?.call(message) ??
                    ToastWidget(message: message),
            alignment: options.alignment,
            clickMaskDismiss: config.clickMaskDismiss,
            animationType: config.animationType,
            nonAnimationTypes: config.nonAnimationTypes,
            animationBuilder: null,
            usePenetrate: config.usePenetrate,
            useAnimation: config.useAnimation,
            animationTime: config.animationTime,
            maskColor: config.maskColor,
            maskWidget: config.maskWidget,
            onDismiss: null,
            onMask: null,
            awaitCompletion: AwaitCompletion.dismiss,
            controller: controller,
            displayTime: options.displayDuration,
            debounceTime: config.debounceTime,
            debounce: config.debounce,
            displayType: _toastDisplayTypeFor(options.displayPolicy),
            consumeEvent: options.consumeEvents,
            tag: identityTag,
            businessTag: options.tag,
            keepSingle: options.strategy == OverlayStrategy.keepExisting,
            replaceExisting: false,
          ),
          generation: generation,
        );
        if (result.identityTag == null) controller.dismiss();
        return OverlayRuntimeResult<void>.lazyClosed(
          visible:
              result.identityTag == null || result.identityTag == identityTag
                  ? controller.visible
                  : result.visible,
          closed: result.readClosed,
          identityTag: result.identityTag,
          refresh: result.refresh ?? controller.refresh,
        );
      },
    );
    lifecycle.start();
    return _overlayHandle<void>(
      generation: generation,
      visible: lifecycle.visible,
      readClosed: lifecycle.readClosed,
      status: DismissStatus.toast,
      tag: identityTag,
      close: lifecycle.close,
      refresh: lifecycle.refresh,
      // Keep the handle out of the content factory's closure context.
      isVisible: lifecycle.isVisible,
    );
  }
}
