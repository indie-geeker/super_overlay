import 'package:flutter/material.dart';

class AnimationParam {
  AnimationParam({
    required this.alignment,
    required this.animationTime,
    this.onForward,
    this.onDismiss,
  });

  final Alignment alignment;
  final Duration animationTime;
  VoidCallback? onForward;
  VoidCallback? onDismiss;
}
