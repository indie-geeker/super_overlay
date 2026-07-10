import 'dart:async';

import 'package:flutter/widgets.dart';

class SuperOverlayController {
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

  void dismiss() {
    _callback = null;
    markVisible();
  }
}
