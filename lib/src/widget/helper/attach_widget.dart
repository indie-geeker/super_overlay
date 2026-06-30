import 'package:flutter/material.dart';

class AttachPositionDelegate extends SingleChildLayoutDelegate {
  AttachPositionDelegate({required this.targetRect, required this.alignment});

  final Rect targetRect;
  final Alignment alignment;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var dx = targetRect.left + (targetRect.width - childSize.width) / 2;
    var dy = targetRect.bottom;

    if (alignment == Alignment.topLeft ||
        alignment == Alignment.topCenter ||
        alignment == Alignment.topRight) {
      dy = targetRect.top - childSize.height;
    } else if (alignment == Alignment.centerLeft ||
        alignment == Alignment.center ||
        alignment == Alignment.centerRight) {
      dy = targetRect.top + (targetRect.height - childSize.height) / 2;
    }

    if (alignment == Alignment.centerLeft) {
      dx = targetRect.left - childSize.width;
    } else if (alignment == Alignment.centerRight) {
      dx = targetRect.right;
    } else if (alignment == Alignment.topLeft ||
        alignment == Alignment.bottomLeft) {
      dx = targetRect.left;
    } else if (alignment == Alignment.topRight ||
        alignment == Alignment.bottomRight) {
      dx = targetRect.right - childSize.width;
    }

    final maxDx = (size.width - childSize.width).clamp(0.0, size.width);
    final maxDy = (size.height - childSize.height).clamp(0.0, size.height);
    return Offset(dx.clamp(0.0, maxDx), dy.clamp(0.0, maxDy));
  }

  @override
  bool shouldRelayout(covariant AttachPositionDelegate oldDelegate) {
    return targetRect != oldDelegate.targetRect ||
        alignment != oldDelegate.alignment;
  }
}
