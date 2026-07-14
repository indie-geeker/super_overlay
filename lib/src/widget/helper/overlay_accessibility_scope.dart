import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/show_param.dart';
import '../../helper/overlay_manager.dart';

class OverlayFocusLifecycle {
  VoidCallback? _restoreFocusBeforeHide;
  VoidCallback? _requestFocusAfterShow;

  void bind({
    required VoidCallback restoreFocusBeforeHide,
    required VoidCallback requestFocusAfterShow,
  }) {
    _restoreFocusBeforeHide = restoreFocusBeforeHide;
    _requestFocusAfterShow = requestFocusAfterShow;
  }

  void unbind(VoidCallback restoreFocusBeforeHide) {
    if (identical(_restoreFocusBeforeHide, restoreFocusBeforeHide)) {
      _restoreFocusBeforeHide = null;
      _requestFocusAfterShow = null;
    }
  }

  void restoreFocusBeforeHide() {
    _restoreFocusBeforeHide?.call();
  }

  void requestFocusAfterShow() {
    _requestFocusAfterShow?.call();
  }
}

class OverlayAccessibilityScope extends StatefulWidget {
  const OverlayAccessibilityScope({
    super.key,
    required this.mode,
    required this.requestFocus,
    required this.semanticsLabel,
    required this.handlesEscape,
    required this.focusRestoreTarget,
    required this.focusLifecycle,
    required this.child,
  });

  final OverlayAccessibilityMode mode;
  final bool requestFocus;
  final String? semanticsLabel;
  final bool handlesEscape;
  final WeakReference<FocusNode>? focusRestoreTarget;
  final OverlayFocusLifecycle focusLifecycle;
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
  int _focusRequestToken = 0;
  late final VoidCallback _restoreFocusCallback = _restoreFocusBeforeHide;

  FocusNode get _activeFocusNode =>
      widget.mode == OverlayAccessibilityMode.modal
          ? _modalFocusScopeNode
          : _nonModalFocusNode;

  FocusNode _focusNodeFor(OverlayAccessibilityMode mode) =>
      mode == OverlayAccessibilityMode.modal
          ? _modalFocusScopeNode
          : _nonModalFocusNode;

  @override
  void initState() {
    super.initState();
    _modalFocusScopeNode.addListener(_handleFocusChange);
    _nonModalFocusNode.addListener(_handleFocusChange);
    _bindFocusLifecycle();
    _scheduleFocusRequest();
  }

  @override
  void didUpdateWidget(covariant OverlayAccessibilityScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.focusLifecycle, widget.focusLifecycle)) {
      oldWidget.focusLifecycle.unbind(_restoreFocusCallback);
      _bindFocusLifecycle();
    }
    final modeChanged = oldWidget.mode != widget.mode;
    if (modeChanged && widget.mode != OverlayAccessibilityMode.modal) {
      _nonModalFocusNode.debugLabel = 'SuperOverlay ${widget.mode.name} focus';
    }

    if (oldWidget.requestFocus && !widget.requestFocus) {
      _cancelPendingFocusRequest();
      _restorePreviousFocus(
        focusNode: _focusNodeFor(oldWidget.mode),
        requireOverlayFocus: true,
      );
      _hadFocus = false;
      return;
    }

    if (widget.requestFocus && (modeChanged || !oldWidget.requestFocus)) {
      _scheduleFocusRequest();
    } else if (modeChanged) {
      _cancelPendingFocusRequest();
    }
  }

  void _bindFocusLifecycle() {
    widget.focusLifecycle.bind(
      restoreFocusBeforeHide: _restoreFocusCallback,
      requestFocusAfterShow: _scheduleFocusRequest,
    );
  }

  void _restoreFocusBeforeHide() {
    _cancelPendingFocusRequest();
    _restorePreviousFocus(
      focusNode: _activeFocusNode,
      requireOverlayFocus: true,
    );
    _hadFocus = false;
  }

  void _scheduleFocusRequest() {
    if (!widget.requestFocus) {
      return;
    }
    final token = ++_focusRequestToken;
    final focusNode = _activeFocusNode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          token != _focusRequestToken ||
          !widget.requestFocus ||
          !identical(focusNode, _activeFocusNode)) {
        return;
      }
      if (focusNode.canRequestFocus) {
        focusNode.requestFocus();
      }
    });
  }

  void _cancelPendingFocusRequest() {
    _focusRequestToken++;
  }

  void _handleFocusChange() {
    _hadFocus =
        _hadFocus ||
        _modalFocusScopeNode.hasFocus ||
        _nonModalFocusNode.hasFocus;
  }

  void _restorePreviousFocus({
    FocusNode? focusNode,
    bool requireOverlayFocus = false,
  }) {
    final overlayFocus = focusNode ?? _activeFocusNode;
    if (!_hadFocus ||
        (requireOverlayFocus && !overlayFocus.hasFocus) ||
        (!requireOverlayFocus &&
            widget.mode != OverlayAccessibilityMode.modal &&
            !overlayFocus.hasFocus)) {
      return;
    }
    final previousFocus = widget.focusRestoreTarget?.target;
    if (previousFocus == null) {
      overlayFocus.unfocus();
      return;
    }
    try {
      if (previousFocus.canRequestFocus) {
        previousFocus.requestFocus();
      } else {
        overlayFocus.unfocus();
      }
    } catch (_) {
      // The previous owner may have disposed its focus node while the overlay
      // was visible. In that case Flutter's focus manager chooses a fallback.
      overlayFocus.unfocus();
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
    _cancelPendingFocusRequest();
    widget.focusLifecycle.unbind(_restoreFocusCallback);
    _modalFocusScopeNode.removeListener(_handleFocusChange);
    _nonModalFocusNode.removeListener(_handleFocusChange);
    _modalFocusScopeNode.dispose();
    _nonModalFocusNode.dispose();
    super.dispose();
  }
}
