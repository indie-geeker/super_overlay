import 'package:flutter/material.dart';

import 'navigator_scope_registry.dart';
import 'overlay_manager.dart';

class SuperOverlayObserver extends NavigatorObserver {
  SuperOverlayObserver({
    required Object ownerIdentity,
    bool isRoot = true,
    VoidCallback? onDispose,
  }) : _ownerIdentity = ownerIdentity,
       _onDispose = onDispose {
    NavigatorScopeRegistry.instance.registerObserver(
      ownerIdentity: ownerIdentity,
      scopeIdentity: _scopeIdentity,
      isRoot: isRoot,
      navigatorState: () => navigator,
      onBackRequested: OverlayManager.instance.handleBackEventForGeneration,
    );
  }

  final Object _ownerIdentity;
  final Object _scopeIdentity = Object();
  VoidCallback? _onDispose;
  bool _disposed = false;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_disposed) {
      return;
    }
    NavigatorScopeRegistry.instance.routePushed(
      scopeIdentity: _scopeIdentity,
      route: route,
    );
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
    NavigatorScopeRegistry.instance.routePopped(
      scopeIdentity: _scopeIdentity,
      route: route,
      previousRoute: previousRoute,
    );
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
    NavigatorScopeRegistry.instance.routeRemoved(
      scopeIdentity: _scopeIdentity,
      route: route,
      previousRoute: previousRoute,
    );
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
    NavigatorScopeRegistry.instance.routeReplaced(
      scopeIdentity: _scopeIdentity,
      oldRoute: oldRoute,
      newRoute: newRoute,
    );
    OverlayManager.instance.handleRouteReplaced(
      ownerIdentity: _ownerIdentity,
      oldRoute: oldRoute,
      newRoute: newRoute,
    );
  }

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    if (_disposed) {
      return;
    }
    NavigatorScopeRegistry.instance.topRouteChanged(
      scopeIdentity: _scopeIdentity,
      topRoute: topRoute,
    );
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    NavigatorScopeRegistry.instance.unregisterObserver(_scopeIdentity);
    final onDispose = _onDispose;
    _onDispose = null;
    onDispose?.call();
  }
}
