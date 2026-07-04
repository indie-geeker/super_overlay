import 'package:flutter/widgets.dart';

import '../api/overlay_policy.dart';

class NotifyStyle {
  const NotifyStyle({
    this.successBuilder,
    this.failureBuilder,
    this.warningBuilder,
    this.errorBuilder,
    this.alertBuilder,
  });

  final Widget Function(String message)? successBuilder;
  final Widget Function(String message)? failureBuilder;
  final Widget Function(String message)? warningBuilder;
  final Widget Function(String message)? errorBuilder;
  final Widget Function(String message)? alertBuilder;

  Widget? build(OverlayNotificationType type, String message) {
    return switch (type) {
      OverlayNotificationType.success => successBuilder?.call(message),
      OverlayNotificationType.failure => failureBuilder?.call(message),
      OverlayNotificationType.warning => warningBuilder?.call(message),
      OverlayNotificationType.error => errorBuilder?.call(message),
      OverlayNotificationType.alert => alertBuilder?.call(message),
    };
  }
}
