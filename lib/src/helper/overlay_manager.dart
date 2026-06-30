import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../config/enum_config.dart';
import '../custom/custom_loading.dart';
import '../custom/custom_notify.dart';
import '../custom/custom_overlay.dart';
import '../custom/toast_tool.dart';
import '../data/show_param.dart';
import '../kit/debounce_utils.dart';
import '../kit/super_overlay_entry.dart';
import '../kit/typedef.dart';
import '../kit/view_utils.dart';
import 'route_record.dart';

part 'overlay_manager_dismiss.dart';
part 'overlay_manager_lifecycle.dart';
part 'overlay_manager_lookup.dart';
part 'overlay_manager_models.dart';

enum OverlayCloseType { normal, mask, route, back }

class OverlayManager {
  OverlayManager._();

  static final OverlayManager instance = OverlayManager._();

  final Queue<_OverlayRecord> _dialogQueue = ListQueue<_OverlayRecord>();
  final Queue<_NotifyRecord> _notifyQueue = ListQueue<_NotifyRecord>();

  late SuperOverlayEntry entryLoading;
  late CustomLoading loadingOverlay;
  BuildContext? contextCustom;
  BuildContext? contextAttach;
  BuildContext? contextNotify;
  BuildContext? contextToast;

  var _nextTagId = 0;

  void initialize() {
    for (final record in _dialogQueue) {
      record.displayTimer?.cancel();
      record.overlay.overlayEntry.remove();
    }
    for (final record in _notifyQueue) {
      record.displayTimer?.cancel();
      record.overlay.overlayEntry.remove();
    }
    _dialogQueue.clear();
    _notifyQueue.clear();
    ToastTool.instance.reset();
    DebounceUtils.instance.reset();
    RouteRecord.instance.reset();
    _nextTagId = 0;
    CustomLoading? loading;
    entryLoading = SuperOverlayEntry(builder: (_) => loading!.getWidget());
    loading = CustomLoading(overlayEntry: entryLoading);
    loadingOverlay = loading;
  }

  void captureContexts(BuildContext context) {
    contextCustom = context;
    contextAttach = context;
    contextNotify = context;
    contextToast = context;
  }

  Future<T?> show<T>({required ShowCustomParam param}) {
    CustomOverlay? overlay;
    final entry = SuperOverlayEntry(builder: (_) => overlay!.getWidget());
    overlay = CustomOverlay(overlayEntry: entry);
    return overlay.show<T>(param: param);
  }

  Future<T?> showAttach<T>({required ShowAttachParam param}) {
    CustomOverlay? overlay;
    final entry = SuperOverlayEntry(builder: (_) => overlay!.getWidget());
    overlay = CustomOverlay(overlayEntry: entry);
    return overlay.showAttach<T>(param: param);
  }

  Future<T?> showLoading<T>({required ShowLoadingParam param}) {
    return loadingOverlay.showLoading<T>(param: param);
  }

  Future<T?> showNotify<T>({required ShowNotifyParam param}) {
    CustomNotify? notify;
    final entry = SuperOverlayEntry(builder: (_) => notify!.getWidget());
    notify = CustomNotify(overlayEntry: entry);
    return notify.showNotify<T>(param: param);
  }

  Future<T?> showToast<T>({required ShowToastParam param}) {
    return ToastTool.instance.show<T>(param);
  }

  CustomPushResult pushCustom(CustomOverlay overlay, ShowCustomParam param) {
    return _pushDialog(
      overlay: overlay,
      type: OverlayType.custom,
      tag: param.tag,
      keepSingle: param.keepSingle,
      permanent: param.permanent,
      displayTime: param.displayTime,
      bindPage: param.bindPage,
      bindWidget: param.bindWidget,
      backType: param.backType,
      onBack: param.onBack,
    );
  }

  CustomPushResult pushAttach(CustomOverlay overlay, ShowAttachParam param) {
    return _pushDialog(
      overlay: overlay,
      type: OverlayType.attach,
      tag: param.tag,
      keepSingle: param.keepSingle,
      permanent: param.permanent,
      displayTime: param.displayTime,
      bindPage: param.bindPage,
      bindWidget: param.bindWidget,
      backType: param.backType,
      onBack: param.onBack,
    );
  }

  NotifyPushResult pushNotify(CustomNotify notify, ShowNotifyParam param) {
    final overlayContext = contextNotify ?? contextCustom;
    if (overlayContext == null) {
      throw StateError(
        'SuperOverlay is not initialized. Use SuperOverlayInit.init() in MaterialApp.builder.',
      );
    }

    final tag = param.keepSingle
        ? param.tag ?? '_super_overlay_notify_keep_single'
        : param.tag ?? '_super_overlay_notify_${_nextTagId++}';

    if (param.keepSingle) {
      final existing = _findNotify(tag: tag);
      if (existing != null) {
        _scheduleNotifyTimer(existing, param.displayTime);
        return NotifyPushResult(
          tag: existing.tag,
          overlay: existing.overlay,
          reused: true,
        );
      }
    }

    final record = _NotifyRecord(
      overlay: notify,
      tag: tag,
      backType: param.backType,
      onBack: param.onBack,
    );
    _notifyQueue.addLast(record);
    _scheduleNotifyTimer(record, param.displayTime);
    ViewUtils.addSafeUse(() {
      overlayOf(
        overlayContext,
      ).insert(notify.overlayEntry, below: entryLoading);
    });
    return NotifyPushResult(tag: tag, overlay: notify, reused: false);
  }

  CustomPushResult _pushDialog({
    required CustomOverlay overlay,
    required OverlayType type,
    required String? tag,
    required bool keepSingle,
    required bool permanent,
    required Duration? displayTime,
    required bool bindPage,
    required BuildContext? bindWidget,
    required BackType backType,
    required SuperOverlayOnBack? onBack,
  }) {
    final overlayContext = type == OverlayType.attach
        ? contextAttach ?? contextCustom
        : contextCustom;
    if (overlayContext == null) {
      throw StateError(
        'SuperOverlay is not initialized. Use SuperOverlayInit.init() in MaterialApp.builder.',
      );
    }

    final effectiveTag = keepSingle
        ? tag ?? '_super_overlay_keep_single'
        : tag ?? '_super_overlay_${_nextTagId++}';

    if (keepSingle) {
      final existing = _findRecord(type: type, tag: effectiveTag, force: true);
      if (existing != null) {
        existing.permanent = permanent;
        _scheduleDisplayTimer(existing, displayTime);
        return CustomPushResult(
          tag: existing.tag,
          overlay: existing.overlay,
          reused: true,
        );
      }
    }

    final record = _OverlayRecord(
      overlay: overlay,
      type: type,
      tag: effectiveTag,
      permanent: permanent,
      route: RouteRecord.instance.currentRoute,
      bindPage: bindPage,
      bindWidget: bindWidget,
      backType: backType,
      onBack: onBack,
    );
    _dialogQueue.addLast(record);
    _scheduleDisplayTimer(record, displayTime);

    ViewUtils.addSafeUse(() {
      overlayOf(
        overlayContext,
      ).insert(overlay.overlayEntry, below: entryLoading);
    });
    return CustomPushResult(tag: effectiveTag, overlay: overlay, reused: false);
  }

  bool checkExist({
    String? tag,
    Set<OverlayType> types = const {
      OverlayType.custom,
      OverlayType.attach,
      OverlayType.loading,
      OverlayType.notify,
      OverlayType.toast,
    },
  }) {
    if (tag != null) {
      return _dialogQueue.any((record) => record.tag == tag) ||
          _notifyQueue.any((record) => record.tag == tag);
    }
    if (_dialogQueue.any((record) => types.contains(record.type))) {
      return true;
    }
    if (types.contains(OverlayType.loading) && loadingOverlay.isVisible) {
      return true;
    }
    if (types.contains(OverlayType.toast) && ToastTool.instance.isExist) {
      return true;
    }
    if (types.contains(OverlayType.notify) && _notifyQueue.isNotEmpty) {
      return true;
    }
    return false;
  }

  bool get hasWidgetBoundOverlays {
    return _dialogQueue.any((record) => record.bindWidget != null);
  }

  void handleRoutePushed({
    required Route<dynamic> route,
    required Route<dynamic>? previousRoute,
  }) {
    if (route is PopupRoute || previousRoute == null) {
      return;
    }

    for (final record in _dialogQueue) {
      if (_isRouteBoundRecord(record, previousRoute)) {
        record.overlay.hide();
      }
    }
  }

  void handleRoutePopped({
    required Route<dynamic> route,
    required Route<dynamic>? previousRoute,
  }) {
    handleRouteRemoved(route);
    if (route is PopupRoute || previousRoute == null) {
      return;
    }

    for (final record in _dialogQueue) {
      if (_isRouteBoundRecord(record, previousRoute)) {
        record.overlay.appear();
      }
    }
  }

  void handleRouteRemoved(Route<dynamic> route) {
    if (route is PopupRoute) {
      return;
    }

    final removeList = _dialogQueue
        .where((record) => _isRouteBoundRecord(record, route))
        .toList(growable: false);
    for (final record in removeList.reversed) {
      unawaited(
        _closeSingle<void>(
          tag: record.tag,
          result: null,
          force: true,
          type: record.type,
          closeType: OverlayCloseType.route,
        ),
      );
    }
  }

  Future<bool> handleBackEvent() {
    return _handleBackEvent();
  }

  void handleWidgetBindingFrame() {
    _handleWidgetBindingFrame();
  }

  Future<void> dismiss<T>({
    DismissStatus status = DismissStatus.auto,
    String? tag,
    T? result,
    bool force = false,
    OverlayCloseType closeType = OverlayCloseType.normal,
  }) {
    return _dismiss<T>(
      status: status,
      tag: tag,
      result: result,
      force: force,
      closeType: closeType,
    );
  }
}
