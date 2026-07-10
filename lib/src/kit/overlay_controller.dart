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
    if (!_visible.isCompleted) {
      _visible.complete();
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
