import 'package:flutter/material.dart';

import '../data/show_param.dart';
import 'helper/attach_widget.dart';
import 'helper/dialog_scope.dart';
import 'helper/mask_event.dart';
import 'highlight_mask.dart';

class AttachDialogWidget extends StatelessWidget {
  const AttachDialogWidget({
    super.key,
    required this.param,
    required this.onMask,
  });

  final ShowAttachParam param;
  final VoidCallback onMask;

  @override
  Widget build(BuildContext context) {
    final targetRect = _targetRect();

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildMask(targetRect),
        CustomSingleChildLayout(
          delegate: AttachPositionDelegate(
            targetRect: targetRect,
            alignment: param.alignment,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: DialogScope(
              controller: param.controller,
              builder: param.builder,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMask(Rect targetRect) {
    final highlight = param.highlight;
    final mask = highlight != null
        ? HighlightMask(
            targetRect: targetRect,
            maskColor: param.maskColor,
            padding: highlight.padding,
            borderRadius: highlight.borderRadius,
            onDismiss: onMask,
          )
        : (param.maskWidget ?? ColoredBox(color: param.maskColor));

    if (param.usePenetrate) {
      return IgnorePointer(child: mask);
    }

    return MaskEvent(
      maskTriggerType: param.maskTriggerType,
      onMask: onMask,
      child: mask,
    );
  }

  Rect _targetRect() {
    final targetContext = param.targetContext;
    final renderObject = targetContext?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return Rect.zero;
    }

    final offset = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final targetRect = offset & size;
    return param.targetRectBuilder?.call(targetRect) ?? targetRect;
  }
}
