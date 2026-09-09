import 'package:flutter/material.dart';

class SizeAnimation extends StatelessWidget {
  const SizeAnimation({
    super.key,
    required this.controller,
    required this.alignment,
    required this.child,
  });

  final AnimationController controller;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      axis: _axis,
      // Flutter 3.29 has no alignment parameter. Keep the compatibility API
      // until the minimum SDK can use its replacement.
      // ignore: deprecated_member_use
      axisAlignment: _axisAlignment,
      fixedCrossAxisSizeFactor: 1,
      sizeFactor: controller,
      child: child,
    );
  }

  Axis get _axis {
    if (alignment == Alignment.centerLeft ||
        alignment == Alignment.centerRight) {
      return Axis.horizontal;
    }
    return Axis.vertical;
  }

  double get _axisAlignment {
    if (alignment == Alignment.bottomLeft ||
        alignment == Alignment.bottomCenter ||
        alignment == Alignment.bottomRight ||
        alignment == Alignment.centerRight) {
      return -1;
    }
    if (alignment == Alignment.topLeft ||
        alignment == Alignment.topCenter ||
        alignment == Alignment.topRight ||
        alignment == Alignment.centerLeft) {
      return 1;
    }
    return 0;
  }
}
