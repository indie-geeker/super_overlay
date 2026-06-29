import 'package:flutter/material.dart';

class OverlayDialogWidget extends StatelessWidget {
  const OverlayDialogWidget({
    super.key,
    required this.child,
    required this.alignment,
    required this.usePenetrate,
    required this.maskColor,
    required this.maskWidget,
    required this.onMask,
  });

  final Widget child;
  final Alignment alignment;
  final bool usePenetrate;
  final Color maskColor;
  final Widget? maskWidget;
  final VoidCallback onMask;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildMask(),
        SafeArea(
          child: Align(
            alignment: alignment,
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ],
    );
  }

  Widget _buildMask() {
    final mask =
        maskWidget ??
        ColoredBox(color: usePenetrate ? Colors.transparent : maskColor);
    if (usePenetrate) {
      return IgnorePointer(child: mask);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onMask,
      child: mask,
    );
  }
}
