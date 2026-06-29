import '../kit/view_utils.dart';
import 'overlay_manager.dart';

class MonitorWidgetHelper {
  MonitorWidgetHelper._();

  static final MonitorWidgetHelper instance = MonitorWidgetHelper._();

  bool _registered = false;
  bool _checking = false;

  void ensureRegistered() {
    if (_registered) {
      return;
    }
    schedulerBinding.addPersistentFrameCallback(_handleFrame);
    _registered = true;
  }

  void _handleFrame(Duration timeStamp) {
    if (_checking || !OverlayManager.instance.hasWidgetBoundOverlays) {
      return;
    }

    _checking = true;
    try {
      OverlayManager.instance.handleWidgetBindingFrame();
    } finally {
      _checking = false;
    }
  }
}
