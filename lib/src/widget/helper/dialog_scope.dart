import 'package:flutter/material.dart';

import '../../kit/overlay_controller.dart';
import '../../kit/view_utils.dart';

abstract class DialogScopeAction {
  void setController(SuperOverlayController? controller);

  void replaceBuilder(Widget? child);
}

class DialogScopeInfo {
  DialogScopeAction? action;
}

class DialogScope extends StatefulWidget {
  DialogScope({super.key, required this.controller, required this.builder});

  final SuperOverlayController? controller;
  final WidgetBuilder builder;
  final DialogScopeInfo info = DialogScopeInfo();

  @override
  State<DialogScope> createState() => _DialogScopeState();
}

class _DialogScopeState extends State<DialogScope>
    implements DialogScopeAction {
  VoidCallback? _callback;
  Widget? _child;

  @override
  void initState() {
    widget.info.action = this;
    setController(widget.controller);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return _child ?? widget.builder(context);
  }

  @override
  void setController(SuperOverlayController? controller) {
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
  void replaceBuilder(Widget? child) {
    _child = child;
  }

  @override
  void dispose() {
    if (_callback != null) {
      widget.controller?.dismiss();
    }
    super.dispose();
  }
}
