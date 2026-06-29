import 'package:flutter/material.dart';

class SlideAnimation extends StatefulWidget {
  const SlideAnimation({
    super.key,
    required this.alignment,
    required this.controller,
    required this.child,
  });

  final Alignment alignment;
  final AnimationController controller;
  final Widget child;

  @override
  State<SlideAnimation> createState() => _SlideAnimationState();
}

class _SlideAnimationState extends State<SlideAnimation> {
  late Tween<Offset> _tween;

  @override
  void initState() {
    _updateTween();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant SlideAnimation oldWidget) {
    if (oldWidget.alignment != widget.alignment ||
        oldWidget.child != widget.child) {
      _updateTween();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _tween.animate(widget.controller),
      child: widget.child,
    );
  }

  void _updateTween() {
    var offset = Offset.zero;
    final alignment = widget.alignment;

    if (alignment == Alignment.bottomCenter ||
        alignment == Alignment.bottomLeft ||
        alignment == Alignment.bottomRight) {
      offset = const Offset(0, 1);
    } else if (alignment == Alignment.topCenter ||
        alignment == Alignment.topLeft ||
        alignment == Alignment.topRight) {
      offset = const Offset(0, -1);
    } else if (alignment == Alignment.centerLeft) {
      offset = const Offset(-1, 0);
    } else if (alignment == Alignment.centerRight) {
      offset = const Offset(1, 0);
    }

    _tween = Tween<Offset>(begin: offset, end: Offset.zero);
  }
}
