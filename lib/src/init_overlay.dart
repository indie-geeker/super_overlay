import 'package:flutter/material.dart';

import 'helper/monitor_widget_helper.dart';
import 'helper/navigator_observer.dart';
import 'helper/overlay_manager.dart';
import 'helper/pop_route_monitor.dart';
import 'kit/super_overlay_entry.dart';
import 'kit/typedef.dart';
import 'data/notify_style.dart';
import 'super_overlay_core.dart';

typedef SuperOverlayStyleBuilder = Widget Function(Widget child);

class SuperOverlayInit extends StatefulWidget {
  const SuperOverlayInit({
    super.key,
    required this.child,
    this.styleBuilder,
    this.toastBuilder,
    this.loadingBuilder,
    this.notifyStyle,
  });

  final Widget? child;
  final SuperOverlayStyleBuilder? styleBuilder;
  final SuperOverlayToastBuilder? toastBuilder;
  final SuperOverlayLoadingBuilder? loadingBuilder;
  final NotifyStyle? notifyStyle;

  static final NavigatorObserver observer = SuperOverlayObserver();

  static TransitionBuilder init({
    TransitionBuilder? builder,
    SuperOverlayStyleBuilder? styleBuilder,
    SuperOverlayToastBuilder? toastBuilder,
    SuperOverlayLoadingBuilder? loadingBuilder,
    NotifyStyle? notifyStyle,
  }) {
    return (context, child) {
      final overlay = SuperOverlayInit(
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

  @override
  void initState() {
    super.initState();
    OverlayManager.instance.initialize();
    PopRouteMonitor.instance.ensureRegistered();
    MonitorWidgetHelper.instance.ensureRegistered();
    _applyDefaultBuilders();
    _appEntry = SuperOverlayEntry(
      builder: (context) {
        OverlayManager.instance.captureContexts(context);
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
    final toastBuilder = widget.toastBuilder;
    if (toastBuilder != null) {
      SuperOverlay.config.toast = SuperOverlay.config.toast.copyWith(
        builder: toastBuilder,
      );
    }

    final loadingBuilder = widget.loadingBuilder;
    if (loadingBuilder != null) {
      SuperOverlay.config.loading = SuperOverlay.config.loading.copyWith(
        builder: loadingBuilder,
      );
    }

    final notifyStyle = widget.notifyStyle;
    if (notifyStyle != null) {
      SuperOverlay.config.notify = SuperOverlay.config.notify.copyWith(
        style: notifyStyle,
      );
    }
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
