part of 'overlay_manager.dart';

class _OverlayRecord {
  _OverlayRecord({
    required this.overlay,
    required this.type,
    required this.tag,
    required this.permanent,
    required this.route,
    required this.bindPage,
    required this.bindWidget,
    required this.backType,
    required this.onBack,
  });

  final CustomOverlay overlay;
  final OverlayType type;
  final String tag;
  final Route<dynamic>? route;
  final bool bindPage;
  final BuildContext? bindWidget;
  final BackType backType;
  final SuperOverlayOnBack? onBack;
  bool permanent;
  Timer? displayTimer;
}

class _NotifyRecord {
  _NotifyRecord({
    required this.overlay,
    required this.tag,
    required this.backType,
    required this.onBack,
  });

  final CustomNotify overlay;
  final String tag;
  final BackType backType;
  final SuperOverlayOnBack? onBack;
  Timer? displayTimer;
}

class CustomPushResult {
  const CustomPushResult({
    required this.tag,
    required this.overlay,
    required this.reused,
  });

  final String tag;
  final CustomOverlay overlay;
  final bool reused;
}

class NotifyPushResult {
  const NotifyPushResult({
    required this.tag,
    required this.overlay,
    required this.reused,
  });

  final String tag;
  final CustomNotify overlay;
  final bool reused;
}
