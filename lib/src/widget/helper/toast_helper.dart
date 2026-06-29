import 'package:flutter/material.dart';

import '../../kit/view_utils.dart';

class ToastHelper extends StatefulWidget {
  const ToastHelper({
    super.key,
    required this.consumeEvent,
    required this.child,
  });

  final bool consumeEvent;
  final Widget child;

  @override
  State<ToastHelper> createState() => _ToastHelperState();
}

class _ToastHelperState extends State<ToastHelper> with WidgetsBindingObserver {
  double _keyboardHeight = 0;
  BuildContext? _childContext;
  Offset? _selfOffset;
  Size? _selfSize;

  @override
  void initState() {
    super.initState();
    widgetsBinding.addObserver(this);
    ViewUtils.addSafeUse(_handleKeyboard);
  }

  @override
  Widget build(BuildContext context) {
    final child = Builder(
      builder: (context) {
        _childContext = context;
        return widget.child;
      },
    );

    return Container(
      margin: EdgeInsets.only(bottom: _keyboardHeight),
      child: widget.consumeEvent ? child : IgnorePointer(child: child),
    );
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _handleKeyboard();
  }

  @override
  void dispose() {
    widgetsBinding.removeObserver(this);
    super.dispose();
  }

  void _handleKeyboard() {
    ViewUtils.addSafeUse(() {
      if (!mounted || !_updateSelfInfo()) {
        return;
      }

      final screen = MediaQuery.of(context).size;
      final childToBottom =
          screen.height - (_selfOffset!.dy + _selfSize!.height);
      final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
      if (childToBottom < 0) {
        _setKeyboardHeight(keyboardHeight);
        return;
      }
      if (childToBottom - keyboardHeight > -30) {
        return;
      }
      _setKeyboardHeight(keyboardHeight - childToBottom);
    });
  }

  bool _updateSelfInfo() {
    final childContext = _childContext;
    if (!(childContext?.mounted ?? false)) {
      _selfOffset = null;
      _selfSize = null;
      return false;
    }

    final renderObject = childContext!.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      _selfOffset = null;
      _selfSize = null;
      return false;
    }

    _selfOffset = renderObject.localToGlobal(Offset.zero);
    _selfSize = renderObject.size;
    return true;
  }

  void _setKeyboardHeight(double value) {
    if (_keyboardHeight == value) {
      return;
    }
    setState(() => _keyboardHeight = value);
  }
}
