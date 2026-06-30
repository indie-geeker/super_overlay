import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';
import 'package:super_overlay/src/widget/highlight_mask.dart';

part 'super_overlay_custom_cases.dart';
part 'super_overlay_feedback_cases.dart';
part 'super_overlay_popup_geometry_cases.dart';
part 'super_overlay_popup_dismiss_cases.dart';
part 'super_overlay_notify_cases.dart';
part 'super_overlay_route_cases.dart';
part 'super_overlay_back_cases.dart';
part 'super_overlay_widget_binding_cases.dart';

Widget buildApp(Widget child) {
  return MaterialApp(
    builder: SuperOverlayInit.init(),
    navigatorObservers: [SuperOverlayInit.observer],
    home: Scaffold(body: child),
  );
}

Future<bool> dispatchSystemBack(WidgetTester tester) async {
  final handled = await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  return handled;
}

void main() {
  registerCustomOverlayTests();
  registerFeedbackOverlayTests();
  registerPopupGeometryTests();
  registerPopupDismissTests();
  registerNotifyOverlayTests();
  registerRouteOverlayTests();
  registerBackOverlayTests();
  registerWidgetBindingTests();
}
