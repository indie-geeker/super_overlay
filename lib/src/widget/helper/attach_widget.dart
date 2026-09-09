import 'package:flutter/material.dart';

import '../../config/enum_config.dart';
import '../../kit/typedef.dart';

class AttachPositionDelegate extends SingleChildLayoutDelegate {
  AttachPositionDelegate({
    required this.targetRect,
    required this.alignment,
    required this.alignmentMode,
    required this.onLayout,
    this.viewInsets = EdgeInsets.zero,
    this.allowFlip = true,
  });

  final Rect targetRect;
  final Alignment alignment;
  final PopupAlignmentMode alignmentMode;
  final ValueChanged<PopupLayoutInfo>? onLayout;
  final EdgeInsets viewInsets;
  final bool allowFlip;

  Rect _availableRect(Size size) {
    final left = viewInsets.left.clamp(0.0, size.width);
    final top = viewInsets.top.clamp(0.0, size.height);
    return Rect.fromLTRB(
      left,
      top,
      (size.width - viewInsets.right).clamp(left, size.width),
      (size.height - viewInsets.bottom).clamp(top, size.height),
    );
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(_availableRect(constraints.biggest).size);
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

    final available = _availableRect(size);
    if (allowFlip) {
      if (alignment.y == 1 &&
          dy + childSize.height > available.bottom &&
          targetRect.top - childSize.height >= available.top) {
        dy = targetRect.top - childSize.height;
      } else if (alignment.y == -1 &&
          dy < available.top &&
          targetRect.bottom + childSize.height <= available.bottom) {
        dy = targetRect.bottom;
      }
      if (alignment == Alignment.centerRight &&
          dx + childSize.width > available.right &&
          targetRect.left - childSize.width >= available.left) {
        dx = targetRect.left - childSize.width;
      } else if (alignment == Alignment.centerLeft &&
          dx < available.left &&
          targetRect.right + childSize.width <= available.right) {
        dx = targetRect.right;
      }
    }
    final maxDx = (available.right - childSize.width).clamp(
      available.left,
      available.right,
    );
    final maxDy = (available.bottom - childSize.height).clamp(
      available.top,
      available.bottom,
    );
    final offset = Offset(
      dx.clamp(available.left, maxDx),
      dy.clamp(available.top, maxDy),
    );
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
        viewInsets != oldDelegate.viewInsets ||
        allowFlip != oldDelegate.allowFlip ||
        alignmentMode != oldDelegate.alignmentMode;
  }
}
