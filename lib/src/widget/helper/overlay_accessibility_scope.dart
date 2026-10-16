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
    required this.focusRestoreTarget,
    required this.focusLifecycle,
    required this.child,
  });

  final OverlayAccessibilityMode mode;
  final bool requestFocus;
  final String? semanticsLabel;
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
  late final _OverlayDismissAction _dismissAction;
  late final _OverlayShortcutManager _shortcutManager;
  late final OnKeyEventCallback _observeKeyEvent = _beginKeyEvent;

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
    _dismissAction = _OverlayDismissAction(context);
    _shortcutManager = _OverlayShortcutManager(_dismissAction);
    FocusManager.instance.addEarlyKeyEventHandler(_observeKeyEvent);
    _modalFocusScopeNode.addListener(_handleFocusChange);
    _nonModalFocusNode.addListener(_handleFocusChange);
    _bindFocusLifecycle();
    _scheduleFocusRequest();
  }

  KeyEventResult _beginKeyEvent(KeyEvent event) {
    // Native child Shortcuts run before our ShortcutManager. Observe their
    // event boundary without dispatching an action or consuming any key. Focus
    // can change in another early handler, and early callbacks for a whole
    // native event batch run before its focus handlers. Do not filter here.
    _dismissAction.beginKeyEvent();
    return KeyEventResult.ignored;
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
    final result =
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

    Widget content = Actions(
      actions: <Type, Action<Intent>>{DismissIntent: _dismissAction},
      child: result,
    );
    if (widget.mode != OverlayAccessibilityMode.liveRegion) {
      content = Shortcuts.manager(manager: _shortcutManager, child: content);
    }
    return switch (widget.mode) {
      OverlayAccessibilityMode.modal => BlockSemantics(
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          scopesRoute: true,
          namesRoute: widget.semanticsLabel?.trim().isNotEmpty ?? false,
          label: widget.semanticsLabel,
          child: content,
        ),
      ),
      OverlayAccessibilityMode.popup => Semantics(
        container: true,
        label: widget.semanticsLabel,
        child: content,
      ),
      OverlayAccessibilityMode.liveRegion => content,
    };
  }

  @override
  void dispose() {
    _cancelPendingFocusRequest();
    FocusManager.instance.removeEarlyKeyEventHandler(_observeKeyEvent);
    _dismissAction.endKeyEvent();
    _shortcutManager.dispose();
    widget.focusLifecycle.unbind(_restoreFocusCallback);
    _modalFocusScopeNode.removeListener(_handleFocusChange);
    _nonModalFocusNode.removeListener(_handleFocusChange);
    _modalFocusScopeNode.dispose();
    _nonModalFocusNode.dispose();
    super.dispose();
  }
}

/// Gives content the first dismissal attempt, then handles unclaimed Escape.
class _OverlayShortcutManager extends ShortcutManager {
  _OverlayShortcutManager(this.fallback)
    : super(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        },
      );

  final _OverlayDismissAction fallback;

  @override
  KeyEventResult handleKeypress(BuildContext context, KeyEvent event) =>
      fallback.withKeyDispatch(() => _handleKeypress(context, event));

  KeyEventResult _handleKeypress(BuildContext context, KeyEvent event) {
    final previousInvocations = fallback.invocations;
    final focusedContext = primaryFocus?.context;
    final directlyUsesBridge =
        focusedContext != null &&
        identical(
          Actions.maybeFind<DismissIntent>(
            focusedContext,
            intent: const DismissIntent(),
          ),
          fallback,
        );
    final result = super.handleKeypress(context, event);
    if (result != KeyEventResult.ignored ||
        directlyUsesBridge ||
        fallback.invocations != previousInvocations ||
        fallback.keyWasConverted ||
        !const SingleActivator(
          LogicalKeyboardKey.escape,
        ).accepts(event, HardwareKeyboard.instance)) {
      return result;
    }
    // A disabled content action (for example a closed Flutter 3.29 MenuAnchor)
    // stops Actions lookup. Only an unclaimed key should use the overlay/app
    // fallback; handled and skipRemainingHandlers results retain their meaning.
    const intent = DismissIntent();
    final target = primaryFocus?.context ?? context;
    final (enabled, value) = Actions.of(
      target,
    ).invokeActionIfEnabled(fallback, intent, target);
    return enabled
        ? fallback.toKeyEventResult(intent, value)
        : KeyEventResult.ignored;
  }
}

class _DismissKeyInvocation {
  Action<DismissIntent>? application;
  bool enabled = false;

  KeyEventResult keyResult(DismissIntent intent, Object? value) {
    return enabled
        ? application!.toKeyEventResult(intent, value)
        : KeyEventResult.ignored;
  }
}

class _DismissKeyDispatch {
  _DismissKeyDispatch({required this.application});

  final Action<DismissIntent>? application;
  bool consumedBack = false;
  bool converted = false;
  _DismissKeyInvocation? invocation;

  _DismissKeyInvocation? claim() {
    if (invocation != null) return null;
    return invocation = _DismissKeyInvocation();
  }
}

/// Supplies EditableText's parent dismissal action outside ModalRoute, without
/// swallowing raw Escape shortcuts when the application has no intent handler.
class _OverlayDismissAction extends ContextAction<DismissIntent> {
  _OverlayDismissAction(this.parentContext);

  final BuildContext parentContext;
  int invocations = 0;
  final List<_DismissKeyDispatch> _keyDispatches = [];
  final Expando<bool> _backResults = Expando<bool>();
  Object? _keyEventToken;
  _DismissKeyDispatch? _nativeDispatch;

  bool get keyWasConverted => _keyDispatches.last.converted;

  _DismissKeyDispatch _newDispatch() => _DismissKeyDispatch(
    application: _applicationAction(const DismissIntent()),
  );

  void beginKeyEvent() {
    endKeyEvent();
    final token = Object();
    _keyEventToken = token;
    // Handled keys do not reach FocusManager's late handlers. Always clear the
    // observation, including when a dispatcher throws or never invokes us.
    scheduleMicrotask(() {
      if (identical(_keyEventToken, token)) endKeyEvent();
    });
  }

  void endKeyEvent() {
    _keyEventToken = null;
    _nativeDispatch = null;
  }

  _DismissKeyDispatch? get _nativeKeyDispatch {
    if (_keyEventToken == null) return null;
    // Most observed events never select this bridge. Resolve Actions only when
    // needed, after early handlers have settled focus.
    return _nativeDispatch ??= _newDispatch();
  }

  KeyEventResult withKeyDispatch(KeyEventResult Function() dispatch) {
    _keyDispatches.add(_newDispatch());
    try {
      return dispatch();
    } finally {
      _keyDispatches.removeLast();
    }
  }

  BuildContext _target(BuildContext? context) =>
      context ?? primaryFocus?.context ?? parentContext;

  Action<DismissIntent>? _applicationAction(DismissIntent intent) =>
      Actions.maybeFind<DismissIntent>(parentContext, intent: intent);

  @override
  bool isEnabled(DismissIntent intent, [BuildContext? context]) {
    if (OverlayManager.instance.hasConsumingBackTarget) return true;
    final action = _applicationAction(intent);
    return action is ContextAction<DismissIntent>
        ? action.isEnabled(intent, _target(context))
        : action?.isEnabled(intent) ?? false;
  }

  @override
  Object? invoke(DismissIntent intent, [BuildContext? context]) {
    invocations++;
    final dispatch =
        _keyDispatches.isEmpty ? _nativeKeyDispatch : _keyDispatches.last;
    // Preserve the application action while forwarding the dispatcher's final
    // value. Any actual back consumption in this boundary takes precedence,
    // including a dispatcher invoking the bridge before or after delegation.
    final invocation = dispatch?.claim();
    final manager = OverlayManager.instance;
    if (manager.hasConsumingBackTarget) {
      final result = manager.handleBackEvent();
      if (dispatch != null) dispatch.consumedBack = true;
      _backResults[result] = true;
      return result;
    }
    final action = _applicationAction(intent);
    if (action == null) {
      return null;
    }
    if (invocation != null) invocation.application = action;
    final target = _target(context);
    final (enabled, value) = Actions.of(
      target,
    ).invokeActionIfEnabled(action, intent, target);
    if (invocation != null) invocation.enabled = enabled;
    return value;
  }

  @override
  KeyEventResult toKeyEventResult(DismissIntent intent, Object? invokeResult) {
    final local = _keyDispatches.isNotEmpty;
    final dispatch = local ? _keyDispatches.last : _nativeKeyDispatch;
    if (dispatch != null) {
      dispatch.converted = true;
      try {
        if (dispatch.consumedBack) return KeyEventResult.handled;
        final invocation = dispatch.invocation;
        // A dispatcher may intercept without calling Action.invoke, so a back
        // target's mere presence cannot prove that this key consumed it. Only
        // actual bridge invocation can claim back handling; otherwise convert
        // the dispatcher's final value using the application's action.
        final result =
            invocation != null
                ? invocation.keyResult(intent, invokeResult)
                : dispatch.application?.toKeyEventResult(
                      intent,
                      invokeResult,
                    ) ??
                    super.toKeyEventResult(intent, invokeResult);
        return dispatch.consumedBack ? KeyEventResult.handled : result;
      } finally {
        if (!local && identical(_nativeDispatch, dispatch)) {
          // An ignored native boundary may reach another ancestor shortcut map.
          // Its invocation and conversion must start with independent state.
          _nativeDispatch = null;
        }
      }
    }
    // Ancestor/content ShortcutManagers can also invoke this bridge. Forward
    // their actual result, while recognizing our own async back requests weakly.
    if (invokeResult is Future<bool> && _backResults[invokeResult] == true) {
      return KeyEventResult.handled;
    }
    return _applicationAction(intent)?.toKeyEventResult(intent, invokeResult) ??
        super.toKeyEventResult(intent, invokeResult);
  }
}
