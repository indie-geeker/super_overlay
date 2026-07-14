import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/show_param.dart';
import '../../helper/overlay_manager.dart';

class OverlayAccessibilityScope extends StatefulWidget {
  const OverlayAccessibilityScope({
    super.key,
    required this.mode,
    required this.requestFocus,
    required this.semanticsLabel,
    required this.handlesEscape,
    required this.focusRestoreTarget,
    required this.child,
  });

  final OverlayAccessibilityMode mode;
  final bool requestFocus;
  final String? semanticsLabel;
  final bool handlesEscape;
  final WeakReference<FocusNode>? focusRestoreTarget;
  final Widget child;

  @override
  State<OverlayAccessibilityScope> createState() =>
      _OverlayAccessibilityScopeState();
}

class _OverlayAccessibilityScopeState extends State<OverlayAccessibilityScope> {
  late final FocusScopeNode _modalFocusScopeNode = FocusScopeNode(
    debugLabel: 'SuperOverlay modal focus scope',
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  late final FocusNode _nonModalFocusNode = FocusNode(
    debugLabel: 'SuperOverlay ${widget.mode.name} focus',
  );
  bool _hadFocus = false;

  FocusNode get _activeFocusNode =>
      widget.mode == OverlayAccessibilityMode.modal
          ? _modalFocusScopeNode
          : _nonModalFocusNode;

  @override
  void initState() {
    super.initState();
    _modalFocusScopeNode.addListener(_handleFocusChange);
    _nonModalFocusNode.addListener(_handleFocusChange);
    _scheduleFocusRequest();
  }

  @override
  void didUpdateWidget(covariant OverlayAccessibilityScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    final modeChanged = oldWidget.mode != widget.mode;
    if (modeChanged && widget.mode != OverlayAccessibilityMode.modal) {
      _nonModalFocusNode.debugLabel = 'SuperOverlay ${widget.mode.name} focus';
    }
    if (widget.requestFocus && (modeChanged || !oldWidget.requestFocus)) {
      _scheduleFocusRequest();
    }
  }

  void _scheduleFocusRequest() {
    if (!widget.requestFocus) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _activeFocusNode.canRequestFocus) {
        _activeFocusNode.requestFocus();
      }
    });
  }

  void _handleFocusChange() {
    _hadFocus =
        _hadFocus ||
        _modalFocusScopeNode.hasFocus ||
        _nonModalFocusNode.hasFocus;
  }

  void _restorePreviousFocus() {
    if (!_hadFocus ||
        (widget.mode != OverlayAccessibilityMode.modal &&
            !_activeFocusNode.hasFocus)) {
      return;
    }
    final previousFocus = widget.focusRestoreTarget?.target;
    if (previousFocus == null) {
      return;
    }
    try {
      if (previousFocus.canRequestFocus) {
        previousFocus.requestFocus();
      }
    } catch (_) {
      // The previous owner may have disposed its focus node while the overlay
      // was visible. In that case Flutter's focus manager chooses a fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget result =
        widget.mode == OverlayAccessibilityMode.modal
            ? FocusScope(node: _modalFocusScopeNode, child: widget.child)
            : Semantics(
              explicitChildNodes: true,
              child: Focus(
                focusNode: _nonModalFocusNode,
                includeSemantics: false,
                skipTraversal: true,
                child: widget.child,
              ),
            );

    if (widget.handlesEscape) {
      result = CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape):
              () => unawaited(OverlayManager.instance.handleBackEvent()),
        },
        child: result,
      );
    }

    return switch (widget.mode) {
      OverlayAccessibilityMode.modal => BlockSemantics(
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          scopesRoute: true,
          label: widget.semanticsLabel,
          child: result,
        ),
      ),
      OverlayAccessibilityMode.popup => Semantics(
        container: true,
        label: widget.semanticsLabel,
        child: result,
      ),
      OverlayAccessibilityMode.liveRegion => result,
    };
  }

  @override
  void dispose() {
    _restorePreviousFocus();
    _modalFocusScopeNode.removeListener(_handleFocusChange);
    _nonModalFocusNode.removeListener(_handleFocusChange);
    _modalFocusScopeNode.dispose();
    _nonModalFocusNode.dispose();
    super.dispose();
  }
}
