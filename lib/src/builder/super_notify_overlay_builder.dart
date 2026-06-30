part of '../super_overlay_core.dart';

class SuperNotifyOverlayBuilder {
  SuperNotifyOverlayBuilder({
    required this.message,
    required this.type,
    required WidgetBuilder? builder,
  }) : _builder = builder;

  final String message;
  final NotifyType type;
  WidgetBuilder? _builder;
  Duration? _displayTime = SuperOverlay.config.notify.displayTime;
  String? _tag;
  bool _keepSingle = false;
  BackType _backType = SuperOverlay.config.notify.backType;
  SuperOverlayOnBack? _onBack;
  AwaitCompletion _awaitCompletion = SuperOverlay.config.notify.awaitCompletion;

  SuperNotifyOverlayBuilder withBuilder(WidgetBuilder builder) {
    _builder = builder;
    return this;
  }

  SuperNotifyOverlayBuilder withDisplayTime(Duration displayTime) {
    _displayTime = displayTime;
    return this;
  }

  SuperNotifyOverlayBuilder withTag(String tag) {
    _tag = tag;
    return this;
  }

  SuperNotifyOverlayBuilder withKeepSingle([bool enabled = true]) {
    _keepSingle = enabled;
    return this;
  }

  SuperNotifyOverlayBuilder withBack({
    BackType type = BackType.normal,
    SuperOverlayOnBack? onBack,
  }) {
    _backType = type;
    _onBack = onBack;
    return this;
  }

  SuperNotifyOverlayBuilder withAwait(AwaitCompletion completion) {
    _awaitCompletion = completion;
    return this;
  }

  Future<T?> fire<T>() {
    final notify = SuperOverlay.config.notify;
    return OverlayManager.instance.showNotify<T>(
      param: ShowNotifyParam(
        builder: _builder ?? (_) => _defaultNotifyWidget(),
        alignment: notify.alignment,
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
        debounce: notify.debounce,
        debounceTime: notify.debounceTime,
        displayTime: _displayTime,
        tag: _tag,
        keepSingle: _keepSingle,
        backType: _backType,
        onBack: _onBack,
      ),
    );
  }

  Widget _defaultNotifyWidget() {
    final styledWidget = SuperOverlay.config.notify.style?.build(type, message);
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
