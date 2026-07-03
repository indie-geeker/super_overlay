/// Defines how a tagged overlay should interact with existing overlays.
enum OverlayStrategy {
  /// Show a new overlay even when another matching tag already exists.
  stack,

  /// Close the existing matching overlay before showing the new one.
  replaceExisting,

  /// Keep the existing matching overlay and do not show a duplicate.
  keepExisting,
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
