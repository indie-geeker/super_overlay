import 'package:flutter/widgets.dart';

import '../config/enum_config.dart';

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

  Widget? build(NotifyType type, String message) {
    return switch (type) {
      NotifyType.success => successBuilder?.call(message),
      NotifyType.failure => failureBuilder?.call(message),
      NotifyType.warning => warningBuilder?.call(message),
      NotifyType.error => errorBuilder?.call(message),
      NotifyType.alert => alertBuilder?.call(message),
    };
  }
}
