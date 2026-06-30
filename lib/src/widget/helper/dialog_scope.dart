import 'package:flutter/material.dart';

import '../../kit/overlay_controller.dart';
import '../../kit/view_utils.dart';

class DialogScope extends StatefulWidget {
  const DialogScope({
    super.key,
    required this.controller,
    required this.builder,
  });

  final SuperOverlayController? controller;
  final WidgetBuilder builder;

  @override
  State<DialogScope> createState() => _DialogScopeState();
}

class _DialogScopeState extends State<DialogScope> {
  VoidCallback? _callback;

  @override
  void initState() {
    _setController(widget.controller);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context);
  }

  void _setController(SuperOverlayController? controller) {
    controller?.setListener(
      _callback = () {
        ViewUtils.addSafeUse(() {
          if (mounted) {
            setState(() {});
          }
        });
      },
    );
  }

  @override
  void dispose() {
    if (_callback != null) {
      widget.controller?.dismiss();
    }
    super.dispose();
  }
}
