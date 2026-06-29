import 'package:flutter/material.dart';

class ScaleAnimation extends StatefulWidget {
  const ScaleAnimation({
    super.key,
    required this.controller,
    required this.child,
    this.alignment,
  });

  final AnimationController controller;
  final Widget child;
  final Alignment? alignment;

  @override
  State<ScaleAnimation> createState() => _ScaleAnimationState();
}

class _ScaleAnimationState extends State<ScaleAnimation> {
  late final CurvedAnimation _curvedAnimation;

  @override
  void initState() {
    super.initState();
    _curvedAnimation = CurvedAnimation(
      parent: widget.controller,
      curve: Curves.linear,
    );
  }

  @override
  void dispose() {
    _curvedAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      alignment: widget.alignment ?? Alignment.center,
      scale: _curvedAnimation,
      child: widget.child,
    );
  }
}
