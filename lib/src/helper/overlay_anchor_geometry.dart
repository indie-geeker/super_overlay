import 'package:flutter/material.dart';

import '../kit/view_utils.dart';

/// Stateless geometry reads. Ownership, presentation and closing decisions
/// belong to the manager; this helper retains no contexts or routes.
class OverlayAnchorGeometry {
  static RenderBox? renderBox(BuildContext context) {
    try {
      final object = context.findRenderObject();
      if (object is RenderBox && object.attached && object.hasSize) {
        return object;
      }
    } catch (_) {}
    return null;
  }

  static Rect? inOverlay(RenderBox target, BuildContext overlayContext) {
    try {
      final overlay = overlayOf(overlayContext).context.findRenderObject();
      if (overlay is! RenderBox || !overlay.attached || !overlay.hasSize) {
        return null;
      }
      final rect = MatrixUtils.transformRect(
        target.getTransformTo(overlay),
        Offset.zero & target.size,
      );
      final viewport = Offset.zero & overlay.size;
      return isValidRect(rect) && rect.overlaps(viewport) ? rect : null;
    } catch (_) {
      return null;
    }
  }

  static double delta(Rect previous, Rect current) {
    var delta = 0.0;
    for (final value in <double>[
      (previous.left - current.left).abs(),
      (previous.top - current.top).abs(),
      (previous.right - current.right).abs(),
      (previous.bottom - current.bottom).abs(),
    ]) {
      if (value > delta) delta = value;
    }
    return delta;
  }

  static bool isValidRect(Rect rect) =>
      rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite &&
      rect.width > 0 &&
      rect.height > 0;

  static bool hasInvalidGeometry(RenderBox box) {
    try {
      final offset = box.localToGlobal(Offset.zero);
      return box.size.isEmpty ||
          offset.dx < 0 ||
          offset.dy < 0 ||
          !offset.dx.isFinite ||
          !offset.dy.isFinite;
    } catch (_) {
      return true;
    }
  }
}
