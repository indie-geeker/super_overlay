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
  late final FocusScopeNode _focusScopeNode = FocusScopeNode(
    debugLabel: 'SuperOverlay ${widget.mode.name} focus scope',
    traversalEdgeBehavior: _traversalEdgeBehavior,
  );
  bool _hadFocus = false;

  @override
  void initState() {
    super.initState();
    _focusScopeNode.addListener(_handleFocusChange);
    _scheduleFocusRequest();
  }

  @override
  void didUpdateWidget(covariant OverlayAccessibilityScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _focusScopeNode
        ..debugLabel = 'SuperOverlay ${widget.mode.name} focus scope'
        ..traversalEdgeBehavior = _traversalEdgeBehavior;
    }
    if (!oldWidget.requestFocus && widget.requestFocus) {
      _scheduleFocusRequest();
    }
  }

  TraversalEdgeBehavior get _traversalEdgeBehavior =>
      widget.mode == OverlayAccessibilityMode.modal
          ? TraversalEdgeBehavior.closedLoop
          : TraversalEdgeBehavior.parentScope;

  void _scheduleFocusRequest() {
    if (!widget.requestFocus) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusScopeNode.canRequestFocus) {
        _focusScopeNode.requestFocus();
      }
    });
  }

  void _handleFocusChange() {
    _hadFocus = _hadFocus || _focusScopeNode.hasFocus;
  }

  void _restorePreviousFocus() {
    if (!_hadFocus ||
        (widget.mode != OverlayAccessibilityMode.modal &&
            !_focusScopeNode.hasFocus)) {
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
    Widget result = FocusScope(node: _focusScopeNode, child: widget.child);

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
    _focusScopeNode.removeListener(_handleFocusChange);
    _focusScopeNode.dispose();
    super.dispose();
  }
}
