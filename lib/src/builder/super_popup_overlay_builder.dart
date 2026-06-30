part of '../super_overlay_core.dart';

class SuperPopupOverlayBuilder {
  SuperPopupOverlayBuilder({
    required this.targetContext,
    required WidgetBuilder builder,
  }) : _builder = builder;

  final BuildContext targetContext;
  WidgetBuilder _builder;
  Alignment _alignment = SuperOverlay.config.attach.alignment;
  Color? _maskColor = Colors.transparent;
  Widget? _maskWidget;
  bool _clickMaskDismiss = SuperOverlay.config.attach.clickMaskDismiss;
  String? _tag;
  HighlightConfig? _highlight;
  PopupTargetRectBuilder? _targetRectBuilder;
  BackType _backType = SuperOverlay.config.attach.backType;
  SuperOverlayOnBack? _onBack;

  SuperPopupOverlayBuilder withBuilder(WidgetBuilder builder) {
    _builder = builder;
    return this;
  }

  SuperPopupOverlayBuilder withAlignment(Alignment alignment) {
    _alignment = alignment;
    return this;
  }

  SuperPopupOverlayBuilder withMask({
    Color? color,
    Widget? widget,
    bool dismissible = true,
  }) {
    _maskColor = color ?? _maskColor;
    _maskWidget = widget;
    _clickMaskDismiss = dismissible;
    return this;
  }

  SuperPopupOverlayBuilder withTag(String tag) {
    _tag = tag;
    return this;
  }

  SuperPopupOverlayBuilder withHighlight({
    Color? maskColor,
    EdgeInsets padding = EdgeInsets.zero,
    BorderRadius borderRadius = BorderRadius.zero,
  }) {
    _highlight = HighlightConfig(padding: padding, borderRadius: borderRadius);
    if (maskColor != null) {
      _maskColor = maskColor;
    } else if (_maskColor == Colors.transparent) {
      _maskColor = SuperOverlay.config.attach.maskColor;
    }
    return this;
  }

  SuperPopupOverlayBuilder withTargetRect(PopupTargetRectBuilder builder) {
    _targetRectBuilder = builder;
    return this;
  }

  SuperPopupOverlayBuilder withBack({
    BackType type = BackType.normal,
    SuperOverlayOnBack? onBack,
  }) {
    _backType = type;
    _onBack = onBack;
    return this;
  }

  Future<T?> fire<T>() {
    final attach = SuperOverlay.config.attach;
    return OverlayManager.instance.showAttach<T>(
      param: ShowAttachParam(
        builder: _builder,
        alignment: _alignment,
        clickMaskDismiss: _clickMaskDismiss,
        animationType: attach.animationType,
        nonAnimationTypes: attach.nonAnimationTypes,
        animationBuilder: null,
        usePenetrate: attach.usePenetrate,
        useAnimation: attach.useAnimation,
        animationTime: attach.animationTime,
        maskColor: _maskColor ?? attach.maskColor,
        maskWidget: _maskWidget ?? attach.maskWidget,
        onDismiss: null,
        onMask: null,
        debounce: attach.debounce,
        debounceTime: attach.debounceTime,
        displayTime: null,
        tag: _tag,
        keepSingle: false,
        permanent: false,
        bindPage: attach.bindPage,
        bindWidget: targetContext,
        ignoreArea: null,
        maskTriggerType: attach.maskTriggerType,
        controller: null,
        backType: _backType,
        onBack: _onBack,
        targetContext: targetContext,
        targetRectBuilder: _targetRectBuilder,
        highlight: _highlight,
      ),
    );
  }
}
