part of '../super_overlay_core.dart';

class _SuperPopupOverlayBuilder {
  _SuperPopupOverlayBuilder({
    required this.targetContext,
    required WidgetBuilder builder,
    OverlayRouteOwner? routeOwner,
    this.themes,
  }) : _builder = builder,
       _routeOwner = routeOwner;

  final BuildContext? targetContext;
  WidgetBuilder _builder;
  final OverlayRouteOwner? _routeOwner;
  final CapturedThemes? themes;
  Alignment _alignment = overlayConfig.attach.alignment;
  Color? _maskColor = Colors.transparent;
  Widget? _maskWidget;
  bool _clickMaskDismiss = overlayConfig.attach.clickMaskDismiss;
  String? _tag;
  String? _businessTag;
  HighlightConfig? _highlight;
  PopupTargetRectBuilder? _targetRectBuilder;
  PopupTargetPointBuilder? _targetPointBuilder;
  PopupAlignmentMode _alignmentMode = overlayConfig.attach.alignmentMode;
  PopupReplacementBuilder? _replacementBuilder;
  PopupAdjustmentBuilder? _adjustmentBuilder;
  PopupScaleOriginBuilder? _scaleOriginBuilder;
  Rect? _maskIgnoreArea;
  SuperOverlayController? _controller;
  Duration? _displayTime;
  bool _keepSingle = false;
  bool _bindPage = overlayConfig.attach.bindPage;
  BackType _backType = overlayConfig.attach.backType;
  SuperOverlayOnBack? _onBack;
  AwaitCompletion _awaitCompletion = overlayConfig.attach.awaitCompletion;
  bool _requestFocus = false;

  _SuperPopupOverlayBuilder withBuilder(WidgetBuilder builder) {
    _builder = builder;
    return this;
  }

  _SuperPopupOverlayBuilder withAlignment(Alignment alignment) {
    _alignment = alignment;
    return this;
  }

  _SuperPopupOverlayBuilder withDisplayTime(Duration displayTime) {
    _displayTime = displayTime;
    return this;
  }

  _SuperPopupOverlayBuilder withMask({
    Color? color,
    Widget? widget,
    bool dismissible = true,
  }) {
    _maskColor = color ?? _maskColor;
    _maskWidget = widget;
    _clickMaskDismiss = dismissible;
    return this;
  }

  _SuperPopupOverlayBuilder withTag(String tag) {
    _tag = tag;
    return this;
  }

  _SuperPopupOverlayBuilder _withBusinessTag(String? tag) {
    _businessTag = tag;
    return this;
  }

  _SuperPopupOverlayBuilder withKeepSingle([bool enabled = true]) {
    _keepSingle = enabled;
    return this;
  }

  _SuperPopupOverlayBuilder bindPage([bool enabled = true]) {
    _bindPage = enabled;
    return this;
  }

  _SuperPopupOverlayBuilder withHighlight({
    Color? maskColor,
    EdgeInsets padding = EdgeInsets.zero,
    BorderRadius borderRadius = BorderRadius.zero,
  }) {
    _highlight = HighlightConfig(padding: padding, borderRadius: borderRadius);
    if (maskColor != null) {
      _maskColor = maskColor;
    } else if (_maskColor == Colors.transparent) {
      _maskColor = overlayConfig.attach.maskColor;
    }
    return this;
  }

  _SuperPopupOverlayBuilder withTargetRect(PopupTargetRectBuilder builder) {
    _targetRectBuilder = builder;
    return this;
  }

  _SuperPopupOverlayBuilder withTargetPoint(PopupTargetPointBuilder builder) {
    _targetPointBuilder = builder;
    return this;
  }

  _SuperPopupOverlayBuilder withAlignmentMode(PopupAlignmentMode mode) {
    _alignmentMode = mode;
    return this;
  }

  _SuperPopupOverlayBuilder withReplacement(PopupReplacementBuilder builder) {
    _replacementBuilder = builder;
    return this;
  }

  _SuperPopupOverlayBuilder withAdjustment(PopupAdjustmentBuilder builder) {
    _adjustmentBuilder = builder;
    return this;
  }

  _SuperPopupOverlayBuilder withScaleOrigin(PopupScaleOriginBuilder builder) {
    _scaleOriginBuilder = builder;
    return this;
  }

  _SuperPopupOverlayBuilder withMaskIgnoreArea(Rect area) {
    _maskIgnoreArea = area;
    return this;
  }

  _SuperPopupOverlayBuilder withController(SuperOverlayController controller) {
    _controller = controller;
    return this;
  }

  _SuperPopupOverlayBuilder withAwait(AwaitCompletion completion) {
    _awaitCompletion = completion;
    return this;
  }

  _SuperPopupOverlayBuilder withAccessibility({required bool requestFocus}) {
    _requestFocus = requestFocus;
    return this;
  }

  _SuperPopupOverlayBuilder withBack({
    BackType type = BackType.normal,
    SuperOverlayOnBack? onBack,
  }) {
    _backType = type;
    _onBack = onBack;
    return this;
  }

  Future<T?> fire<T>() {
    final attach = overlayConfig.attach;
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
        accessibilityMode: OverlayAccessibilityMode.popup,
        requestFocus: _requestFocus,
        semanticsLabel: null,
        barrierSemanticsLabel: null,
        debounce: attach.debounce,
        debounceTime: attach.debounceTime,
        displayTime: _displayTime,
        tag: _tag,
        businessTag: _businessTag,
        keepSingle: _keepSingle,
        permanent: false,
        bindPage: _bindPage,
        bindWidget: targetContext,
        ignoreArea: null,
        maskTriggerType: attach.maskTriggerType,
        controller: _controller,
        backType: _backType,
        onBack: _onBack,
        routeOwner: _routeOwner,
        themes: themes,
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
