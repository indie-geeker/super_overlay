part of '../super_overlay_core.dart';

class _SuperCustomOverlayBuilder {
  _SuperCustomOverlayBuilder({required WidgetBuilder builder})
    : _builder = builder;

  WidgetBuilder _builder;
  Color? _maskColor;
  Widget? _maskWidget;
  bool _clickMaskDismiss = overlayConfig.custom.clickMaskDismiss;
  Alignment _alignment = overlayConfig.custom.alignment;
  bool _debounce = overlayConfig.custom.debounce;
  Duration? _displayTime;
  String? _tag;
  String? _businessTag;
  bool _keepSingle = false;
  bool _permanent = false;
  bool _bindPage = overlayConfig.custom.bindPage;
  BuildContext? _bindWidget;
  Rect? _ignoreArea;
  MaskTriggerType _maskTriggerType = overlayConfig.custom.maskTriggerType;
  SuperOverlayController? _controller;
  BackType _backType = overlayConfig.custom.backType;
  bool _usePenetrate = overlayConfig.custom.usePenetrate;
  SuperOverlayOnBack? _onBack;
  VoidCallback? _onDismiss;
  VoidCallback? _onMask;
  AwaitCompletion _awaitCompletion = overlayConfig.custom.awaitCompletion;

  _SuperCustomOverlayBuilder withBuilder(WidgetBuilder builder) {
    _builder = builder;
    return this;
  }

  _SuperCustomOverlayBuilder withMask({
    Color? color,
    Widget? widget,
    bool dismissible = true,
    MaskTriggerType? triggerType,
  }) {
    _maskColor = color;
    _maskWidget = widget;
    _clickMaskDismiss = dismissible;
    _maskTriggerType = triggerType ?? _maskTriggerType;
    return this;
  }

  _SuperCustomOverlayBuilder withAlignment(Alignment alignment) {
    _alignment = alignment;
    return this;
  }

  _SuperCustomOverlayBuilder withTag(String tag) {
    _tag = tag;
    return this;
  }

  _SuperCustomOverlayBuilder _withBusinessTag(String? tag) {
    _businessTag = tag;
    return this;
  }

  _SuperCustomOverlayBuilder withDebounce(bool enabled) {
    _debounce = enabled;
    return this;
  }

  _SuperCustomOverlayBuilder withDisplayTime(Duration displayTime) {
    _displayTime = displayTime;
    return this;
  }

  _SuperCustomOverlayBuilder withKeepSingle([bool enabled = true]) {
    _keepSingle = enabled;
    return this;
  }

  _SuperCustomOverlayBuilder withPermanent([bool enabled = true]) {
    _permanent = enabled;
    return this;
  }

  _SuperCustomOverlayBuilder bindPage([bool enabled = true]) {
    _bindPage = enabled;
    return this;
  }

  _SuperCustomOverlayBuilder bindWidget(BuildContext context) {
    _bindWidget = context;
    return this;
  }

  _SuperCustomOverlayBuilder withIgnoreArea(Rect area) {
    _ignoreArea = area;
    return this;
  }

  _SuperCustomOverlayBuilder withController(SuperOverlayController controller) {
    _controller = controller;
    return this;
  }

  _SuperCustomOverlayBuilder withPenetrate([bool enabled = true]) {
    _usePenetrate = enabled;
    return this;
  }

  _SuperCustomOverlayBuilder withBack({
    BackType type = BackType.normal,
    SuperOverlayOnBack? onBack,
  }) {
    _backType = type;
    _onBack = onBack;
    return this;
  }

  _SuperCustomOverlayBuilder onDismiss(VoidCallback callback) {
    _onDismiss = callback;
    return this;
  }

  _SuperCustomOverlayBuilder onMask(VoidCallback callback) {
    _onMask = callback;
    return this;
  }

  _SuperCustomOverlayBuilder withAwait(AwaitCompletion completion) {
    _awaitCompletion = completion;
    return this;
  }

  Future<T?> fire<T>() {
    final custom = overlayConfig.custom;
    return OverlayManager.instance.show<T>(
      param: ShowCustomParam(
        builder: _builder,
        alignment: _alignment,
        clickMaskDismiss: _clickMaskDismiss,
        animationType: custom.animationType,
        nonAnimationTypes: custom.nonAnimationTypes,
        animationBuilder: null,
        usePenetrate: _usePenetrate,
        useAnimation: custom.useAnimation,
        animationTime: custom.animationTime,
        maskColor: _maskColor ?? custom.maskColor,
        maskWidget: _maskWidget ?? custom.maskWidget,
        onDismiss: _onDismiss,
        onMask: _onMask,
        awaitCompletion: _awaitCompletion,
        debounce: _debounce,
        debounceTime: custom.debounceTime,
        displayTime: _displayTime,
        tag: _tag,
        businessTag: _businessTag,
        keepSingle: _keepSingle,
        permanent: _permanent,
        bindPage: _bindPage,
        bindWidget: _bindWidget,
        ignoreArea: _ignoreArea,
        maskTriggerType: _maskTriggerType,
        controller: _controller,
        backType: _backType,
        onBack: _onBack,
      ),
    );
  }
}
