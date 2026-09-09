import 'package:flutter/widgets.dart';

/// Reveals a popup without changing its layout size. Placement therefore uses
/// the complete content bounds throughout opening and closing.
class PopupRevealAnimation extends StatelessWidget {
  const PopupRevealAnimation({
    super.key,
    required this.controller,
    required this.alignment,
    required this.child,
  });

  final Animation<double> controller;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    clipper: _PopupRevealClipper(controller, alignment),
    child: child,
  );
}

class _PopupRevealClipper extends CustomClipper<Rect> {
  _PopupRevealClipper(this.animation, this.alignment)
    : super(reclip: animation);

  final Animation<double> animation;
  final Alignment alignment;

  @override
  Rect getClip(Size size) {
    final progress = animation.value.clamp(0.0, 1.0);
    if (alignment == Alignment.centerLeft ||
        alignment == Alignment.centerRight) {
      final width = size.width * progress;
      return Rect.fromLTWH(
        alignment.x < 0 ? size.width - width : 0,
        0,
        width,
        size.height,
      );
    }
    final height = size.height * progress;
    final top =
        alignment.y < 0
            ? size.height - height
            : alignment.y > 0
            ? 0.0
            : (size.height - height) / 2;
    return Rect.fromLTWH(0, top, size.width, height);
  }

  @override
  Rect getApproximateClipRect(Size size) => getClip(size);

  @override
  bool shouldReclip(_PopupRevealClipper oldClipper) =>
      animation != oldClipper.animation || alignment != oldClipper.alignment;
}
