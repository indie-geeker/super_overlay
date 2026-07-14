part of '../super_overlay_core.dart';

class _SuperNotifyOverlayBuilder {
  _SuperNotifyOverlayBuilder({
    required this.message,
    required this.type,
    required WidgetBuilder? builder,
  }) : _builder = builder;

  final String message;
  final NotifyType type;
  WidgetBuilder? _builder;
  Alignment _alignment = overlayConfig.notify.alignment;
  Duration? _displayTime = overlayConfig.notify.displayTime;
  String? _tag;
  String? _businessTag;
  bool _keepSingle = false;
  BackType _backType = overlayConfig.notify.backType;
  SuperOverlayOnBack? _onBack;
  SuperOverlayController? _controller;
  AwaitCompletion _awaitCompletion = overlayConfig.notify.awaitCompletion;

  _SuperNotifyOverlayBuilder withBuilder(WidgetBuilder builder) {
    _builder = builder;
    return this;
  }

  _SuperNotifyOverlayBuilder withAlignment(Alignment alignment) {
    _alignment = alignment;
    return this;
  }

  _SuperNotifyOverlayBuilder withDisplayTime(Duration displayTime) {
    _displayTime = displayTime;
    return this;
  }

  _SuperNotifyOverlayBuilder withTag(String tag) {
    _tag = tag;
    return this;
  }

  _SuperNotifyOverlayBuilder _withBusinessTag(String? tag) {
    _businessTag = tag;
    return this;
  }

  _SuperNotifyOverlayBuilder withKeepSingle([bool enabled = true]) {
    _keepSingle = enabled;
    return this;
  }

  _SuperNotifyOverlayBuilder withBack({
    BackType type = BackType.normal,
    SuperOverlayOnBack? onBack,
  }) {
    _backType = type;
    _onBack = onBack;
    return this;
  }

  _SuperNotifyOverlayBuilder withController(SuperOverlayController controller) {
    _controller = controller;
    return this;
  }

  _SuperNotifyOverlayBuilder withAwait(AwaitCompletion completion) {
    _awaitCompletion = completion;
    return this;
  }

  Future<T?> fire<T>() {
    final notify = overlayConfig.notify;
    return OverlayManager.instance.showNotify<T>(
      param: ShowNotifyParam(
        builder: _builder ?? (_) => _defaultNotifyWidget(),
        alignment: _alignment,
        clickMaskDismiss: notify.clickMaskDismiss,
        animationType: notify.animationType,
        nonAnimationTypes: notify.nonAnimationTypes,
        animationBuilder: null,
        usePenetrate: notify.usePenetrate,
        useAnimation: notify.useAnimation,
        animationTime: notify.animationTime,
        maskColor: notify.maskColor,
        maskWidget: notify.maskWidget,
        onDismiss: null,
        onMask: null,
        awaitCompletion: _awaitCompletion,
        accessibilityMode: OverlayAccessibilityMode.liveRegion,
        requestFocus: false,
        semanticsLabel: null,
        barrierSemanticsLabel: null,
        controller: _controller,
        debounce: notify.debounce,
        debounceTime: notify.debounceTime,
        displayTime: _displayTime,
        tag: _tag,
        businessTag: _businessTag,
        keepSingle: _keepSingle,
        backType: _backType,
        onBack: _onBack,
      ),
    );
  }

  Widget _defaultNotifyWidget() {
    final styledWidget = overlayConfig.notify.style?.build(
      _notificationTypeFor(type),
      message,
    );
    if (styledWidget != null) {
      return styledWidget;
    }

    return switch (type) {
      NotifyType.success => NotifySuccess(message: message),
      NotifyType.failure => NotifyFailure(message: message),
      NotifyType.warning => NotifyWarning(message: message),
      NotifyType.error => NotifyError(message: message),
      NotifyType.alert => NotifyAlert(message: message),
    };
  }
}

OverlayNotificationType _notificationTypeFor(NotifyType type) {
  return switch (type) {
    NotifyType.success => OverlayNotificationType.success,
    NotifyType.failure => OverlayNotificationType.failure,
    NotifyType.warning => OverlayNotificationType.warning,
    NotifyType.error => OverlayNotificationType.error,
    NotifyType.alert => OverlayNotificationType.alert,
  };
}
