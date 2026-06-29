import 'package:flutter/material.dart';

class HighlightMask extends StatelessWidget {
  final Rect targetRect;
  final Color maskColor;
  final VoidCallback? onDismiss;
  final EdgeInsets padding;
  final BorderRadius borderRadius;

  const HighlightMask({
    super.key,
    required this.targetRect,
    required this.maskColor,
    this.onDismiss,
    this.padding = EdgeInsets.zero,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context) {
    final inflatedRect = padding.inflateRect(targetRect);

    return ClipPath(
      clipper: _HoleClipper(inflatedRect, borderRadius),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: Container(
          color: maskColor,
        ),
      ),
    );
  }
}

class _HoleClipper extends CustomClipper<Path> {
  final Rect holeRect;
  final BorderRadius borderRadius;

  _HoleClipper(this.holeRect, this.borderRadius);

  @override
  Path getClip(Size size) {
    final fullScreenPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final holePath = Path()
      ..addRRect(borderRadius.toRRect(holeRect));

    return Path.combine(PathOperation.difference, fullScreenPath, holePath);
  }

  @override
  bool shouldReclip(covariant _HoleClipper oldClipper) {
    return oldClipper.holeRect != holeRect || oldClipper.borderRadius != borderRadius;
  }
}
