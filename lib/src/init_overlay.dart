import 'package:flutter/material.dart';

import 'helper/monitor_widget_helper.dart';
import 'helper/navigator_observer.dart';
import 'helper/overlay_manager.dart';
import 'helper/pop_route_monitor.dart';
import 'kit/super_overlay_entry.dart';

typedef SuperOverlayStyleBuilder = Widget Function(Widget child);

class SuperOverlayInit extends StatefulWidget {
  const SuperOverlayInit({super.key, required this.child, this.styleBuilder});

  final Widget? child;
  final SuperOverlayStyleBuilder? styleBuilder;

  static final NavigatorObserver observer = SuperOverlayObserver();

  static TransitionBuilder init({
    TransitionBuilder? builder,
    SuperOverlayStyleBuilder? styleBuilder,
  }) {
    return (context, child) {
      final overlay = SuperOverlayInit(
        styleBuilder: styleBuilder,
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
    _appEntry = SuperOverlayEntry(
      builder: (context) {
        OverlayManager.instance.captureContexts(context);
        return widget.child ?? const SizedBox.shrink();
      },
    );
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
