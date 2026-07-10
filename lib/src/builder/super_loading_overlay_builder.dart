part of '../super_overlay_core.dart';

class _SuperLoadingOverlayBuilder {
  _SuperLoadingOverlayBuilder({
    required this.message,
    required WidgetBuilder? builder,
  }) : _builder = builder;

  final String message;
  WidgetBuilder? _builder;
  Duration? _displayTime;
  Duration _leastLoadingTime = overlayConfig.loading.leastLoadingTime;
  Color? _maskColor;
  Widget? _maskWidget;
  bool _clickMaskDismiss = overlayConfig.loading.clickMaskDismiss;
  String? _tag;
  BackType _backType = overlayConfig.loading.backType;
  SuperOverlayOnBack? _onBack;
  SuperOverlayController? _controller;
  AwaitCompletion _awaitCompletion = overlayConfig.loading.awaitCompletion;

  _SuperLoadingOverlayBuilder withBuilder(WidgetBuilder builder) {
    _builder = builder;
    return this;
  }

  _SuperLoadingOverlayBuilder withDisplayTime(Duration displayTime) {
    _displayTime = displayTime;
    return this;
  }

  _SuperLoadingOverlayBuilder withLeastLoadingTime(Duration duration) {
    _leastLoadingTime = duration;
    return this;
  }

  _SuperLoadingOverlayBuilder withMask({
    Color? color,
    Widget? widget,
    bool dismissible = false,
  }) {
    _maskColor = color;
    _maskWidget = widget;
    _clickMaskDismiss = dismissible;
    return this;
  }

  _SuperLoadingOverlayBuilder withTag(String tag) {
    _tag = tag;
    return this;
  }

  _SuperLoadingOverlayBuilder withBack({
    BackType type = BackType.normal,
    SuperOverlayOnBack? onBack,
  }) {
    _backType = type;
    _onBack = onBack;
    return this;
  }

  _SuperLoadingOverlayBuilder withController(
    SuperOverlayController controller,
  ) {
    _controller = controller;
    return this;
  }

  _SuperLoadingOverlayBuilder withAwait(AwaitCompletion completion) {
    _awaitCompletion = completion;
    return this;
  }

  Future<T?> fire<T>() {
    final loading = overlayConfig.loading;
    return OverlayManager.instance.showLoading<T>(
      param: ShowLoadingParam(
        builder:
            _builder ??
            (_) =>
                loading.builder?.call(message) ??
                LoadingWidget(message: message),
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
        awaitCompletion: _awaitCompletion,
        controller: _controller,
        displayTime: _displayTime,
        leastLoadingTime: _leastLoadingTime,
        tag: _tag,
        backType: _backType,
        onBack: _onBack,
      ),
    );
  }
}
