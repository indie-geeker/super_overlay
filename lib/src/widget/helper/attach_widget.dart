import 'package:flutter/material.dart';

import '../../config/enum_config.dart';
import '../../kit/typedef.dart';

class AttachPositionDelegate extends SingleChildLayoutDelegate {
  AttachPositionDelegate({
    required this.targetRect,
    required this.alignment,
    required this.alignmentMode,
    required this.onLayout,
  });

  final Rect targetRect;
  final Alignment alignment;
  final PopupAlignmentMode alignmentMode;
  final ValueChanged<PopupLayoutInfo>? onLayout;

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
      dx = _horizontalEdgeOffset(
        edge: targetRect.left,
        childWidth: childSize.width,
        isLeftEdge: true,
      );
    } else if (alignment == Alignment.topRight ||
        alignment == Alignment.bottomRight) {
      dx = _horizontalEdgeOffset(
        edge: targetRect.right,
        childWidth: childSize.width,
        isLeftEdge: false,
      );
    }

    final maxDx = (size.width - childSize.width).clamp(0.0, size.width);
    final maxDy = (size.height - childSize.height).clamp(0.0, size.height);
    final offset = Offset(dx.clamp(0.0, maxDx), dy.clamp(0.0, maxDy));
    onLayout?.call(
      PopupLayoutInfo(
        targetOffset: targetRect.topLeft,
        targetSize: targetRect.size,
        popupOffset: offset,
        popupSize: childSize,
      ),
    );
    return offset;
  }

  double _horizontalEdgeOffset({
    required double edge,
    required double childWidth,
    required bool isLeftEdge,
  }) {
    return switch (alignmentMode) {
      PopupAlignmentMode.inside => isLeftEdge ? edge : edge - childWidth,
      PopupAlignmentMode.center => edge - childWidth / 2,
      PopupAlignmentMode.outside => isLeftEdge ? edge - childWidth : edge,
    };
  }

  @override
  bool shouldRelayout(covariant AttachPositionDelegate oldDelegate) {
    return targetRect != oldDelegate.targetRect ||
        alignment != oldDelegate.alignment ||
        alignmentMode != oldDelegate.alignmentMode;
  }
}
