import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_overlay/super_overlay.dart';

import 'super_overlay_custom_cases.dart' as custom_cases;
import 'super_overlay_feedback_cases.dart' as feedback_cases;
import 'super_overlay_notify_cases.dart' as notify_cases;
import 'super_overlay_popup_dismiss_cases.dart' as popup_dismiss;
import 'super_overlay_popup_geometry_cases.dart' as popup_geometry;

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
  custom_cases.registerCustomOverlayTests();
  feedback_cases.registerFeedbackOverlayTests();
  popup_geometry.registerPopupGeometryTests();
  popup_dismiss.registerPopupDismissTests();
  notify_cases.registerNotifyOverlayTests();
  registerRouteOverlayTests();
  registerBackOverlayTests();
  registerWidgetBindingTests();
}
