part of '../super_overlay_core.dart';

class _SuperToastOverlayBuilder {
  _SuperToastOverlayBuilder({
    required this.message,
    required WidgetBuilder? builder,
  }) : _builder = builder;

  final String message;
  WidgetBuilder? _builder;
  Duration _displayTime = overlayConfig.toast.displayTime;
  ToastDisplayType _displayType = overlayConfig.toast.displayType;
  Alignment _alignment = overlayConfig.toast.alignment;
  bool _consumeEvent = overlayConfig.toast.consumeEvent;
  bool _debounce = overlayConfig.toast.debounce;
  String? _tag;
  String? _businessTag;
  bool _keepSingle = false;
  bool _replaceExisting = false;
  SuperOverlayController? _controller;
  AwaitCompletion _awaitCompletion = overlayConfig.toast.awaitCompletion;

  _SuperToastOverlayBuilder withBuilder(WidgetBuilder builder) {
    _builder = builder;
    return this;
  }

  _SuperToastOverlayBuilder withDisplayTime(Duration displayTime) {
    _displayTime = displayTime;
    return this;
  }

  _SuperToastOverlayBuilder withDisplayType(ToastDisplayType displayType) {
    _displayType = displayType;
    return this;
  }

  _SuperToastOverlayBuilder withAlignment(Alignment alignment) {
    _alignment = alignment;
    return this;
  }

  _SuperToastOverlayBuilder withTag(String tag) {
    _tag = tag;
    return this;
  }

  _SuperToastOverlayBuilder _withBusinessTag(String? tag) {
    _businessTag = tag;
    return this;
  }

  _SuperToastOverlayBuilder withConsumeEvent(bool enabled) {
    _consumeEvent = enabled;
    return this;
  }

  _SuperToastOverlayBuilder withDebounce(bool enabled) {
    _debounce = enabled;
    return this;
  }

  _SuperToastOverlayBuilder withKeepSingle([bool enabled = true]) {
    _keepSingle = enabled;
    return this;
  }

  _SuperToastOverlayBuilder withReplaceExisting([bool enabled = true]) {
    _replaceExisting = enabled;
    return this;
  }

  _SuperToastOverlayBuilder withController(SuperOverlayController controller) {
    _controller = controller;
    return this;
  }

  _SuperToastOverlayBuilder withAwait(AwaitCompletion completion) {
    _awaitCompletion = completion;
    return this;
  }

  Future<T?> fire<T>() {
    return OverlayManager.instance.showToast<T>(param: _buildParam());
  }

  OverlayRuntimeResult<T> _fireCommand<T>(int generation) {
    final result = ToastTool.instance.showCommand<T>(
      _buildParam(),
      generation: generation,
    );
    final controller = _controller;
    if (controller == null ||
        (result.identityTag != null && result.identityTag != _tag)) {
      return result;
    }
    return OverlayRuntimeResult<T>(
      visible: controller.visible,
      closed: result.closed,
      identityTag: result.identityTag,
      refresh: result.refresh ?? controller.refresh,
    );
  }

  ShowToastParam _buildParam() {
    final toast = overlayConfig.toast;
    return ShowToastParam(
      builder:
          _builder ??
          (_) => toast.builder?.call(message) ?? ToastWidget(message: message),
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
      awaitCompletion: _awaitCompletion,
      accessibilityMode: OverlayAccessibilityMode.liveRegion,
      requestFocus: false,
      semanticsLabel: null,
      barrierSemanticsLabel: null,
      controller: _controller,
      displayTime: _displayTime,
      debounceTime: toast.debounceTime,
      debounce: _debounce,
      displayType: _displayType,
      consumeEvent: _consumeEvent,
      tag: _tag,
      businessTag: _businessTag,
      keepSingle: _keepSingle,
      replaceExisting: _replaceExisting,
    );
  }
}
