import 'package:flutter/material.dart';
import 'super_overlay_builder.dart';
import 'super_overlay_config.dart';

class SuperOverlay {
  /// Global navigator key to enable context-less overlay presentation.
  /// Ensure you assign this to your [MaterialApp] or [CupertinoApp].
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Global configuration for default styles and behaviors.
  static final SuperOverlayConfig config = SuperOverlayConfig();

  static final Map<String, Route> _activeRoutes = {};
  static DateTime _lastShowTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Checks if the action should be debounced.
  static bool checkDebounce(bool? enable) {
    final shouldDebounce = enable ?? config.enableDebounce;
    if (!shouldDebounce) return true;
    final now = DateTime.now();
    if (now.difference(_lastShowTime) < config.debounceDuration) {
      return false; // Prevent show
    }
    _lastShowTime = now;
    return true;
  }

  @visibleForTesting
  static void resetDebounceTimer() {
    _lastShowTime = DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Registers a route with a tag for precise dismissal later.
  static void registerRoute(String tag, Route route) {
    _activeRoutes[tag] = route;
    route.popped.then((_) => _activeRoutes.remove(tag));
  }

  /// Dismisses a specific dialog by tag.
  /// If [tag] is null, pops the top route on the navigator normally.
  static void dismiss({String? tag, dynamic result}) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    if (tag != null) {
      final route = _activeRoutes[tag];
      if (route != null) {
        Navigator.of(context).removeRoute(route);
        _activeRoutes.remove(tag);
      }
    } else {
      Navigator.of(context).pop(result);
    }
  }

  /// Entry point to show a general custom dialog.
  /// Returns a builder to chain configurations.
  static SuperOverlayBuilder show({required Widget content, BuildContext? context}) {
    return SuperOverlayBuilder(content: content, context: context);
  }

  /// Shows a loading overlay. Defaults to not dismissible.
  static SuperOverlayBuilder showLoading({Widget? content, BuildContext? context}) {
    return SuperOverlayBuilder(
      content: Builder(builder: (ctx) {
        return content ?? config.defaultLoadingBuilder(ctx);
      }), 
      context: context
    ).withMask(dismissible: false);
  }

  /// Shows an ephemeral toast message. It does not block user interaction.
  static ToastBuilder showToast({required String msg, BuildContext? context}) {
    return ToastBuilder(msg: msg, context: context);
  }

  /// Shows a popup overlay attached to a specific target context.
  static PopupBuilder showPopup({
    required Widget content, 
    required BuildContext targetContext, 
    BuildContext? context
  }) {
    return PopupBuilder(content: content, targetContext: targetContext, context: context);
  }
}
