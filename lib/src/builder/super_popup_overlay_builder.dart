part of '../super_overlay_core.dart';

class SuperPopupOverlayBuilder {
  SuperPopupOverlayBuilder({
    required this.targetContext,
    required WidgetBuilder builder,
  }) : _builder = builder;

  final BuildContext? targetContext;
  WidgetBuilder _builder;
  Alignment _alignment = SuperOverlay.config.attach.alignment;
  Color? _maskColor = Colors.transparent;
  Widget? _maskWidget;
  bool _clickMaskDismiss = SuperOverlay.config.attach.clickMaskDismiss;
  String? _tag;
  HighlightConfig? _highlight;
  PopupTargetRectBuilder? _targetRectBuilder;
  PopupTargetPointBuilder? _targetPointBuilder;
  PopupAlignmentMode _alignmentMode = SuperOverlay.config.attach.alignmentMode;
  PopupReplacementBuilder? _replacementBuilder;
  PopupAdjustmentBuilder? _adjustmentBuilder;
  PopupScaleOriginBuilder? _scaleOriginBuilder;
  Rect? _maskIgnoreArea;
  SuperOverlayController? _controller;
  BackType _backType = SuperOverlay.config.attach.backType;
  SuperOverlayOnBack? _onBack;
  AwaitCompletion _awaitCompletion = SuperOverlay.config.attach.awaitCompletion;

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

  SuperPopupOverlayBuilder withTargetPoint(PopupTargetPointBuilder builder) {
    _targetPointBuilder = builder;
    return this;
  }

  SuperPopupOverlayBuilder withAlignmentMode(PopupAlignmentMode mode) {
    _alignmentMode = mode;
    return this;
  }

  SuperPopupOverlayBuilder withReplacement(PopupReplacementBuilder builder) {
    _replacementBuilder = builder;
    return this;
  }

  SuperPopupOverlayBuilder withAdjustment(PopupAdjustmentBuilder builder) {
    _adjustmentBuilder = builder;
    return this;
  }

  SuperPopupOverlayBuilder withScaleOrigin(PopupScaleOriginBuilder builder) {
    _scaleOriginBuilder = builder;
    return this;
  }

  SuperPopupOverlayBuilder withMaskIgnoreArea(Rect area) {
    _maskIgnoreArea = area;
    return this;
  }

  SuperPopupOverlayBuilder withController(SuperOverlayController controller) {
    _controller = controller;
    return this;
  }

  SuperPopupOverlayBuilder withAwait(AwaitCompletion completion) {
    _awaitCompletion = completion;
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
        awaitCompletion: _awaitCompletion,
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
        controller: _controller,
        backType: _backType,
        onBack: _onBack,
        targetContext: targetContext,
        targetRectBuilder: _targetRectBuilder,
        targetPointBuilder: _targetPointBuilder,
        alignmentMode: _alignmentMode,
        replacementBuilder: _replacementBuilder,
        adjustmentBuilder: _adjustmentBuilder,
        scaleOriginBuilder: _scaleOriginBuilder,
        maskIgnoreArea: _maskIgnoreArea,
        highlight: _highlight,
      ),
    );
  }
}
