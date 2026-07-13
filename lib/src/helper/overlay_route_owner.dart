import 'package:flutter/widgets.dart';

/// Immutable ownership captured when a route-scoped overlay command is made.
@immutable
class OverlayRouteOwner {
  const OverlayRouteOwner({
    required this.generation,
    required this.ownerIdentity,
    required this.scopeIdentity,
    required this.route,
    required this.invocationContext,
  });

  /// Active overlay host generation at capture time.
  final int generation;

  /// Integration identity that owns the captured scope.
  final Object ownerIdentity;

  /// Navigator observer scope identity.
  final Object scopeIdentity;

  /// Exact route containing [invocationContext].
  final Route<dynamic> route;

  /// Context from which the scoped facade was captured.
  final BuildContext invocationContext;
}
