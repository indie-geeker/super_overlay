import 'package:flutter/widgets.dart';

/// Retains a presented subtree while its route is inactive, without building
/// content that has never been presented.
class OverlayPresentation extends StatefulWidget {
  const OverlayPresentation({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  State<OverlayPresentation> createState() => _OverlayPresentationState();
}

class _OverlayPresentationState extends State<OverlayPresentation> {
  bool _hasPresented = false;

  @override
  Widget build(BuildContext context) {
    _hasPresented = _hasPresented || widget.visible;
    if (!_hasPresented) {
      return const SizedBox.shrink();
    }
    return Offstage(
      offstage: !widget.visible,
      child: TickerMode(
        enabled: widget.visible,
        child: ExcludeFocus(excluding: !widget.visible, child: widget.child),
      ),
    );
  }
}
