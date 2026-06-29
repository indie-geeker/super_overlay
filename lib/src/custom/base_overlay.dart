import 'package:flutter/widgets.dart';

import '../kit/super_overlay_entry.dart';
import 'main_overlay.dart';

class BaseOverlay {
  BaseOverlay(this.overlayEntry)
    : mainOverlay = MainOverlay(overlayEntry: overlayEntry);

  final SuperOverlayEntry overlayEntry;
  MainOverlay mainOverlay;

  Widget getWidget() => mainOverlay.getWidget();

  void appear() {
    if (mainOverlay.visible) {
      return;
    }
    mainOverlay.visible = true;
    overlayEntry.markNeedsBuild();
  }

  void hide() {
    if (!mainOverlay.visible) {
      return;
    }
    mainOverlay.visible = false;
    overlayEntry.markNeedsBuild();
  }
}
