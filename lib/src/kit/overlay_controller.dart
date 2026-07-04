import 'package:flutter/widgets.dart';

class SuperOverlayController {
  VoidCallback? _callback;

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

  void dismiss() {
    _callback = null;
  }
}
