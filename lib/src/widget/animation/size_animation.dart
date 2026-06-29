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
    return SizeTransition(axis: _axis, sizeFactor: controller, child: child);
  }

  Axis get _axis {
    if (alignment == Alignment.centerLeft ||
        alignment == Alignment.centerRight) {
      return Axis.horizontal;
    }
    return Axis.vertical;
  }
}
