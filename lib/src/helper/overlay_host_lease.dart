import 'package:flutter/widgets.dart';

import 'overlay_manager.dart';

class OverlayHostLease {
  OverlayHostLease.acquire({required Object ownerIdentity})
    : _ownerIdentity = ownerIdentity {
    OverlayManager.instance.initialize();
  }

  final Object _ownerIdentity;
  bool _disposed = false;

  void captureContexts({
    required Object ownerIdentity,
    required BuildContext context,
  }) {
    _ensureOwner(ownerIdentity);
    if (_disposed) {
      throw StateError('Cannot capture contexts with a disposed host lease.');
    }
    OverlayManager.instance.captureContexts(context);
  }

  void dispose({required Object ownerIdentity}) {
    _ensureOwner(ownerIdentity);
    if (_disposed) {
      return;
    }
    _disposed = true;
    OverlayManager.instance.disposeHost();
  }

  void _ensureOwner(Object ownerIdentity) {
    if (!identical(_ownerIdentity, ownerIdentity)) {
      throw StateError('The overlay host lease belongs to another owner.');
    }
  }
}
