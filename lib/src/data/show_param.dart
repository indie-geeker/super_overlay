import 'package:flutter/material.dart';

import '../config/enum_config.dart';
import '../kit/overlay_controller.dart';
import '../kit/typedef.dart';
import '../helper/overlay_route_owner.dart';

enum OverlayAccessibilityMode { modal, popup, liveRegion }

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
    required this.awaitCompletion,
    this.accessibilityMode = OverlayAccessibilityMode.modal,
    this.requestFocus = true,
    this.semanticsLabel,
    this.barrierSemanticsLabel,
    this.controller,
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
  final AwaitCompletion awaitCompletion;
  final OverlayAccessibilityMode accessibilityMode;
  final bool requestFocus;
  final String? semanticsLabel;
  final String? barrierSemanticsLabel;
  final SuperOverlayController? controller;
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
    required super.awaitCompletion,
    super.accessibilityMode,
    super.requestFocus,
    super.semanticsLabel,
    super.barrierSemanticsLabel,
    required this.debounce,
    required this.debounceTime,
    required this.displayTime,
    required this.tag,
    this.businessTag,
    required this.keepSingle,
    required this.permanent,
    required this.bindPage,
    required this.bindWidget,
    required this.ignoreArea,
    required this.maskTriggerType,
    required super.controller,
    required this.backType,
    required this.onBack,
    this.routeOwner,
  });

  final bool debounce;
  final Duration debounceTime;
  final Duration? displayTime;
  final String? tag;
  final String? businessTag;
  final bool keepSingle;
  final bool permanent;
  final bool bindPage;
  final BuildContext? bindWidget;
  final Rect? ignoreArea;
  final MaskTriggerType maskTriggerType;
  final BackType backType;
  final SuperOverlayOnBack? onBack;
  final OverlayRouteOwner? routeOwner;

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
    AwaitCompletion? awaitCompletion,
    OverlayAccessibilityMode? accessibilityMode,
    bool? requestFocus,
    String? semanticsLabel,
    String? barrierSemanticsLabel,
    bool? debounce,
    Duration? debounceTime,
    Duration? displayTime,
    String? tag,
    String? businessTag,
    bool? keepSingle,
    bool? permanent,
    bool? bindPage,
    BuildContext? bindWidget,
    Rect? ignoreArea,
    MaskTriggerType? maskTriggerType,
    SuperOverlayController? controller,
    BackType? backType,
    SuperOverlayOnBack? onBack,
    OverlayRouteOwner? routeOwner,
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
      awaitCompletion: awaitCompletion ?? this.awaitCompletion,
      accessibilityMode: accessibilityMode ?? this.accessibilityMode,
      requestFocus: requestFocus ?? this.requestFocus,
      semanticsLabel: semanticsLabel ?? this.semanticsLabel,
      barrierSemanticsLabel:
          barrierSemanticsLabel ?? this.barrierSemanticsLabel,
      debounce: debounce ?? this.debounce,
      debounceTime: debounceTime ?? this.debounceTime,
      displayTime: displayTime ?? this.displayTime,
      tag: tag ?? this.tag,
      businessTag: businessTag ?? this.businessTag,
      keepSingle: keepSingle ?? this.keepSingle,
      permanent: permanent ?? this.permanent,
      bindPage: bindPage ?? this.bindPage,
      bindWidget: bindWidget ?? this.bindWidget,
      ignoreArea: ignoreArea ?? this.ignoreArea,
      maskTriggerType: maskTriggerType ?? this.maskTriggerType,
      controller: controller ?? this.controller,
      backType: backType ?? this.backType,
      onBack: onBack ?? this.onBack,
      routeOwner: routeOwner ?? this.routeOwner,
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
    required super.awaitCompletion,
    super.accessibilityMode = OverlayAccessibilityMode.popup,
    super.requestFocus = false,
    super.semanticsLabel,
    super.barrierSemanticsLabel,
    required super.debounce,
    required super.debounceTime,
    required super.displayTime,
    required super.tag,
    super.businessTag,
    required super.keepSingle,
    required super.permanent,
    required super.bindPage,
    required super.bindWidget,
    required super.ignoreArea,
    required super.maskTriggerType,
    required super.controller,
    required super.backType,
    required super.onBack,
    super.routeOwner,
    required this.targetContext,
    required this.targetRectBuilder,
    required this.targetPointBuilder,
    required this.alignmentMode,
    required this.replacementBuilder,
    required this.adjustmentBuilder,
    required this.scaleOriginBuilder,
    required this.maskIgnoreArea,
    required this.highlight,
  });

  final BuildContext? targetContext;
  final PopupTargetRectBuilder? targetRectBuilder;
  final PopupTargetPointBuilder? targetPointBuilder;
  final PopupAlignmentMode alignmentMode;
  final PopupReplacementBuilder? replacementBuilder;
  final PopupAdjustmentBuilder? adjustmentBuilder;
  final PopupScaleOriginBuilder? scaleOriginBuilder;
  final Rect? maskIgnoreArea;
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
    required super.awaitCompletion,
    super.accessibilityMode,
    super.requestFocus,
    super.semanticsLabel,
    super.barrierSemanticsLabel,
    super.controller,
    required this.displayTime,
    required this.leastLoadingTime,
    required this.tag,
    this.businessTag,
    required this.backType,
    required this.onBack,
  });

  final Duration? displayTime;
  final Duration leastLoadingTime;
  final String? tag;
  final String? businessTag;
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
    required super.awaitCompletion,
    super.accessibilityMode = OverlayAccessibilityMode.liveRegion,
    super.requestFocus = false,
    super.semanticsLabel,
    super.barrierSemanticsLabel,
    super.controller,
    required this.displayTime,
    required this.debounceTime,
    required this.debounce,
    required this.displayType,
    required this.consumeEvent,
    required this.tag,
    this.businessTag,
    required this.keepSingle,
    required this.replaceExisting,
  });

  final Duration displayTime;
  final Duration debounceTime;
  final bool debounce;
  final ToastDisplayType displayType;
  final bool consumeEvent;
  final String? tag;
  final String? businessTag;
  final bool keepSingle;
  final bool replaceExisting;
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
    required super.awaitCompletion,
    super.accessibilityMode = OverlayAccessibilityMode.liveRegion,
    super.requestFocus = false,
    super.semanticsLabel,
    super.barrierSemanticsLabel,
    super.controller,
    required this.debounce,
    required this.debounceTime,
    required this.displayTime,
    required this.tag,
    this.businessTag,
    required this.keepSingle,
    required this.backType,
    required this.onBack,
  });

  final bool debounce;
  final Duration debounceTime;
  final Duration? displayTime;
  final String? tag;
  final String? businessTag;
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
