import 'package:flutter/material.dart';

import 'overlay_manager.dart';
import 'route_record.dart';

class SuperOverlayObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    RouteRecord.instance.push(route);
    OverlayManager.instance.handleRoutePushed(
      route: route,
      previousRoute: previousRoute,
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    RouteRecord.instance.pop(route, previousRoute);
    OverlayManager.instance.handleRoutePopped(
      route: route,
      previousRoute: previousRoute,
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    RouteRecord.instance.remove(route);
    OverlayManager.instance.handleRouteRemoved(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
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
}
