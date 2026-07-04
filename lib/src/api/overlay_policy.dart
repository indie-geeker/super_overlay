/// Defines how a tagged overlay should interact with existing overlays.
enum OverlayStrategy {
  /// Show a new overlay even when another matching tag already exists.
  stack,

  /// Close the existing matching overlay before showing the new one.
  replaceExisting,

  /// Keep the existing matching overlay and do not show a duplicate.
  keepExisting,
}

/// Names the overlay surface family that a command should inspect.
enum OverlaySurface {
  /// Dialog overlays shown through `SuperOverlay.dialog`.
  dialog,

  /// Popup overlays shown through `SuperOverlay.popup`.
  popup,

  /// Notification overlays shown through `SuperOverlay.notify`.
  notification,

  /// Loading overlays shown through `SuperOverlay.loading`.
  loading,

  /// Toast overlays shown through `SuperOverlay.toast`.
  toast,
}

/// Selects which overlay or overlay family should be closed.
enum OverlayCloseTarget {
  /// Close the most relevant currently active overlay.
  ///
  /// Loading has priority, followed by notification, dialog or popup, then
  /// toast. Use a more specific target when the caller owns a particular flow.
  topMost,

  /// Close one dialog overlay.
  dialog,

  /// Close every dialog overlay.
  allDialogs,

  /// Close one popup overlay.
  popup,

  /// Close every popup overlay.
  allPopups,

  /// Close one notification overlay.
  notification,

  /// Close every notification overlay.
  allNotifications,

  /// Close the loading overlay.
  loading,

  /// Close one toast overlay.
  toast,

  /// Close every toast overlay.
  allToasts,

  /// Close every overlay surface managed by SuperOverlay.
  all,
}

/// Defines how an overlay responds to a system back event.
enum OverlayBackBehavior {
  /// Close the overlay and consume the back event.
  dismiss,

  /// Keep the overlay visible and consume the back event.
  block,

  /// Ignore the back event and let the app handle it.
  passThrough,
}

/// Defines how a popup is positioned relative to its target.
enum OverlayPopupAlignmentMode {
  /// Keep the popup inside the target bounds.
  inside,

  /// Center the popup on the target edge or corner.
  center,

  /// Place the popup outside the target bounds.
  outside,
}

/// Defines how toast messages are displayed relative to active toasts.
enum OverlayToastDisplayPolicy {
  /// Show toast messages one after another.
  queue,

  /// Replace the active toast with the latest toast.
  replaceLatest,

  /// Refresh the active toast content instead of adding a new entry.
  refreshActive,

  /// Show multiple toast messages at the same time.
  stack,
}

/// Identifies a notification visual style.
enum OverlayNotificationType {
  /// Success notification.
  success,

  /// Failure notification.
  failure,

  /// Warning notification.
  warning,

  /// Error notification.
  error,

  /// Alert notification.
  alert,
}
