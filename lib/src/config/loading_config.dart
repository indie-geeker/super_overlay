import 'package:flutter/material.dart';

import 'enum_config.dart';

class LoadingConfig {
  const LoadingConfig({
    this.alignment = Alignment.center,
    this.animationType = AnimationType.fade,
    this.animationTime = const Duration(milliseconds: 200),
    this.useAnimation = true,
    this.usePenetrate = false,
    this.maskColor = const Color.fromRGBO(0, 0, 0, 0.46),
    this.maskWidget,
    this.clickMaskDismiss = false,
    this.leastLoadingTime = Duration.zero,
    this.maskTriggerType = MaskTriggerType.up,
    this.nonAnimationTypes = const [
      NonAnimationType.routeClose,
      NonAnimationType.close,
    ],
    this.backType = BackType.normal,
  });

  final Alignment alignment;
  final AnimationType animationType;
  final Duration animationTime;
  final bool useAnimation;
  final bool usePenetrate;
  final Color maskColor;
  final Widget? maskWidget;
  final bool clickMaskDismiss;
  final Duration leastLoadingTime;
  final MaskTriggerType maskTriggerType;
  final List<NonAnimationType> nonAnimationTypes;
  final BackType backType;
}
