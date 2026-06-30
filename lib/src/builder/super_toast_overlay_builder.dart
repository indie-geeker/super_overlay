part of '../super_overlay_core.dart';

class SuperToastOverlayBuilder {
  SuperToastOverlayBuilder({
    required this.message,
    required WidgetBuilder? builder,
  }) : _builder = builder;

  final String message;
  WidgetBuilder? _builder;
  Duration _displayTime = SuperOverlay.config.toast.displayTime;
  ToastDisplayType _displayType = SuperOverlay.config.toast.displayType;
  Alignment _alignment = SuperOverlay.config.toast.alignment;
  bool _consumeEvent = SuperOverlay.config.toast.consumeEvent;
  bool _debounce = SuperOverlay.config.toast.debounce;

  SuperToastOverlayBuilder withBuilder(WidgetBuilder builder) {
    _builder = builder;
    return this;
  }

  SuperToastOverlayBuilder withDisplayTime(Duration displayTime) {
    _displayTime = displayTime;
    return this;
  }

  SuperToastOverlayBuilder withDisplayType(ToastDisplayType displayType) {
    _displayType = displayType;
    return this;
  }

  SuperToastOverlayBuilder withAlignment(Alignment alignment) {
    _alignment = alignment;
    return this;
  }

  SuperToastOverlayBuilder withConsumeEvent(bool enabled) {
    _consumeEvent = enabled;
    return this;
  }

  SuperToastOverlayBuilder withDebounce(bool enabled) {
    _debounce = enabled;
    return this;
  }

  Future<T?> fire<T>() {
    final toast = SuperOverlay.config.toast;
    OverlayManager.instance.showToast(
      param: ShowToastParam(
        builder: _builder ?? (_) => ToastWidget(message: message),
        alignment: _alignment,
        clickMaskDismiss: toast.clickMaskDismiss,
        animationType: toast.animationType,
        nonAnimationTypes: toast.nonAnimationTypes,
        animationBuilder: null,
        usePenetrate: toast.usePenetrate,
        useAnimation: toast.useAnimation,
        animationTime: toast.animationTime,
        maskColor: toast.maskColor,
        maskWidget: toast.maskWidget,
        onDismiss: null,
        onMask: null,
        displayTime: _displayTime,
        debounceTime: toast.debounceTime,
        debounce: _debounce,
        displayType: _displayType,
        consumeEvent: _consumeEvent,
      ),
    );
    return Future<T?>.value();
  }
}
