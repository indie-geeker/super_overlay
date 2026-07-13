import 'dart:collection';

import 'package:flutter/widgets.dart';

import 'overlay_pop_entry.dart';

/// Tracks the route-level pop gates installed by SuperOverlay observers.
///
/// Overlay ownership remains global within one integration while each
/// Navigator keeps an independent route and PopEntry lifecycle.
class NavigatorScopeRegistry {
  NavigatorScopeRegistry._();

  static final NavigatorScopeRegistry instance = NavigatorScopeRegistry._();

  final Map<Object, _NavigatorScope> _scopes =
      HashMap<Object, _NavigatorScope>.identity();
  final Map<Object, Set<int>> _hostGenerations =
      HashMap<Object, Set<int>>.identity();
  final Map<Object, bool> _backBlocked = HashMap<Object, bool>.identity();

  void registerObserver({
    required Object ownerIdentity,
    required Object scopeIdentity,
    required bool isRoot,
    required bool Function() isAttached,
    required OverlayBackRequest onBackRequested,
  }) {
    if (_scopes.containsKey(scopeIdentity)) {
      return;
    }
    final scope = _NavigatorScope(
      ownerIdentity: ownerIdentity,
      isRoot: isRoot,
      isAttached: isAttached,
      onBackRequested: onBackRequested,
    );
    _scopes[scopeIdentity] = scope;
    final generation = _currentHostGeneration(ownerIdentity);
    if (generation != null) {
      scope.bindGeneration(generation);
    }
  }

  void unregisterObserver(Object scopeIdentity) {
    _scopes.remove(scopeIdentity)?.dispose();
  }

  void attachHost({required Object ownerIdentity, required int generation}) {
    final generations = _hostGenerations.putIfAbsent(
      ownerIdentity,
      () => <int>{},
    );
    generations.add(generation);
    for (final scope in _scopesForOwner(ownerIdentity)) {
      scope.bindGeneration(generation);
    }
  }

  void detachHost({required Object ownerIdentity, required int generation}) {
    final generations = _hostGenerations[ownerIdentity];
    if (generations == null || !generations.remove(generation)) {
      return;
    }
    for (final scope in _scopesForOwner(ownerIdentity)) {
      scope.unbindGeneration(generation);
    }
    if (generations.isEmpty) {
      _hostGenerations.remove(ownerIdentity);
      _backBlocked.remove(ownerIdentity);
    } else {
      final survivingGeneration = generations.last;
      for (final scope in _scopesForOwner(ownerIdentity)) {
        if (scope.generation == null) {
          scope.bindGeneration(survivingGeneration);
        }
      }
    }
  }

  void routePushed({
    required Object scopeIdentity,
    required Route<dynamic> route,
  }) {
    _scopes[scopeIdentity]?.push(route, _isBackBlockedForScope(scopeIdentity));
  }

  void routePopped({
    required Object scopeIdentity,
    required Route<dynamic> route,
    required Route<dynamic>? previousRoute,
  }) {
    _scopes[scopeIdentity]?.pop(
      route,
      previousRoute,
      _isBackBlockedForScope(scopeIdentity),
    );
  }

  void routeRemoved({
    required Object scopeIdentity,
    required Route<dynamic> route,
    required Route<dynamic>? previousRoute,
  }) {
    _scopes[scopeIdentity]?.remove(
      route,
      previousRoute,
      _isBackBlockedForScope(scopeIdentity),
    );
  }

  void routeReplaced({
    required Object scopeIdentity,
    required Route<dynamic>? oldRoute,
    required Route<dynamic>? newRoute,
  }) {
    _scopes[scopeIdentity]?.replace(
      oldRoute: oldRoute,
      newRoute: newRoute,
      backBlocked: _isBackBlockedForScope(scopeIdentity),
    );
  }

  void topRouteChanged({
    required Object scopeIdentity,
    required Route<dynamic> topRoute,
  }) {
    _scopes[scopeIdentity]?.changeTop(
      topRoute,
      _isBackBlockedForScope(scopeIdentity),
    );
  }

  void updateBackDisposition({
    required Object ownerIdentity,
    required int generation,
    required bool blocked,
  }) {
    if (_hostGenerations[ownerIdentity]?.contains(generation) != true) {
      return;
    }
    _backBlocked[ownerIdentity] = blocked;
    for (final scope in _scopesForOwner(ownerIdentity)) {
      if (scope.generation == generation) {
        scope.updateBackDisposition(blocked);
      }
    }
  }

  void transferRootRoutes({
    required Object fromOwnerIdentity,
    required int fromGeneration,
    required Object toOwnerIdentity,
    required int toGeneration,
  }) {
    final fromRoots = _scopesForOwner(fromOwnerIdentity)
        .where((scope) => scope.isRoot && scope.generation == fromGeneration)
        .toList(growable: false);
    final toRoots = _scopesForOwner(toOwnerIdentity)
        .where((scope) => scope.isRoot && scope.generation == toGeneration)
        .toList(growable: false);
    if (fromRoots.length != 1 || toRoots.length != 1) {
      return;
    }
    final snapshot = fromRoots.single.takeRouteSnapshot();
    toRoots.single.restoreRouteSnapshot(
      snapshot,
      _backBlocked[toOwnerIdentity] == true,
    );
  }

  void pruneDetachedRoot({
    required Object ownerIdentity,
    required int generation,
  }) {
    for (final scope in _scopesForOwner(ownerIdentity)) {
      if (scope.isRoot &&
          scope.generation == generation &&
          !scope.isAttached()) {
        scope.clearDetachedRoutes();
      }
    }
  }

  ModalRoute<dynamic> requireRootModalRoute({
    required Object ownerIdentity,
    required int generation,
    required String operation,
  }) {
    final roots = _scopesForOwner(ownerIdentity)
        .where((scope) => scope.isRoot && scope.generation == generation)
        .toList(growable: false);
    if (roots.length != 1 ||
        !roots.single.isAttached() ||
        roots.single.currentRoute == null) {
      throw StateError(
        '$operation requires the matching SuperOverlay NavigatorObserver to '
        'be installed on the active Navigator and to have a current ModalRoute.',
      );
    }
    final route = roots.single.currentRoute;
    if (route is! ModalRoute<dynamic>) {
      throw StateError(
        '$operation requires the current Navigator route to be a ModalRoute; '
        'the matching observer currently reports ${route.runtimeType}.',
      );
    }
    return route;
  }

  Iterable<_NavigatorScope> _scopesForOwner(Object ownerIdentity) {
    return _scopes.values.where(
      (scope) => identical(scope.ownerIdentity, ownerIdentity),
    );
  }

  int? _currentHostGeneration(Object ownerIdentity) {
    final generations = _hostGenerations[ownerIdentity];
    if (generations == null || generations.isEmpty) {
      return null;
    }
    return generations.last;
  }

  bool _isBackBlockedForScope(Object scopeIdentity) {
    final scope = _scopes[scopeIdentity];
    return scope != null && _backBlocked[scope.ownerIdentity] == true;
  }
}

class _NavigatorScope {
  _NavigatorScope({
    required this.ownerIdentity,
    required this.isRoot,
    required this.isAttached,
    required this.onBackRequested,
  });

  final Object ownerIdentity;
  final bool isRoot;
  final bool Function() isAttached;
  final OverlayBackRequest onBackRequested;
  final List<Route<dynamic>> _routes = <Route<dynamic>>[];
  final Map<ModalRoute<dynamic>, OverlayPopEntry> _entries =
      HashMap<ModalRoute<dynamic>, OverlayPopEntry>.identity();

  int? generation;
  Route<dynamic>? currentRoute;
  bool _disposed = false;

  void bindGeneration(int value) {
    if (_disposed || generation == value) {
      return;
    }
    _clearRoutes();
    generation = value;
  }

  void unbindGeneration(int value) {
    if (_disposed || generation != value) {
      return;
    }
    _clearRoutes();
    generation = null;
  }

  void push(Route<dynamic> route, bool backBlocked) {
    if (_disposed || generation == null) {
      return;
    }
    if (!_routes.any((candidate) => identical(candidate, route))) {
      _routes.add(route);
      _register(route);
    }
    currentRoute = route;
    updateBackDisposition(backBlocked);
  }

  void pop(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
    bool backBlocked,
  ) {
    if (_disposed) {
      return;
    }
    _unregister(route);
    _routes.removeWhere((candidate) => identical(candidate, route));
    if (identical(currentRoute, route)) {
      currentRoute = previousRoute ?? (_routes.isEmpty ? null : _routes.last);
    }
    updateBackDisposition(backBlocked);
  }

  void remove(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
    bool backBlocked,
  ) {
    pop(route, previousRoute, backBlocked);
  }

  void replace({
    required Route<dynamic>? oldRoute,
    required Route<dynamic>? newRoute,
    required bool backBlocked,
  }) {
    if (_disposed) {
      return;
    }
    var index = -1;
    if (oldRoute != null) {
      index = _routes.indexWhere((route) => identical(route, oldRoute));
      _unregister(oldRoute);
      if (index >= 0) {
        _routes.removeAt(index);
      }
    }
    if (newRoute != null && generation != null) {
      if (index < 0 || index > _routes.length) {
        _routes.add(newRoute);
      } else {
        _routes.insert(index, newRoute);
      }
      _register(newRoute);
    }
    if (oldRoute == null || identical(currentRoute, oldRoute)) {
      currentRoute = newRoute ?? (_routes.isEmpty ? null : _routes.last);
    }
    updateBackDisposition(backBlocked);
  }

  void changeTop(Route<dynamic> route, bool backBlocked) {
    if (_disposed || generation == null) {
      return;
    }
    if (!_routes.any((candidate) => identical(candidate, route))) {
      _routes.add(route);
      _register(route);
    }
    currentRoute = route;
    updateBackDisposition(backBlocked);
  }

  void updateBackDisposition(bool blocked) {
    if (_disposed) {
      return;
    }
    for (final entry in _entries.entries) {
      entry.value.updateCanPop(
        !(blocked && identical(entry.key, currentRoute)),
      );
    }
  }

  _NavigatorRouteSnapshot takeRouteSnapshot() {
    final snapshot = _NavigatorRouteSnapshot(
      routes: List<Route<dynamic>>.of(_routes),
      currentRoute: currentRoute,
    );
    _clearRoutes();
    return snapshot;
  }

  void clearDetachedRoutes() {
    if (_disposed || isAttached()) {
      return;
    }
    _clearRoutes();
  }

  void restoreRouteSnapshot(
    _NavigatorRouteSnapshot snapshot,
    bool backBlocked,
  ) {
    if (_disposed || generation == null) {
      return;
    }
    _clearRoutes();
    for (final route in snapshot.routes) {
      if (_routes.any((candidate) => identical(candidate, route))) {
        continue;
      }
      _routes.add(route);
      _register(route);
    }
    currentRoute = snapshot.currentRoute;
    updateBackDisposition(backBlocked);
  }

  void _register(Route<dynamic> route) {
    if (route is! ModalRoute<dynamic> || _entries.containsKey(route)) {
      return;
    }
    final value = generation;
    if (value == null) {
      return;
    }
    final entry = OverlayPopEntry(
      generation: value,
      onBackRequested: onBackRequested,
    );
    _entries[route] = entry;
    route.registerPopEntry(entry);
  }

  void _unregister(Route<dynamic> route) {
    if (route is! ModalRoute<dynamic>) {
      return;
    }
    final entry = _entries.remove(route);
    if (entry == null) {
      return;
    }
    route.unregisterPopEntry(entry);
    entry.dispose();
  }

  void _clearRoutes() {
    for (final route in _entries.keys.toList(growable: false)) {
      _unregister(route);
    }
    _routes.clear();
    currentRoute = null;
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _clearRoutes();
    generation = null;
    _disposed = true;
  }
}

class _NavigatorRouteSnapshot {
  const _NavigatorRouteSnapshot({
    required this.routes,
    required this.currentRoute,
  });

  final List<Route<dynamic>> routes;
  final Route<dynamic>? currentRoute;
}
