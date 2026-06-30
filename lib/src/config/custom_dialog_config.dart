import 'package:flutter/material.dart';

import 'enum_config.dart';

class CustomDialogConfig {
  const CustomDialogConfig({
    this.alignment = Alignment.center,
    this.animationType = AnimationType.centerScaleOtherSlide,
    this.animationTime = const Duration(milliseconds: 200),
    this.useAnimation = true,
    this.usePenetrate = false,
    this.maskColor = const Color.fromRGBO(0, 0, 0, 0.46),
    this.maskWidget,
    this.clickMaskDismiss = true,
    this.debounce = false,
    this.debounceTime = const Duration(milliseconds: 300),
    this.bindPage = true,
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
  final bool debounce;
  final Duration debounceTime;
  final bool bindPage;
  final MaskTriggerType maskTriggerType;
  final List<NonAnimationType> nonAnimationTypes;
  final BackType backType;
}
