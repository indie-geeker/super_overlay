import 'package:flutter/widgets.dart';

class KeyboardAwarePositionDelegate extends SingleChildLayoutDelegate {
  const KeyboardAwarePositionDelegate({
    required this.alignment,
    required this.keyboardInset,
  });

  final Alignment alignment;
  final double keyboardInset;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(
      Size(
        constraints.maxWidth,
        (constraints.maxHeight - keyboardInset).clamp(
          0.0,
          constraints.maxHeight,
        ),
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final desired = alignment.alongOffset(
      Offset(size.width - childSize.width, size.height - childSize.height),
    );
    final bottom = (size.height - keyboardInset - childSize.height).clamp(
      0.0,
      size.height,
    );
    return Offset(desired.dx, desired.dy.clamp(0.0, bottom));
  }

  @override
  bool shouldRelayout(KeyboardAwarePositionDelegate oldDelegate) =>
      alignment != oldDelegate.alignment ||
      keyboardInset != oldDelegate.keyboardInset;
}
