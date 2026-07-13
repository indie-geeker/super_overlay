import 'package:flutter/material.dart';

import 'overlay_manager.dart';
import 'route_record.dart';

class SuperOverlayObserver extends NavigatorObserver {
  SuperOverlayObserver({VoidCallback? onDispose}) : _onDispose = onDispose;

  VoidCallback? _onDispose;
  bool _disposed = false;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_disposed) {
      return;
    }
    RouteRecord.instance.push(route);
    OverlayManager.instance.handleRoutePushed(
      route: route,
      previousRoute: previousRoute,
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_disposed) {
      return;
    }
    RouteRecord.instance.pop(route, previousRoute);
    OverlayManager.instance.handleRoutePopped(
      route: route,
      previousRoute: previousRoute,
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_disposed) {
      return;
    }
    RouteRecord.instance.remove(route);
    OverlayManager.instance.handleRouteRemoved(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (_disposed) {
      return;
    }
    RouteRecord.instance.replace(oldRoute: oldRoute, newRoute: newRoute);
    if (oldRoute != null) {
      OverlayManager.instance.handleRouteRemoved(oldRoute);
    }
    if (newRoute != null) {
      OverlayManager.instance.handleRoutePushed(
        route: newRoute,
        previousRoute: null,
      );
    }
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
