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
  String? _tag;
  String? _businessTag;
  bool _keepSingle = false;
  bool _replaceExisting = false;
  AwaitCompletion _awaitCompletion = SuperOverlay.config.toast.awaitCompletion;

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

  SuperToastOverlayBuilder withTag(String tag) {
    _tag = tag;
    return this;
  }

  SuperToastOverlayBuilder _withBusinessTag(String? tag) {
    _businessTag = tag;
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

  SuperToastOverlayBuilder withKeepSingle([bool enabled = true]) {
    _keepSingle = enabled;
    return this;
  }

  SuperToastOverlayBuilder withReplaceExisting([bool enabled = true]) {
    _replaceExisting = enabled;
    return this;
  }

  SuperToastOverlayBuilder withAwait(AwaitCompletion completion) {
    _awaitCompletion = completion;
    return this;
  }

  Future<T?> fire<T>() {
    return OverlayManager.instance.showToast<T>(param: _buildParam());
  }

  ToastShowResult<T> _fireCommand<T>() {
    return ToastTool.instance.showCommand<T>(_buildParam());
  }

  ShowToastParam _buildParam() {
    final toast = SuperOverlay.config.toast;
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
