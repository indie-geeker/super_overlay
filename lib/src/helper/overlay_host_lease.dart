import 'package:flutter/widgets.dart';

import '../data/notify_style.dart';
import '../kit/super_overlay_entry.dart';
import '../kit/typedef.dart';
import 'overlay_manager.dart';

class OverlayHostLease {
  OverlayHostLease.acquire({
    required Object ownerIdentity,
    required SuperOverlayToastBuilder? toastBuilder,
    required SuperOverlayLoadingBuilder? loadingBuilder,
    required NotifyStyle? notifyStyle,
  }) : _ownerIdentity = ownerIdentity,
       _generation = OverlayManager.instance.acquireHost(
         ownerIdentity: ownerIdentity,
         toastBuilder: toastBuilder,
         loadingBuilder: loadingBuilder,
         notifyStyle: notifyStyle,
       );

  final Object _ownerIdentity;
  final int _generation;
  bool _disposed = false;

  int get generation => _generation;

  SuperOverlayEntry get entryLoading =>
      OverlayManager.instance.entryForHost(_generation);

  void captureContexts({
    required Object ownerIdentity,
    required BuildContext context,
  }) {
    _ensureOwner(ownerIdentity);
    if (_disposed) {
      throw StateError('Cannot capture contexts with a disposed host lease.');
    }
    OverlayManager.instance.captureHostContexts(_generation, context);
  }

  void updateDefaults({
    required Object ownerIdentity,
    required SuperOverlayToastBuilder? toastBuilder,
    required SuperOverlayLoadingBuilder? loadingBuilder,
    required NotifyStyle? notifyStyle,
  }) {
    _ensureOwner(ownerIdentity);
    if (_disposed) {
      throw StateError('Cannot update defaults with a disposed host lease.');
    }
    OverlayManager.instance.updateHostDefaults(
      generation: _generation,
      toastBuilder: toastBuilder,
      loadingBuilder: loadingBuilder,
      notifyStyle: notifyStyle,
    );
  }

  void dispose({required Object ownerIdentity}) {
    _ensureOwner(ownerIdentity);
    if (_disposed) {
      return;
    }
    _disposed = true;
    OverlayManager.instance.releaseHost(_generation);
  }

  void _ensureOwner(Object ownerIdentity) {
    if (!identical(_ownerIdentity, ownerIdentity)) {
      throw StateError('The overlay host lease belongs to another owner.');
    }
  }
}
