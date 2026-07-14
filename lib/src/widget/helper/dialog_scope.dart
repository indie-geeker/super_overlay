import 'package:flutter/material.dart';

import '../../kit/overlay_controller.dart';
import '../../kit/view_utils.dart';

class DialogScope extends StatefulWidget {
  const DialogScope({
    super.key,
    required this.controller,
    required this.builder,
    this.liveRegion = false,
  });

  final SuperOverlayController? controller;
  final WidgetBuilder builder;
  final bool liveRegion;

  @override
  State<DialogScope> createState() => _DialogScopeState();
}

class _DialogScopeState extends State<DialogScope> {
  VoidCallback? _callback;
  SuperOverlayController? _boundController;
  bool _visibilityScheduled = false;

  @override
  void initState() {
    super.initState();
    _bindController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant DialogScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _unbindController(oldWidget.controller);
      _bindController(widget.controller);
      _visibilityScheduled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visibilityScheduled) {
      _visibilityScheduled = true;
      final scheduledController = widget.controller;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_boundController, scheduledController)) {
          scheduledController?.markVisible();
        }
      });
    }
    final child = widget.builder(context);
    if (!widget.liveRegion) {
      return child;
    }
    return Semantics(liveRegion: true, child: child);
  }

  void _bindController(SuperOverlayController? controller) {
    if (controller == null) {
      return;
    }
    final callback =
        _callback ??= () {
          ViewUtils.addSafeUse(() {
            if (mounted) {
              setState(() {});
            }
          });
        };
    controller.setListener(callback);
    _boundController = controller;
  }

  void _unbindController(SuperOverlayController? controller) {
    final callback = _callback;
    if (callback == null || controller == null) {
      return;
    }
    controller.removeListener(callback);
    if (identical(_boundController, controller)) {
      _boundController = null;
    }
  }

  @override
  void dispose() {
    _unbindController(_boundController);
    super.dispose();
  }
}
