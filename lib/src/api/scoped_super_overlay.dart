part of '../super_overlay_core.dart';

/// Commands captured against one exact observed Navigator route.
///
/// Obtain this facade with a context below the Navigator that owns the route.
/// A context above a nested or shell Navigator resolves to its parent scope.
/// Local inherited themes are captured when the facade is created. Other
/// inherited dependencies must be supplied explicitly to the overlay content.
/// Feedback and global cleanup use [SuperOverlay] directly.
class ScopedSuperOverlay {
  ScopedSuperOverlay._(OverlayRouteOwner routeOwner, CapturedThemes themes)
    : dialog = ScopedOverlayDialogService._(routeOwner, themes),
      popup = ScopedOverlayPopupService._(routeOwner, themes);

  /// Dialog commands owned by the captured route.
  final ScopedOverlayDialogService dialog;

  /// Popup commands owned by the captured route.
  final ScopedOverlayPopupService popup;
}

/// Route-owned dialog commands captured by [SuperOverlay.of].
class ScopedOverlayDialogService {
  const ScopedOverlayDialogService._(this._routeOwner, this._themes);

  final OverlayRouteOwner _routeOwner;
  final CapturedThemes _themes;

  /// Shows a route-owned dialog whose builder receives its typed handle.
  OverlayHandle<T> show<T>({
    required OverlayWidgetBuilder<T> builder,
    OverlayDialogOptions options = const OverlayDialogOptions(),
  }) {
    return SuperOverlay.dialog._show<T>(
      builder: builder,
      options: options,
      routeOwner: _routeOwner,
      themes: _themes,
    );
  }
}

/// Route-owned popup commands captured by [SuperOverlay.of].
class ScopedOverlayPopupService {
  const ScopedOverlayPopupService._(this._routeOwner, this._themes);

  final OverlayRouteOwner _routeOwner;
  final CapturedThemes _themes;

  /// Shows a route-owned popup whose builder receives its typed handle.
  OverlayHandle<T> show<T>({
    BuildContext? targetContext,
    required OverlayWidgetBuilder<T> builder,
    OverlayPopupOptions options = const OverlayPopupOptions(),
  }) {
    return SuperOverlay.popup._show<T>(
      targetContext: targetContext,
      builder: builder,
      options: options,
      routeOwner: _routeOwner,
      themes: _themes,
    );
  }
}
