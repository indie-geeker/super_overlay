import 'package:flutter/material.dart';

import '../data/notify_style.dart';
import 'enum_config.dart';

class NotifyConfig {
  const NotifyConfig({
    this.alignment = Alignment.topCenter,
    this.animationType = AnimationType.fade,
    this.animationTime = const Duration(milliseconds: 200),
    this.useAnimation = true,
    this.usePenetrate = true,
    this.maskColor = const Color.fromRGBO(0, 0, 0, 0.46),
    this.maskWidget,
    this.clickMaskDismiss = false,
    this.debounce = false,
    this.debounceTime = const Duration(milliseconds: 300),
    this.displayTime = const Duration(milliseconds: 2500),
    this.maskTriggerType = MaskTriggerType.up,
    this.nonAnimationTypes = const [NonAnimationType.close],
    this.backType = BackType.ignore,
    this.style,
    this.awaitCompletion = AwaitCompletion.dismiss,
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
  final Duration? displayTime;
  final MaskTriggerType maskTriggerType;
  final List<NonAnimationType> nonAnimationTypes;
  final BackType backType;
  final NotifyStyle? style;
  final AwaitCompletion awaitCompletion;

  NotifyConfig copyWith({NotifyStyle? style}) {
    return NotifyConfig(
      alignment: alignment,
      animationType: animationType,
      animationTime: animationTime,
      useAnimation: useAnimation,
      usePenetrate: usePenetrate,
      maskColor: maskColor,
      maskWidget: maskWidget,
      clickMaskDismiss: clickMaskDismiss,
      debounce: debounce,
      debounceTime: debounceTime,
      displayTime: displayTime,
      maskTriggerType: maskTriggerType,
      nonAnimationTypes: nonAnimationTypes,
      backType: backType,
      style: style ?? this.style,
      awaitCompletion: awaitCompletion,
    );
  }
}
