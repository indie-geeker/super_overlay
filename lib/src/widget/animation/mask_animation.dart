import 'package:flutter/material.dart';

class MaskAnimation extends StatefulWidget {
  const MaskAnimation({
    super.key,
    required this.controller,
    required this.maskWidget,
    required this.maskColor,
    required this.usePenetrate,
  });

  final AnimationController controller;
  final Widget? maskWidget;
  final Color maskColor;
  final bool usePenetrate;

  @override
  State<MaskAnimation> createState() => _MaskAnimationState();
}

class _MaskAnimationState extends State<MaskAnimation> {
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
    final child =
        widget.maskWidget != null && !widget.usePenetrate
            ? widget.maskWidget!
            : ColoredBox(
              color:
                  widget.usePenetrate ? Colors.transparent : widget.maskColor,
            );

    return FadeTransition(opacity: _curvedAnimation, child: child);
  }
}
