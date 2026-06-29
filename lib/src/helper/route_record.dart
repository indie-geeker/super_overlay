import 'dart:collection';

import 'package:flutter/material.dart';

class RouteRecord {
  RouteRecord._();

  static final RouteRecord instance = RouteRecord._();

  final Queue<Route<dynamic>> _routes = DoubleLinkedQueue<Route<dynamic>>();

  Route<dynamic>? currentRoute;

  Iterable<Route<dynamic>> get routes => _routes;

  void reset() {
    _routes.clear();
    currentRoute = null;
  }

  void push(Route<dynamic> route) {
    _routes.remove(route);
    _routes.addLast(route);
    currentRoute = route;
  }

  void replace({
    required Route<dynamic>? oldRoute,
    required Route<dynamic>? newRoute,
  }) {
    if (oldRoute != null) {
      _routes.remove(oldRoute);
    }
    if (newRoute != null) {
      _routes.remove(newRoute);
      _routes.addLast(newRoute);
    }
    currentRoute = newRoute ?? (_routes.isEmpty ? null : _routes.last);
  }

  void remove(Route<dynamic> route) {
    _routes.remove(route);
    if (identical(currentRoute, route)) {
      currentRoute = _routes.isEmpty ? null : _routes.last;
    }
  }

  void pop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    currentRoute = previousRoute ?? (_routes.isEmpty ? null : _routes.last);
  }
}
