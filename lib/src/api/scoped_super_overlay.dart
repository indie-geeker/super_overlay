part of '../super_overlay_core.dart';

/// Commands captured against one exact observed Navigator route.
class ScopedSuperOverlay {
  ScopedSuperOverlay._(OverlayRouteOwner routeOwner)
    : dialog = ScopedOverlayDialogService._(routeOwner),
      popup = ScopedOverlayPopupService._(routeOwner);

  /// Dialog commands owned by the captured route.
  final ScopedOverlayDialogService dialog;

  /// Popup commands owned by the captured route.
  final ScopedOverlayPopupService popup;

  /// Loading remains global to the one active root host.
  OverlayLoadingService get loading => SuperOverlay.loading;

  /// Notifications remain global to the one active root host.
  OverlayNotifyService get notify => SuperOverlay.notify;

  /// Shows a root-host toast.
  OverlayHandle<void> toast(
    String message, {
    WidgetBuilder? builder,
    OverlayToastOptions options = const OverlayToastOptions(),
  }) {
    return SuperOverlay.toast(message, builder: builder, options: options);
  }

  /// Runs a global close command against the active root host.
  Future<void> close<T>({
    OverlayCloseTarget target = OverlayCloseTarget.topMost,
    String? tag,
    T? result,
    bool force = false,
  }) {
    return SuperOverlay.close<T>(
      target: target,
      tag: tag,
      result: result,
      force: force,
    );
  }

  /// Queries the one active root host.
  bool exists({
    String? tag,
    Set<OverlaySurface> surfaces = const {
      OverlaySurface.dialog,
      OverlaySurface.popup,
      OverlaySurface.loading,
      OverlaySurface.notification,
      OverlaySurface.toast,
    },
  }) {
    return SuperOverlay.exists(tag: tag, surfaces: surfaces);
  }
}

/// Route-owned dialog commands captured by [SuperOverlay.of].
class ScopedOverlayDialogService {
  const ScopedOverlayDialogService._(this._routeOwner);

  final OverlayRouteOwner _routeOwner;

  /// Shows a dialog owned by the facade's captured Navigator route.
  OverlayHandle<T> show<T>({
    required WidgetBuilder builder,
    OverlayDialogOptions options = const OverlayDialogOptions(),
  }) {
    return SuperOverlay.dialog._show<T>(
      builder: builder,
      options: options,
      routeOwner: _routeOwner,
    );
  }
}

/// Route-owned popup commands captured by [SuperOverlay.of].
class ScopedOverlayPopupService {
  const ScopedOverlayPopupService._(this._routeOwner);

  final OverlayRouteOwner _routeOwner;

  /// Shows a popup owned by the facade's captured Navigator route.
  OverlayHandle<T> show<T>({
    BuildContext? targetContext,
    required WidgetBuilder builder,
    OverlayPopupOptions options = const OverlayPopupOptions(),
  }) {
    return SuperOverlay.popup._show<T>(
      targetContext: targetContext,
      builder: builder,
      options: options,
      routeOwner: _routeOwner,
    );
  }
}
