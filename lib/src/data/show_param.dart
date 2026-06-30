import 'package:flutter/material.dart';

import '../config/enum_config.dart';
import '../kit/overlay_controller.dart';
import '../kit/typedef.dart';

class HighlightConfig {
  const HighlightConfig({
    this.padding = EdgeInsets.zero,
    this.borderRadius = BorderRadius.zero,
  });

  final EdgeInsets padding;
  final BorderRadius borderRadius;
}

class ShowParamBase {
  const ShowParamBase({
    required this.builder,
    required this.alignment,
    required this.clickMaskDismiss,
    required this.animationType,
    required this.nonAnimationTypes,
    required this.animationBuilder,
    required this.usePenetrate,
    required this.useAnimation,
    required this.animationTime,
    required this.maskColor,
    required this.maskWidget,
    required this.onDismiss,
    required this.onMask,
  });

  final WidgetBuilder builder;
  final Alignment alignment;
  final bool clickMaskDismiss;
  final AnimationType animationType;
  final List<NonAnimationType> nonAnimationTypes;
  final AnimationBuilder? animationBuilder;
  final bool usePenetrate;
  final bool useAnimation;
  final Duration animationTime;
  final Color maskColor;
  final Widget? maskWidget;
  final VoidCallback? onDismiss;
  final VoidCallback? onMask;
}

class ShowCustomParam extends ShowParamBase {
  const ShowCustomParam({
    required super.builder,
    required super.alignment,
    required super.clickMaskDismiss,
    required super.animationType,
    required super.nonAnimationTypes,
    required super.animationBuilder,
    required super.usePenetrate,
    required super.useAnimation,
    required super.animationTime,
    required super.maskColor,
    required super.maskWidget,
    required super.onDismiss,
    required super.onMask,
    required this.debounce,
    required this.debounceTime,
    required this.displayTime,
    required this.tag,
    required this.keepSingle,
    required this.permanent,
    required this.bindPage,
    required this.bindWidget,
    required this.ignoreArea,
    required this.maskTriggerType,
    required this.controller,
    required this.backType,
    required this.onBack,
  });

  final bool debounce;
  final Duration debounceTime;
  final Duration? displayTime;
  final String? tag;
  final bool keepSingle;
  final bool permanent;
  final bool bindPage;
  final BuildContext? bindWidget;
  final Rect? ignoreArea;
  final MaskTriggerType maskTriggerType;
  final SuperOverlayController? controller;
  final BackType backType;
  final SuperOverlayOnBack? onBack;

  ShowCustomParam copyWith({
    WidgetBuilder? builder,
    Alignment? alignment,
    bool? clickMaskDismiss,
    AnimationType? animationType,
    List<NonAnimationType>? nonAnimationTypes,
    AnimationBuilder? animationBuilder,
    bool? usePenetrate,
    bool? useAnimation,
    Duration? animationTime,
    Color? maskColor,
    Widget? maskWidget,
    VoidCallback? onDismiss,
    VoidCallback? onMask,
    bool? debounce,
    Duration? debounceTime,
    Duration? displayTime,
    String? tag,
    bool? keepSingle,
    bool? permanent,
    bool? bindPage,
    BuildContext? bindWidget,
    Rect? ignoreArea,
    MaskTriggerType? maskTriggerType,
    SuperOverlayController? controller,
    BackType? backType,
    SuperOverlayOnBack? onBack,
  }) {
    return ShowCustomParam(
      builder: builder ?? this.builder,
      alignment: alignment ?? this.alignment,
      clickMaskDismiss: clickMaskDismiss ?? this.clickMaskDismiss,
      animationType: animationType ?? this.animationType,
      nonAnimationTypes: nonAnimationTypes ?? this.nonAnimationTypes,
      animationBuilder: animationBuilder ?? this.animationBuilder,
      usePenetrate: usePenetrate ?? this.usePenetrate,
      useAnimation: useAnimation ?? this.useAnimation,
      animationTime: animationTime ?? this.animationTime,
      maskColor: maskColor ?? this.maskColor,
      maskWidget: maskWidget ?? this.maskWidget,
      onDismiss: onDismiss ?? this.onDismiss,
      onMask: onMask ?? this.onMask,
      debounce: debounce ?? this.debounce,
      debounceTime: debounceTime ?? this.debounceTime,
      displayTime: displayTime ?? this.displayTime,
      tag: tag ?? this.tag,
      keepSingle: keepSingle ?? this.keepSingle,
      permanent: permanent ?? this.permanent,
      bindPage: bindPage ?? this.bindPage,
      bindWidget: bindWidget ?? this.bindWidget,
      ignoreArea: ignoreArea ?? this.ignoreArea,
      maskTriggerType: maskTriggerType ?? this.maskTriggerType,
      controller: controller ?? this.controller,
      backType: backType ?? this.backType,
      onBack: onBack ?? this.onBack,
    );
  }
}

class ShowAttachParam extends ShowCustomParam {
  const ShowAttachParam({
    required super.builder,
    required super.alignment,
    required super.clickMaskDismiss,
    required super.animationType,
    required super.nonAnimationTypes,
    required super.animationBuilder,
    required super.usePenetrate,
    required super.useAnimation,
    required super.animationTime,
    required super.maskColor,
    required super.maskWidget,
    required super.onDismiss,
    required super.onMask,
    required super.debounce,
    required super.debounceTime,
    required super.displayTime,
    required super.tag,
    required super.keepSingle,
    required super.permanent,
    required super.bindPage,
    required super.bindWidget,
    required super.ignoreArea,
    required super.maskTriggerType,
    required super.controller,
    required super.backType,
    required super.onBack,
    required this.targetContext,
    required this.targetRectBuilder,
    required this.highlight,
  });

  final BuildContext? targetContext;
  final PopupTargetRectBuilder? targetRectBuilder;
  final HighlightConfig? highlight;
}

class ShowLoadingParam extends ShowParamBase {
  const ShowLoadingParam({
    required super.builder,
    required super.alignment,
    required super.clickMaskDismiss,
    required super.animationType,
    required super.nonAnimationTypes,
    required super.animationBuilder,
    required super.usePenetrate,
    required super.useAnimation,
    required super.animationTime,
    required super.maskColor,
    required super.maskWidget,
    required super.onDismiss,
    required super.onMask,
    required this.displayTime,
    required this.leastLoadingTime,
    required this.backType,
    required this.onBack,
  });

  final Duration? displayTime;
  final Duration leastLoadingTime;
  final BackType backType;
  final SuperOverlayOnBack? onBack;
}

class ShowToastParam extends ShowParamBase {
  const ShowToastParam({
    required super.builder,
    required super.alignment,
    required super.clickMaskDismiss,
    required super.animationType,
    required super.nonAnimationTypes,
    required super.animationBuilder,
    required super.usePenetrate,
    required super.useAnimation,
    required super.animationTime,
    required super.maskColor,
    required super.maskWidget,
    required super.onDismiss,
    required super.onMask,
    required this.displayTime,
    required this.debounceTime,
    required this.debounce,
    required this.displayType,
    required this.consumeEvent,
  });

  final Duration displayTime;
  final Duration debounceTime;
  final bool debounce;
  final ToastDisplayType displayType;
  final bool consumeEvent;
}

class ShowNotifyParam extends ShowParamBase {
  const ShowNotifyParam({
    required super.builder,
    required super.alignment,
    required super.clickMaskDismiss,
    required super.animationType,
    required super.nonAnimationTypes,
    required super.animationBuilder,
    required super.usePenetrate,
    required super.useAnimation,
    required super.animationTime,
    required super.maskColor,
    required super.maskWidget,
    required super.onDismiss,
    required super.onMask,
    required this.debounce,
    required this.debounceTime,
    required this.displayTime,
    required this.tag,
    required this.keepSingle,
    required this.backType,
    required this.onBack,
  });

  final bool debounce;
  final Duration debounceTime;
  final Duration? displayTime;
  final String? tag;
  final bool keepSingle;
  final BackType backType;
  final SuperOverlayOnBack? onBack;
}

class MainOverlayParam<T> {
  const MainOverlayParam({
    required this.type,
    required this.showParam,
    required this.tag,
    required this.keepSingle,
    required this.permanent,
  });

  final OverlayType type;
  final ShowParamBase showParam;
  final String? tag;
  final bool keepSingle;
  final bool permanent;
}
