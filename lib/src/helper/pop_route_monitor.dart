import 'package:flutter/widgets.dart';

import '../kit/view_utils.dart';
import 'overlay_manager.dart';

class PopRouteMonitor with WidgetsBindingObserver {
  PopRouteMonitor._();

  static final PopRouteMonitor instance = PopRouteMonitor._();

  bool _registered = false;

  void ensureRegistered() {
    if (_registered) {
      return;
    }
    widgetsBinding.addObserver(this);
    _registered = true;
  }

  @override
  Future<bool> didPopRoute() {
    return handleBackEvent();
  }

  Future<bool> handleBackEvent() {
    return OverlayManager.instance.handleBackEvent();
  }
}
