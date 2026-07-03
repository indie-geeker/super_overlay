import 'package:flutter/material.dart';

import 'overlay_policy.dart';

/// Shared options for overlays that support route and dismissal policy.
class OverlaySurfaceOptions {
  /// Creates shared overlay options.
  const OverlaySurfaceOptions({
    this.tag,
    this.strategy = OverlayStrategy.stack,
    this.dismissOnMaskTap = true,
    this.bindToRoute = true,
    this.backBehavior = OverlayBackBehavior.dismiss,
    this.displayDuration,
  });

  /// Business identifier for replacing, keeping, or closing overlays.
  final String? tag;

  /// How a tagged overlay interacts with an existing matching overlay.
  final OverlayStrategy strategy;

  /// Whether tapping the mask should close the overlay.
  final bool dismissOnMaskTap;

  /// Whether this overlay should hide and close with its owning route.
  ///
  /// Route-bound overlays hide when their route is covered, reappear when that
  /// route returns, and close when the route is removed.
  final bool bindToRoute;

  /// How this overlay responds to a system back event.
  final OverlayBackBehavior backBehavior;

  /// Optional automatic close duration.
  final Duration? displayDuration;
}

/// Options for command-style dialog overlays.
class OverlayDialogOptions extends OverlaySurfaceOptions {
  /// Creates dialog overlay options.
  const OverlayDialogOptions({
    super.tag,
    super.strategy,
    super.dismissOnMaskTap,
    super.bindToRoute,
    super.backBehavior,
    super.displayDuration,
    this.alignment = Alignment.center,
    this.barrierColor,
  });

  /// Where the dialog should be aligned inside the overlay host.
  final Alignment alignment;

  /// Optional barrier color for the dialog mask.
  final Color? barrierColor;
}

/// Options for command-style popup overlays.
class OverlayPopupOptions extends OverlaySurfaceOptions {
  /// Creates popup overlay options.
  const OverlayPopupOptions({
    super.tag,
    super.strategy,
    super.dismissOnMaskTap,
    super.bindToRoute,
    super.backBehavior,
    super.displayDuration,
    this.alignment = Alignment.bottomCenter,
    this.highlightTarget = false,
    this.maskIgnoreArea,
  });

  /// Popup alignment relative to its target.
  final Alignment alignment;

  /// Whether the target should be highlighted while the popup is visible.
  final bool highlightTarget;

  /// Optional area where the popup mask should not intercept input.
  final Rect? maskIgnoreArea;
}

/// Options for command-style loading overlays.
class OverlayLoadingOptions {
  /// Creates loading overlay options.
  const OverlayLoadingOptions({
    this.tag,
    this.dismissOnMaskTap = false,
    this.backBehavior = OverlayBackBehavior.dismiss,
    this.displayDuration,
    this.minimumVisibleDuration = Duration.zero,
  });

  /// Business identifier for this loading overlay.
  final String? tag;

  /// Whether tapping the mask should close the loading overlay.
  final bool dismissOnMaskTap;

  /// How the loading overlay responds to a system back event.
  final OverlayBackBehavior backBehavior;

  /// Optional automatic close duration.
  final Duration? displayDuration;

  /// Minimum time the loading overlay should stay visible before closing.
  final Duration minimumVisibleDuration;
}

/// Options for command-style toast overlays.
class OverlayToastOptions {
  /// Creates toast overlay options.
  const OverlayToastOptions({
    this.tag,
    this.strategy = OverlayStrategy.stack,
    this.displayPolicy = OverlayToastDisplayPolicy.queue,
    this.alignment = Alignment.bottomCenter,
    this.displayDuration = const Duration(milliseconds: 2000),
    this.consumeEvents = false,
  });

  /// Business identifier for replacing or keeping a toast.
  final String? tag;

  /// How a tagged toast interacts with an existing matching toast.
  final OverlayStrategy strategy;

  /// How untagged toast messages are displayed relative to other toasts.
  final OverlayToastDisplayPolicy displayPolicy;

  /// Where the toast should appear inside the overlay host.
  final Alignment alignment;

  /// How long the toast should stay visible.
  final Duration displayDuration;

  /// Whether the toast area should consume pointer events.
  final bool consumeEvents;
}

/// Options for command-style notification overlays.
class OverlayNotifyOptions {
  /// Creates notification overlay options.
  const OverlayNotifyOptions({
    this.tag,
    this.strategy = OverlayStrategy.stack,
    this.alignment = Alignment.topCenter,
    this.displayDuration = const Duration(milliseconds: 2500),
    this.backBehavior = OverlayBackBehavior.passThrough,
  });

  /// Business identifier for replacing or keeping a notification.
  final String? tag;

  /// How a tagged notification interacts with an existing matching notification.
  final OverlayStrategy strategy;

  /// Where the notification should appear inside the overlay host.
  final Alignment alignment;

  /// How long the notification should stay visible.
  final Duration? displayDuration;

  /// How this notification responds to a system back event.
  final OverlayBackBehavior backBehavior;
}
