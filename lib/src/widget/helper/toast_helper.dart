import 'package:flutter/widgets.dart';

class ToastHelper extends StatelessWidget {
  const ToastHelper({
    super.key,
    required this.consumeEvent,
    required this.child,
  });

  final bool consumeEvent;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      consumeEvent ? child : IgnorePointer(child: child);
}
