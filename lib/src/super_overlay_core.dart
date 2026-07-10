import 'dart:async';

import 'package:flutter/material.dart';

import 'api/overlay_handle.dart';
import 'api/overlay_options.dart';
import 'api/overlay_policy.dart';
import 'config/enum_config.dart';
import 'config/overlay_config.dart';
import 'custom/toast_tool.dart';
import 'data/notify_style.dart';
import 'data/show_param.dart';
import 'helper/overlay_manager.dart';
import 'init_overlay.dart';
import 'kit/overlay_controller.dart';
import 'kit/overlay_runtime_result.dart';
import 'kit/typedef.dart';
import 'widget/default/loading_widget.dart';
import 'widget/default/notify_alert.dart';
import 'widget/default/notify_error.dart';
import 'widget/default/notify_failure.dart';
import 'widget/default/notify_success.dart';
import 'widget/default/notify_warning.dart';
import 'widget/default/toast_widget.dart';

part 'builder/super_custom_overlay_builder.dart';
part 'builder/super_loading_overlay_builder.dart';
part 'builder/super_notify_overlay_builder.dart';
part 'builder/super_popup_overlay_builder.dart';
part 'builder/super_toast_overlay_builder.dart';
part 'api/overlay_services.dart';

class SuperOverlay {
  static const _toastService = _OverlayToastService();

  static final OverlayLoadingService loading = OverlayLoadingService();
  static final OverlayDialogService dialog = OverlayDialogService();
  static final OverlayPopupService popup = OverlayPopupService();
  static final OverlayNotifyService notify = OverlayNotifyService();

  static NavigatorObserver get observer => SuperOverlayInit.observer;

  static TransitionBuilder init({
    TransitionBuilder? builder,
    SuperOverlayStyleBuilder? styleBuilder,
    SuperOverlayToastBuilder? toastBuilder,
    SuperOverlayLoadingBuilder? loadingBuilder,
    NotifyStyle? notifyStyle,
  }) {
    return SuperOverlayInit.init(
      builder: builder,
      styleBuilder: styleBuilder,
      toastBuilder: toastBuilder,
      loadingBuilder: loadingBuilder,
      notifyStyle: notifyStyle,
    );
  }

  static _SuperCustomOverlayBuilder _custom({required WidgetBuilder builder}) {
    return _SuperCustomOverlayBuilder(builder: builder);
  }

  static _SuperLoadingOverlayBuilder _loading({
    String message = '',
    WidgetBuilder? builder,
  }) {
    return _SuperLoadingOverlayBuilder(message: message, builder: builder);
  }

  static _SuperToastOverlayBuilder _toastCommand(
    String message, {
    WidgetBuilder? builder,
  }) {
    return _SuperToastOverlayBuilder(message: message, builder: builder);
  }

  /// Shows a toast message through the command API.
  ///
  /// When [builder] is provided, it renders this toast only and takes
  /// precedence over the default builder configured with
  /// `SuperOverlay.init(toastBuilder: ...)`.
  static OverlayHandle<void> toast(
    String message, {
    WidgetBuilder? builder,
    OverlayToastOptions options = const OverlayToastOptions(),
  }) {
    return _toastService.show(message, builder: builder, options: options);
  }

  static _SuperPopupOverlayBuilder _popup({
    BuildContext? targetContext,
    required WidgetBuilder builder,
  }) {
    return _SuperPopupOverlayBuilder(
      targetContext: targetContext,
      builder: builder,
    );
  }

  static _SuperNotifyOverlayBuilder _notification({
    required String message,
    required NotifyType type,
    WidgetBuilder? builder,
  }) {
    return _SuperNotifyOverlayBuilder(
      message: message,
      type: type,
      builder: builder,
    );
  }

  /// Closes overlays outside of a specific [OverlayHandle].
  ///
  /// Prefer `handle.close()` when the caller owns the overlay. Use this method
  /// for global commands such as clearing all toasts, closing a tagged dialog
  /// from inside its content, or cleaning up an overlay family in tests.
  static Future<void> close<T>({
    OverlayCloseTarget target = OverlayCloseTarget.topMost,
    String? tag,
    T? result,
    bool force = false,
  }) async {
    if (target == OverlayCloseTarget.all) {
      await _dismiss<T>(
        status: DismissStatus.loading,
        tag: tag,
        result: result,
        force: force,
      );
      await _dismiss<T>(
        status: DismissStatus.allNotify,
        tag: tag,
        result: result,
        force: force,
      );
      await _dismiss<T>(
        status: DismissStatus.allAttach,
        tag: tag,
        result: result,
        force: force,
      );
      await _dismiss<T>(
        status: DismissStatus.allCustom,
        tag: tag,
        result: result,
        force: force,
      );
      await _dismiss<T>(
        status: DismissStatus.allToast,
        tag: tag,
        result: result,
        force: force,
      );
      return;
    }

    return _dismiss<T>(
      status: _dismissStatusFor(target),
      tag: tag,
      result: result,
      force: force,
    );
  }

  /// Returns whether a matching overlay currently exists.
  static bool exists({
    String? tag,
    Set<OverlaySurface> surfaces = const {
      OverlaySurface.dialog,
      OverlaySurface.popup,
      OverlaySurface.loading,
      OverlaySurface.notification,
      OverlaySurface.toast,
    },
  }) {
    return _checkExistByTypes(
      tag: tag,
      types: surfaces.map(_overlayTypeFor).toSet(),
    );
  }

  static Future<void> _dismiss<T>({
    DismissStatus status = DismissStatus.auto,
    String? tag,
    T? result,
    bool force = false,
  }) {
    return OverlayManager.instance.dismiss<T>(
      status: status,
      tag: tag,
      result: result,
      force: force,
    );
  }

  static bool _checkExistByTypes({
    String? tag,
    Set<OverlayType> types = const {
      OverlayType.custom,
      OverlayType.attach,
      OverlayType.loading,
      OverlayType.notify,
      OverlayType.toast,
    },
  }) {
    return OverlayManager.instance.checkExist(tag: tag, types: types);
  }
}

DismissStatus _dismissStatusFor(OverlayCloseTarget target) {
  return switch (target) {
    OverlayCloseTarget.topMost => DismissStatus.auto,
    OverlayCloseTarget.dialog => DismissStatus.custom,
    OverlayCloseTarget.allDialogs => DismissStatus.allCustom,
    OverlayCloseTarget.popup => DismissStatus.attach,
    OverlayCloseTarget.allPopups => DismissStatus.allAttach,
    OverlayCloseTarget.notification => DismissStatus.notify,
    OverlayCloseTarget.allNotifications => DismissStatus.allNotify,
    OverlayCloseTarget.loading => DismissStatus.loading,
    OverlayCloseTarget.toast => DismissStatus.toast,
    OverlayCloseTarget.allToasts => DismissStatus.allToast,
    OverlayCloseTarget.all => DismissStatus.auto,
  };
}

OverlayType _overlayTypeFor(OverlaySurface surface) {
  return switch (surface) {
    OverlaySurface.dialog => OverlayType.custom,
    OverlaySurface.popup => OverlayType.attach,
    OverlaySurface.notification => OverlayType.notify,
    OverlaySurface.loading => OverlayType.loading,
    OverlaySurface.toast => OverlayType.toast,
  };
}
