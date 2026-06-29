import 'package:flutter/material.dart';

import 'config/enum_config.dart';
import 'config/overlay_config.dart';
import 'data/show_param.dart';
import 'helper/overlay_manager.dart';
import 'kit/typedef.dart';

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
  }) {
    _maskColor = color;
    _maskWidget = widget;
    _clickMaskDismiss = dismissible;
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
        backType: _backType,
        onBack: _onBack,
      ),
    );
  }
}

class SuperLoadingOverlayBuilder {
  SuperLoadingOverlayBuilder({required this.message, required this.builder});

  final String message;
  final WidgetBuilder? builder;

  Future<T?> fire<T>() => Future<T?>.value();
}

class SuperToastOverlayBuilder {
  SuperToastOverlayBuilder({required this.message, required this.builder});

  final String message;
  final WidgetBuilder? builder;

  Future<T?> fire<T>() => Future<T?>.value();
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
