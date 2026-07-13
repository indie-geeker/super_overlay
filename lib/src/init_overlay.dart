import 'package:flutter/material.dart';

import 'helper/monitor_widget_helper.dart';
import 'helper/overlay_host_lease.dart';
import 'helper/overlay_manager.dart';
import 'helper/pop_route_monitor.dart';
import 'kit/super_overlay_entry.dart';
import 'kit/typedef.dart';
import 'data/notify_style.dart';
import 'config/overlay_config.dart';

typedef SuperOverlayStyleBuilder = Widget Function(Widget child);

class SuperOverlayInit extends StatefulWidget {
  const SuperOverlayInit({
    super.key,
    required this.child,
    required this.ownerIdentity,
    this.styleBuilder,
    this.toastBuilder,
    this.loadingBuilder,
    this.notifyStyle,
  });

  final Widget? child;
  final Object ownerIdentity;
  final SuperOverlayStyleBuilder? styleBuilder;
  final SuperOverlayToastBuilder? toastBuilder;
  final SuperOverlayLoadingBuilder? loadingBuilder;
  final NotifyStyle? notifyStyle;

  static TransitionBuilder init({
    required Object ownerIdentity,
    TransitionBuilder? builder,
    SuperOverlayStyleBuilder? styleBuilder,
    SuperOverlayToastBuilder? toastBuilder,
    SuperOverlayLoadingBuilder? loadingBuilder,
    NotifyStyle? notifyStyle,
  }) {
    return (context, child) {
      final overlay = SuperOverlayInit(
        ownerIdentity: ownerIdentity,
        styleBuilder: styleBuilder,
        toastBuilder: toastBuilder,
        loadingBuilder: loadingBuilder,
        notifyStyle: notifyStyle,
        child: child,
      );
      if (builder == null) {
        return overlay;
      }
      return builder(context, overlay);
    };
  }

  @override
  State<SuperOverlayInit> createState() => _SuperOverlayInitState();
}

class _SuperOverlayInitState extends State<SuperOverlayInit> {
  late final SuperOverlayEntry _appEntry;
  late final OverlayHostLease _hostLease;

  @override
  void initState() {
    super.initState();
    _hostLease = OverlayHostLease.acquire(ownerIdentity: widget.ownerIdentity);
    PopRouteMonitor.instance.ensureRegistered();
    MonitorWidgetHelper.instance.ensureRegistered();
    _applyDefaultBuilders();
    _appEntry = SuperOverlayEntry(
      builder: (context) {
        _hostLease.captureContexts(
          ownerIdentity: widget.ownerIdentity,
          context: context,
        );
        return widget.child ?? const SizedBox.shrink();
      },
    );
  }

  @override
  void didUpdateWidget(covariant SuperOverlayInit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.toastBuilder != widget.toastBuilder ||
        oldWidget.loadingBuilder != widget.loadingBuilder ||
        oldWidget.notifyStyle != widget.notifyStyle) {
      _applyDefaultBuilders();
    }
  }

  void _applyDefaultBuilders() {
    overlayConfig.toast = overlayConfig.toast.withBuilder(widget.toastBuilder);
    overlayConfig.loading = overlayConfig.loading.withBuilder(
      widget.loadingBuilder,
    );
    overlayConfig.notify = overlayConfig.notify.withStyle(widget.notifyStyle);
  }

  @override
  void dispose() {
    overlayConfig.toast = overlayConfig.toast.withBuilder(null);
    overlayConfig.loading = overlayConfig.loading.withBuilder(null);
    overlayConfig.notify = overlayConfig.notify.withStyle(null);
    _hostLease.dispose(ownerIdentity: widget.ownerIdentity);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overlay = Overlay(
      initialEntries: [_appEntry, OverlayManager.instance.entryLoading],
    );
    return widget.styleBuilder?.call(overlay) ??
        Material(color: Colors.transparent, child: overlay);
  }
}
