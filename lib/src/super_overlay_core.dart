import 'package:flutter/material.dart';

import 'config/enum_config.dart';
import 'config/overlay_config.dart';
import 'data/show_param.dart';
import 'helper/overlay_manager.dart';
import 'kit/overlay_controller.dart';
import 'kit/typedef.dart';
import 'widget/default/loading_widget.dart';
import 'widget/default/toast_widget.dart';

class SuperOverlay {
  static final OverlayConfig config = OverlayConfig();

  static SuperCustomOverlayBuilder show({required WidgetBuilder builder}) {
    return SuperCustomOverlayBuilder(builder: builder);
  }

  static SuperLoadingOverlayBuilder showLoading({
    String msg = '',
    WidgetBuilder? builder,
  }) {
    return SuperLoadingOverlayBuilder(message: msg, builder: builder);
  }

  static SuperToastOverlayBuilder showToast(
    String message, {
    WidgetBuilder? builder,
  }) {
    return SuperToastOverlayBuilder(message: message, builder: builder);
  }

  static SuperPopupOverlayBuilder showPopup({
    required BuildContext targetContext,
    required WidgetBuilder builder,
  }) {
    return SuperPopupOverlayBuilder(
      targetContext: targetContext,
      builder: builder,
    );
  }

  static SuperNotifyOverlayBuilder showNotify({
    required String msg,
    required NotifyType type,
    WidgetBuilder? builder,
  }) {
    return SuperNotifyOverlayBuilder(
      message: msg,
      type: type,
      builder: builder,
    );
  }

  static Future<void> dismiss<T>({
    DismissStatus status = DismissStatus.auto,
    String? tag,
    T? result,
    bool force = false,
  }) {
    return OverlayManager.instance.dismiss<T>(
      status: status,
      tag: tag,
      result: result,
      force: force,
    );
  }

  static bool checkExist({
    String? tag,
    Set<OverlayType> dialogTypes = const {
      OverlayType.custom,
      OverlayType.attach,
      OverlayType.loading,
    },
  }) {
    return OverlayManager.instance.checkExist(tag: tag, types: dialogTypes);
  }
}

class SuperCustomOverlayBuilder {
  SuperCustomOverlayBuilder({required WidgetBuilder builder})
    : _builder = builder;

  WidgetBuilder _builder;
  Color? _maskColor;
  Widget? _maskWidget;
  bool _clickMaskDismiss = SuperOverlay.config.custom.clickMaskDismiss;
  Alignment _alignment = SuperOverlay.config.custom.alignment;
  bool _debounce = SuperOverlay.config.custom.debounce;
  Duration? _displayTime;
  String? _tag;
  bool _keepSingle = false;
  bool _permanent = false;
  bool _bindPage = SuperOverlay.config.custom.bindPage;
  BuildContext? _bindWidget;
  Rect? _ignoreArea;
  MaskTriggerType _maskTriggerType = SuperOverlay.config.custom.maskTriggerType;
  SuperOverlayController? _controller;
  BackType _backType = SuperOverlay.config.custom.backType;
  SuperOverlayOnBack? _onBack;
  VoidCallback? _onDismiss;
  VoidCallback? _onMask;

  SuperCustomOverlayBuilder withBuilder(WidgetBuilder builder) {
    _builder = builder;
    return this;
  }

  SuperCustomOverlayBuilder withMask({
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

  SuperCustomOverlayBuilder withAlignment(Alignment alignment) {
    _alignment = alignment;
    return this;
  }

  SuperCustomOverlayBuilder withTag(String tag) {
    _tag = tag;
    return this;
  }

  SuperCustomOverlayBuilder withDebounce(bool enabled) {
    _debounce = enabled;
    return this;
  }

  SuperCustomOverlayBuilder withDisplayTime(Duration displayTime) {
    _displayTime = displayTime;
    return this;
  }

  SuperCustomOverlayBuilder withKeepSingle([bool enabled = true]) {
    _keepSingle = enabled;
    return this;
  }

  SuperCustomOverlayBuilder withPermanent([bool enabled = true]) {
    _permanent = enabled;
    return this;
  }

  SuperCustomOverlayBuilder bindPage([bool enabled = true]) {
    _bindPage = enabled;
    return this;
  }

  SuperCustomOverlayBuilder bindWidget(BuildContext context) {
    _bindWidget = context;
    return this;
  }

  SuperCustomOverlayBuilder withIgnoreArea(Rect area) {
    _ignoreArea = area;
    return this;
  }

  SuperCustomOverlayBuilder withController(SuperOverlayController controller) {
    _controller = controller;
    return this;
  }

  SuperCustomOverlayBuilder withBack({
    BackType type = BackType.normal,
    SuperOverlayOnBack? onBack,
  }) {
    _backType = type;
    _onBack = onBack;
    return this;
  }

  SuperCustomOverlayBuilder onDismiss(VoidCallback callback) {
    _onDismiss = callback;
    return this;
  }

  SuperCustomOverlayBuilder onMask(VoidCallback callback) {
    _onMask = callback;
    return this;
  }

  Future<T?> fire<T>() {
    final custom = SuperOverlay.config.custom;
    return OverlayManager.instance.show<T>(
      param: ShowCustomParam(
        builder: _builder,
        alignment: _alignment,
        clickMaskDismiss: _clickMaskDismiss,
        animationType: custom.animationType,
        nonAnimationTypes: custom.nonAnimationTypes,
        animationBuilder: null,
        usePenetrate: custom.usePenetrate,
        useAnimation: custom.useAnimation,
        animationTime: custom.animationTime,
        maskColor: _maskColor ?? custom.maskColor,
        maskWidget: _maskWidget ?? custom.maskWidget,
        onDismiss: _onDismiss,
        onMask: _onMask,
        debounce: _debounce,
        displayTime: _displayTime,
        tag: _tag,
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
        backType: loading.backType,
        onBack: null,
      ),
    );
  }
}

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
        debounce: _debounce,
        displayType: _displayType,
        consumeEvent: _consumeEvent,
      ),
    );
    return Future<T?>.value();
  }
}

class SuperPopupOverlayBuilder {
  SuperPopupOverlayBuilder({
    required this.targetContext,
    required this.builder,
  });

  final BuildContext targetContext;
  final WidgetBuilder builder;

  Future<T?> fire<T>() => Future<T?>.value();
}

class SuperNotifyOverlayBuilder {
  SuperNotifyOverlayBuilder({
    required this.message,
    required this.type,
    required this.builder,
  });

  final String message;
  final NotifyType type;
  final WidgetBuilder? builder;

  Future<T?> fire<T>() => Future<T?>.value();
}
