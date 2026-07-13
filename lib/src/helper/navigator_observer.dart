import 'package:flutter/material.dart';

import 'overlay_manager.dart';

class SuperOverlayObserver extends NavigatorObserver {
  SuperOverlayObserver({required Object ownerIdentity, VoidCallback? onDispose})
    : _ownerIdentity = ownerIdentity,
      _onDispose = onDispose;

  final Object _ownerIdentity;
  VoidCallback? _onDispose;
  bool _disposed = false;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_disposed) {
      return;
    }
    OverlayManager.instance.handleRoutePushed(
      ownerIdentity: _ownerIdentity,
      route: route,
      previousRoute: previousRoute,
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_disposed) {
      return;
    }
    OverlayManager.instance.handleRoutePopped(
      ownerIdentity: _ownerIdentity,
      route: route,
      previousRoute: previousRoute,
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_disposed) {
      return;
    }
    OverlayManager.instance.handleRouteRemoved(
      ownerIdentity: _ownerIdentity,
      route: route,
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (_disposed) {
      return;
    }
    OverlayManager.instance.handleRouteReplaced(
      ownerIdentity: _ownerIdentity,
      oldRoute: oldRoute,
      newRoute: newRoute,
    );
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final onDispose = _onDispose;
    _onDispose = null;
    onDispose?.call();
  }
}
