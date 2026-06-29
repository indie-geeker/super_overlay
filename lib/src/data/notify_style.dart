import 'package:flutter/widgets.dart';

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
}
