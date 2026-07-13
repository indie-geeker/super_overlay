part of 'overlay_manager.dart';

enum _OverlayHostTopology { empty, active, pending, conflict }

class _OverlayHostDefaults {
  const _OverlayHostDefaults({
    required this.toastBuilder,
    required this.loadingBuilder,
    required this.notifyStyle,
  });

  final SuperOverlayToastBuilder? toastBuilder;
  final SuperOverlayLoadingBuilder? loadingBuilder;
  final NotifyStyle? notifyStyle;
}

class _OverlayHostState {
  _OverlayHostState({
    required this.generation,
    required this.ownerIdentity,
    required this.defaults,
    required void Function() onBackDispositionChanged,
  }) {
    CustomLoading? loading;
    entryLoading = SuperOverlayEntry(builder: (_) => loading!.getWidget());
    loading = CustomLoading(
      overlayEntry: entryLoading,
      onBackDispositionChanged: onBackDispositionChanged,
    );
    loadingOverlay = loading;
  }

  final int generation;
  final Object ownerIdentity;
  _OverlayHostDefaults defaults;
  late final SuperOverlayEntry entryLoading;
  late final CustomLoading loadingOverlay;
  BuildContext? contextCustom;
  BuildContext? contextAttach;
  BuildContext? contextNotify;
  BuildContext? contextToast;
  final RouteRecord routeRecord = RouteRecord();
  Object? view;
  bool mounted = true;
  bool resourcesDisposed = false;

  void captureContexts(BuildContext context) {
    contextCustom = context;
    contextAttach = context;
    contextNotify = context;
    contextToast = context;
    view = View.maybeOf(context);
  }

  void disposeResources() {
    if (resourcesDisposed) {
      return;
    }
    resourcesDisposed = true;
    loadingOverlay.disposeHost();
    entryLoading.remove();
    contextCustom = null;
    contextAttach = null;
    contextNotify = null;
    contextToast = null;
    routeRecord.reset();
    view = null;
  }
}

class _OverlayRecord {
  _OverlayRecord({
    required this.generation,
    required this.overlay,
    required this.type,
    required this.tag,
    required this.businessTag,
    required this.permanent,
    required this.route,
    required this.bindPage,
    required this.bindWidget,
    required this.backType,
    required this.onBack,
  });

  final int generation;
  final CustomOverlay overlay;
  final OverlayType type;
  final String tag;
  final String? businessTag;
  final Route<dynamic>? route;
  final bool bindPage;
  final BuildContext? bindWidget;
  final BackType backType;
  final SuperOverlayOnBack? onBack;
  bool permanent;
  Timer? displayTimer;

  bool matchesTag(String value) => tag == value || businessTag == value;
}

class _NotifyRecord {
  _NotifyRecord({
    required this.generation,
    required this.overlay,
    required this.tag,
    required this.businessTag,
    required this.backType,
    required this.onBack,
  });

  final int generation;
  final CustomNotify overlay;
  final String tag;
  final String? businessTag;
  final BackType backType;
  final SuperOverlayOnBack? onBack;
  Timer? displayTimer;

  bool matchesTag(String value) => tag == value || businessTag == value;
}

class CustomPushResult {
  const CustomPushResult({
    required this.generation,
    required this.tag,
    required this.overlay,
    required this.reused,
  });

  final int generation;
  final String tag;
  final CustomOverlay overlay;
  final bool reused;
}

class NotifyPushResult {
  const NotifyPushResult({
    required this.generation,
    required this.tag,
    required this.overlay,
    required this.reused,
  });

  final int generation;
  final String tag;
  final CustomNotify overlay;
  final bool reused;
}
