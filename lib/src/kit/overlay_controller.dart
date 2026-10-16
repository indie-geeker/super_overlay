import 'dart:async';

import 'package:flutter/widgets.dart';

class SuperOverlayController {
  SuperOverlayController() {
    unawaited(
      _visible.future.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
    );
  }

  VoidCallback? _callback;
  final Completer<void> _visible = Completer<void>();
  bool _presentationEnabled = true;
  bool _hasRenderedFrame = false;

  Future<void> get visible => _visible.future;

  void refresh() {
    _callback?.call();
  }

  void setListener(VoidCallback? callback) {
    _callback = callback;
  }

  void removeListener(VoidCallback callback) {
    if (identical(_callback, callback)) {
      _callback = null;
    }
  }

  void markVisible() {
    _hasRenderedFrame = true;
    if (!_presentationEnabled) {
      return;
    }
    if (!_visible.isCompleted) {
      _visible.complete();
    }
  }

  void setPresentationEnabled(bool enabled) {
    if (_presentationEnabled == enabled) return;
    _presentationEnabled = enabled;
    // A route can suspend after content was painted but before its first
    // frame callback. That content is retained and may not rebuild on resume.
    if (enabled && _hasRenderedFrame && !_visible.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_presentationEnabled) markVisible();
      });
    }
  }

  void failVisible(String message) {
    if (!_visible.isCompleted) {
      _visible.completeError(StateError(message));
    }
  }

  void dismiss() {
    _callback = null;
    failVisible('The overlay closed before its first rendered frame.');
  }
}
