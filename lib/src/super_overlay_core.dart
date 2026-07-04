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
  static final OverlayConfig config = OverlayConfig();
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

  static SuperCustomOverlayBuilder show({required WidgetBuilder builder}) {
    return SuperCustomOverlayBuilder(builder: builder);
  }

  static SuperLoadingOverlayBuilder showLoading({
    String msg = '',
    WidgetBuilder? builder,
  }) {
    return SuperLoadingOverlayBuilder(message: msg, builder: builder);
  }

  static SuperToastOverlayBuilder showToast(
    String message, {
    WidgetBuilder? builder,
  }) {
    return SuperToastOverlayBuilder(message: message, builder: builder);
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

  static SuperPopupOverlayBuilder showPopup({
    BuildContext? targetContext,
    required WidgetBuilder builder,
  }) {
    return SuperPopupOverlayBuilder(
      targetContext: targetContext,
      builder: builder,
    );
  }

  static SuperNotifyOverlayBuilder showNotify({
    required String msg,
    required NotifyType type,
    WidgetBuilder? builder,
  }) {
    return SuperNotifyOverlayBuilder(
      message: msg,
      type: type,
      builder: builder,
    );
  }

  static Future<void> dismiss<T>({
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

  static bool checkExist({
    String? tag,
    Set<OverlayType> dialogTypes = const {
      OverlayType.custom,
      OverlayType.attach,
      OverlayType.loading,
    },
  }) {
    return OverlayManager.instance.checkExist(tag: tag, types: dialogTypes);
  }
}
