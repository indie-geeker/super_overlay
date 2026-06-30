part of '../super_overlay_core.dart';

class SuperLoadingOverlayBuilder {
  SuperLoadingOverlayBuilder({
    required this.message,
    required WidgetBuilder? builder,
  }) : _builder = builder;

  final String message;
  WidgetBuilder? _builder;
  Duration? _displayTime;
  Duration _leastLoadingTime = SuperOverlay.config.loading.leastLoadingTime;
  Color? _maskColor;
  Widget? _maskWidget;
  bool _clickMaskDismiss = SuperOverlay.config.loading.clickMaskDismiss;
  BackType _backType = SuperOverlay.config.loading.backType;
  SuperOverlayOnBack? _onBack;

  SuperLoadingOverlayBuilder withBuilder(WidgetBuilder builder) {
    _builder = builder;
    return this;
  }

  SuperLoadingOverlayBuilder withDisplayTime(Duration displayTime) {
    _displayTime = displayTime;
    return this;
  }

  SuperLoadingOverlayBuilder withLeastLoadingTime(Duration duration) {
    _leastLoadingTime = duration;
    return this;
  }

  SuperLoadingOverlayBuilder withMask({
    Color? color,
    Widget? widget,
    bool dismissible = false,
  }) {
    _maskColor = color;
    _maskWidget = widget;
    _clickMaskDismiss = dismissible;
    return this;
  }

  SuperLoadingOverlayBuilder withBack({
    BackType type = BackType.normal,
    SuperOverlayOnBack? onBack,
  }) {
    _backType = type;
    _onBack = onBack;
    return this;
  }

  Future<T?> fire<T>() {
    final loading = SuperOverlay.config.loading;
    return OverlayManager.instance.showLoading<T>(
      param: ShowLoadingParam(
        builder: _builder ?? (_) => LoadingWidget(message: message),
        alignment: loading.alignment,
        clickMaskDismiss: _clickMaskDismiss,
        animationType: loading.animationType,
        nonAnimationTypes: loading.nonAnimationTypes,
        animationBuilder: null,
        usePenetrate: loading.usePenetrate,
        useAnimation: loading.useAnimation,
        animationTime: loading.animationTime,
        maskColor: _maskColor ?? loading.maskColor,
        maskWidget: _maskWidget ?? loading.maskWidget,
        onDismiss: null,
        onMask: null,
        displayTime: _displayTime,
        leastLoadingTime: _leastLoadingTime,
        backType: _backType,
        onBack: _onBack,
      ),
    );
  }
}
