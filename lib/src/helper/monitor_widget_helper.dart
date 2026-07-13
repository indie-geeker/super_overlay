import '../kit/view_utils.dart';
import 'overlay_manager.dart';

class MonitorWidgetHelper {
  MonitorWidgetHelper._();

  static final MonitorWidgetHelper instance = MonitorWidgetHelper._();

  bool _registered = false;
  bool _checking = false;
  bool _scheduled = false;

  void ensureRegistered() {
    if (_registered) {
      return;
    }
    schedulerBinding.addPersistentFrameCallback(_handleFrame);
    _registered = true;
  }

  void _handleFrame(Duration timeStamp) {
    if (_checking ||
        _scheduled ||
        !OverlayManager.instance.hasMonitoredOverlays) {
      return;
    }

    _scheduled = true;
    widgetsBinding.addPostFrameCallback((_) {
      _scheduled = false;
      if (_checking || !OverlayManager.instance.hasMonitoredOverlays) {
        return;
      }

      _checking = true;
      try {
        OverlayManager.instance.handleWidgetBindingFrame();
      } finally {
        _checking = false;
      }
    });
  }
}
