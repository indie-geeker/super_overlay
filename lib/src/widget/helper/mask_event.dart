import 'package:flutter/material.dart';

import '../../config/enum_config.dart';

class MaskEvent extends StatefulWidget {
  const MaskEvent({
    super.key,
    required this.maskTriggerType,
    required this.onMask,
    this.dismissible = false,
    this.semanticsLabel,
    required this.child,
  });

  final MaskTriggerType maskTriggerType;
  final VoidCallback onMask;
  final bool dismissible;
  final String? semanticsLabel;
  final Widget child;

  @override
  State<MaskEvent> createState() => _MaskEventState();
}

class _MaskEventState extends State<MaskEvent> {
  bool _maskTriggered = false;

  @override
  Widget build(BuildContext context) {
    VoidCallback? onPointerDown;
    VoidCallback? onPointerMove;
    VoidCallback? onPointerUp;

    switch (widget.maskTriggerType) {
      case MaskTriggerType.down:
        onPointerDown = widget.onMask;
        break;
      case MaskTriggerType.move:
        onPointerMove = widget.onMask;
        break;
      case MaskTriggerType.up:
        onPointerUp = widget.onMask;
        break;
    }

    final label =
        widget.semanticsLabel ??
        (widget.dismissible
            ? MaterialLocalizations.of(context).modalBarrierDismissLabel
            : null);
    return Semantics(
      container: true,
      label: label,
      onDismiss: widget.dismissible ? widget.onMask : null,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          onPointerDown?.call();
          if (onPointerDown != null) {
            _maskTriggered = true;
          }
        },
        onPointerMove: (_) {
          if (!_maskTriggered) {
            onPointerMove?.call();
          }
          if (onPointerMove != null) {
            _maskTriggered = true;
          }
        },
        onPointerUp: (_) {
          onPointerUp?.call();
          if (onPointerUp == null && !_maskTriggered) {
            widget.onMask.call();
          }
          _maskTriggered = false;
        },
        child: widget.child,
      ),
    );
  }
}
