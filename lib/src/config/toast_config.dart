import 'package:flutter/material.dart';

import 'enum_config.dart';

class ToastConfig {
  const ToastConfig({
    this.alignment = Alignment.bottomCenter,
    this.animationType = AnimationType.fade,
    this.animationTime = const Duration(milliseconds: 200),
    this.useAnimation = true,
    this.usePenetrate = true,
    this.maskColor = const Color.fromRGBO(0, 0, 0, 0.46),
    this.maskWidget,
    this.clickMaskDismiss = false,
    this.debounce = false,
    this.debounceTime = const Duration(milliseconds: 300),
    this.displayType = ToastDisplayType.normal,
    this.consumeEvent = false,
    this.displayTime = const Duration(milliseconds: 2000),
    this.maskTriggerType = MaskTriggerType.up,
    this.nonAnimationTypes = const [NonAnimationType.close],
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
  final ToastDisplayType displayType;
  final bool consumeEvent;
  final Duration displayTime;
  final MaskTriggerType maskTriggerType;
  final List<NonAnimationType> nonAnimationTypes;
}
