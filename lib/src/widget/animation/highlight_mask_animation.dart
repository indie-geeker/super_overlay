import 'package:flutter/material.dart';

class HighlightMaskAnimation extends StatelessWidget {
  const HighlightMaskAnimation({
    super.key,
    required this.controller,
    required this.animate,
    required this.child,
  });

  final AnimationController controller;
  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!animate) {
      return child;
    }

    return FadeTransition(opacity: controller, child: child);
  }
}
