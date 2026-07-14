import 'package:flutter/material.dart';

import 'helper/monitor_widget_helper.dart';
import 'helper/navigator_scope_registry.dart';
import 'helper/overlay_host_lease.dart';
import 'kit/super_overlay_entry.dart';
import 'kit/typedef.dart';
import 'data/notify_style.dart';

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
  late SuperOverlayEntry _appEntry;
  late OverlayHostLease _hostLease;

  @override
  void initState() {
    super.initState();
    _hostLease = _acquireLease(widget);
    MonitorWidgetHelper.instance.ensureRegistered();
    _appEntry = _createAppEntry(_hostLease, widget.ownerIdentity);
  }

  OverlayHostLease _acquireLease(SuperOverlayInit configuration) {
    return OverlayHostLease.acquire(
      ownerIdentity: configuration.ownerIdentity,
      toastBuilder: configuration.toastBuilder,
      loadingBuilder: configuration.loadingBuilder,
      notifyStyle: configuration.notifyStyle,
    );
  }

  SuperOverlayEntry _createAppEntry(
    OverlayHostLease lease,
    Object ownerIdentity,
  ) {
    return SuperOverlayEntry(
      builder: (context) {
        lease.captureContexts(ownerIdentity: ownerIdentity, context: context);
        return widget.child ?? const SizedBox.shrink();
      },
    );
  }

  @override
  void didUpdateWidget(covariant SuperOverlayInit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.ownerIdentity, widget.ownerIdentity)) {
      final oldLease = _hostLease;
      _hostLease = _acquireLease(widget);
      _appEntry = _createAppEntry(_hostLease, widget.ownerIdentity);
      NavigatorScopeRegistry.instance.transferRootRoutes(
        fromOwnerIdentity: oldWidget.ownerIdentity,
        fromGeneration: oldLease.generation,
        toOwnerIdentity: widget.ownerIdentity,
        toGeneration: _hostLease.generation,
      );
      _scheduleObserverAttachmentCheck();
      oldLease.dispose(ownerIdentity: oldWidget.ownerIdentity);
      return;
    }
    if (oldWidget.toastBuilder != widget.toastBuilder ||
        oldWidget.loadingBuilder != widget.loadingBuilder ||
        oldWidget.notifyStyle != widget.notifyStyle) {
      _hostLease.updateDefaults(
        ownerIdentity: widget.ownerIdentity,
        toastBuilder: widget.toastBuilder,
        loadingBuilder: widget.loadingBuilder,
        notifyStyle: widget.notifyStyle,
      );
    }
    _scheduleObserverAttachmentCheck();
  }

  void _scheduleObserverAttachmentCheck() {
    final ownerIdentity = widget.ownerIdentity;
    final generation = _hostLease.generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavigatorScopeRegistry.instance.pruneDetachedRoot(
        ownerIdentity: ownerIdentity,
        generation: generation,
      );
    });
  }

  @override
  void dispose() {
    _hostLease.dispose(ownerIdentity: widget.ownerIdentity);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overlay = Overlay(
      key: ObjectKey(_hostLease),
      initialEntries: [_appEntry, _hostLease.entryLoading],
    );
    final content =
        widget.styleBuilder?.call(overlay) ??
        Material(color: Colors.transparent, child: overlay);
    return FocusScope(
      debugLabel: 'SuperOverlay host focus scope',
      child: content,
    );
  }
}
