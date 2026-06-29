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

  Future<void> showToast({required ShowToastParam param}) async {
    ToastTool.instance.show(param);
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

  Future<bool> handleBackEvent() async {
    if (loadingOverlay.isVisible) {
      final handled = await _handleBackConfig(
        backType: loadingOverlay.backType,
        onBack: loadingOverlay.onBack,
        close: () => dismiss<void>(
          status: DismissStatus.loading,
          closeType: OverlayCloseType.back,
        ),
      );
      if (handled != null) {
        return handled;
      }
    }

    final notifyRecords = _notifyQueue.toList(growable: false);
    for (var index = notifyRecords.length - 1; index >= 0; index--) {
      final record = notifyRecords[index];
      final handled = await _handleBackConfig(
        backType: record.backType,
        onBack: record.onBack,
        close: () => dismiss<void>(
          status: DismissStatus.notify,
          tag: record.tag,
          closeType: OverlayCloseType.back,
        ),
      );
      if (handled != null) {
        return handled;
      }
    }

    final record = _lastBackRecord();
    if (record == null) {
      return false;
    }

    final handled = await _handleBackConfig(
      backType: record.backType,
      onBack: record.onBack,
      close: () => dismiss<void>(
        status: record.type == OverlayType.attach
            ? DismissStatus.attach
            : DismissStatus.custom,
        tag: record.tag,
        closeType: OverlayCloseType.back,
      ),
    );
    return handled ?? false;
  }

  void handleWidgetBindingFrame() {
    final removeList = <_OverlayRecord>[];
    for (final record in _dialogQueue.toList(growable: false)) {
      final context = record.bindWidget;
      if (context == null) {
        continue;
      }

      if (!_isContextMounted(context)) {
        removeList.add(record);
        continue;
      }

      if (!_isRecordOnCurrentRoute(record)) {
        record.overlay.hide();
        continue;
      }

      final renderBox = _safeRenderBox(context);
      if (renderBox == null || _hasInvalidGeometry(renderBox)) {
        record.overlay.hide();
      } else {
        record.overlay.appear();
      }
    }

    for (final record in removeList.reversed) {
      unawaited(
        _closeSingle<void>(
          tag: record.tag,
          result: null,
          force: true,
          type: record.type,
          closeType: OverlayCloseType.normal,
        ),
      );
    }
  }

  Future<void> dismiss<T>({
    DismissStatus status = DismissStatus.auto,
    String? tag,
    T? result,
    bool force = false,
    OverlayCloseType closeType = OverlayCloseType.normal,
  }) async {
    if (status == DismissStatus.auto) {
      if (loadingOverlay.isVisible && (tag == null || _dialogQueue.isEmpty)) {
        await loadingOverlay.dismiss(closeType: closeType);
        return;
      }
      if (_notifyQueue.isNotEmpty) {
        await _closeNotify<T>(tag: tag, result: result, closeType: closeType);
        return;
      }
      await _closeSingle<T>(
        tag: tag,
        result: result,
        force: force,
        type: null,
        closeType: closeType,
      );
      return;
    }

    if (status == DismissStatus.custom ||
        status == DismissStatus.attach ||
        status == DismissStatus.dialog) {
      await _closeSingle<T>(
        tag: tag,
        result: result,
        force: force,
        type: switch (status) {
          DismissStatus.custom => OverlayType.custom,
          DismissStatus.attach => OverlayType.attach,
          _ => null,
        },
        closeType: closeType,
      );
      return;
    }

    if (status == DismissStatus.allCustom ||
        status == DismissStatus.allAttach ||
        status == DismissStatus.allDialog) {
      await _closeAll<T>(
        result: result,
        force: force,
        type: switch (status) {
          DismissStatus.allCustom => OverlayType.custom,
          DismissStatus.allAttach => OverlayType.attach,
          _ => null,
        },
        closeType: closeType,
      );
      return;
    }

    if (status == DismissStatus.notify) {
      await _closeNotify<T>(tag: tag, result: result, closeType: closeType);
      return;
    }

    if (status == DismissStatus.allNotify) {
      while (_notifyQueue.isNotEmpty) {
        await _closeNotify<T>(result: result, closeType: closeType);
      }
      return;
    }

    if (status == DismissStatus.loading) {
      await loadingOverlay.dismiss(closeType: closeType);
      return;
    }

    if (status == DismissStatus.toast) {
      await ToastTool.instance.dismiss();
      return;
    }

    if (status == DismissStatus.allToast) {
      await ToastTool.instance.dismiss(closeAll: true);
    }
  }

  Future<void> _closeAll<T>({
    required T? result,
    required bool force,
    required OverlayType? type,
    required OverlayCloseType closeType,
  }) async {
    while (_dialogQueue.any((record) => type == null || record.type == type)) {
      await _closeSingle<T>(
        result: result,
        force: force,
        type: type,
        closeType: closeType,
      );
    }
  }

  Future<void> _closeSingle<T>({
    required T? result,
    required bool force,
    required OverlayType? type,
    required OverlayCloseType closeType,
    String? tag,
  }) async {
    final record = _findRecord(type: type, tag: tag, force: force);
    if (record == null || (record.permanent && !force)) {
      return;
    }

    _dialogQueue.remove(record);
    record.displayTimer?.cancel();
    await record.overlay.dismiss<T>(result: result, closeType: closeType);
    record.overlay.overlayEntry.remove();
  }

  void _scheduleDisplayTimer(_OverlayRecord record, Duration? displayTime) {
    record.displayTimer?.cancel();
    if (displayTime == null) {
      record.displayTimer = null;
      return;
    }
    record.displayTimer = Timer(displayTime, () {
      dismiss<void>(
        status: record.type == OverlayType.attach
            ? DismissStatus.attach
            : DismissStatus.custom,
        tag: record.tag,
      );
    });
  }

  void _scheduleNotifyTimer(_NotifyRecord record, Duration? displayTime) {
    record.displayTimer?.cancel();
    if (displayTime == null) {
      record.displayTimer = null;
      return;
    }
    record.displayTimer = Timer(displayTime, () {
      dismiss<void>(status: DismissStatus.notify, tag: record.tag);
    });
  }

  Future<void> _closeNotify<T>({
    String? tag,
    T? result,
    OverlayCloseType closeType = OverlayCloseType.normal,
  }) async {
    final record = _findNotify(tag: tag);
    if (record == null) {
      return;
    }

    _notifyQueue.remove(record);
    record.displayTimer?.cancel();
    await record.overlay.dismiss<T>(result: result, closeType: closeType);
    record.overlay.overlayEntry.remove();
  }

  _NotifyRecord? _findNotify({String? tag}) {
    if (_notifyQueue.isEmpty) {
      return null;
    }
    final records = _notifyQueue.toList(growable: false);
    if (tag != null) {
      for (var index = records.length - 1; index >= 0; index--) {
        if (records[index].tag == tag) {
          return records[index];
        }
      }
      return null;
    }
    return records.last;
  }

  _OverlayRecord? _findRecord({
    required OverlayType? type,
    required String? tag,
    required bool force,
  }) {
    if (_dialogQueue.isEmpty) {
      return null;
    }

    final records = _dialogQueue.toList(growable: false);
    if (tag != null) {
      for (var index = records.length - 1; index >= 0; index--) {
        final record = records[index];
        if (record.tag == tag && (type == null || record.type == type)) {
          return record;
        }
      }
      return null;
    }

    if (force) {
      for (var index = records.length - 1; index >= 0; index--) {
        final record = records[index];
        if (record.permanent && (type == null || record.type == type)) {
          return record;
        }
      }
    }

    for (var index = records.length - 1; index >= 0; index--) {
      final record = records[index];
      if (type == null || record.type == type) {
        return record;
      }
    }
    return null;
  }

  bool _isRouteBoundRecord(_OverlayRecord record, Route<dynamic> route) {
    return record.bindPage &&
        identical(record.route, route) &&
        record.route is! PopupRoute;
  }

  bool _isRecordOnCurrentRoute(_OverlayRecord record) {
    final currentRoute = RouteRecord.instance.currentRoute;
    return currentRoute == null ||
        identical(record.route, currentRoute) ||
        currentRoute is PopupRoute ||
        !record.bindPage;
  }

  _OverlayRecord? _lastBackRecord() {
    final records = _dialogQueue.toList(growable: false);
    for (var index = records.length - 1; index >= 0; index--) {
      final record = records[index];
      if (record.permanent || !record.overlay.mainOverlay.visible) {
        continue;
      }
      return record;
    }
    return null;
  }

  Future<bool?> _handleBackConfig({
    required BackType backType,
    required SuperOverlayOnBack? onBack,
    required Future<void> Function() close,
  }) async {
    if (await onBack?.call() == true) {
      return true;
    }

    return switch (backType) {
      BackType.normal => () async {
        await close();
        return true;
      }(),
      BackType.block => true,
      BackType.ignore => null,
    };
  }

  bool _isContextMounted(BuildContext context) {
    if (context is Element) {
      return context.mounted;
    }
    return true;
  }

  RenderBox? _safeRenderBox(BuildContext context) {
    try {
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox &&
          renderObject.attached &&
          renderObject.hasSize) {
        return renderObject;
      }
    } catch (_) {}
    return null;
  }

  bool _hasInvalidGeometry(RenderBox renderBox) {
    try {
      final offset = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      return size.isEmpty ||
          offset.dx < 0 ||
          offset.dy < 0 ||
          offset.dx.isNaN ||
          offset.dy.isNaN ||
          offset.dx.isInfinite ||
          offset.dy.isInfinite;
    } catch (_) {
      return true;
    }
  }
}

class _OverlayRecord {
  _OverlayRecord({
    required this.overlay,
    required this.type,
    required this.tag,
    required this.permanent,
    required this.route,
    required this.bindPage,
    required this.bindWidget,
    required this.backType,
    required this.onBack,
  });

  final CustomOverlay overlay;
  final OverlayType type;
  final String tag;
  final Route<dynamic>? route;
  final bool bindPage;
  final BuildContext? bindWidget;
  final BackType backType;
  final SuperOverlayOnBack? onBack;
  bool permanent;
  Timer? displayTimer;
}

class _NotifyRecord {
  _NotifyRecord({
    required this.overlay,
    required this.tag,
    required this.backType,
    required this.onBack,
  });

  final CustomNotify overlay;
  final String tag;
  final BackType backType;
  final SuperOverlayOnBack? onBack;
  Timer? displayTimer;
}

class CustomPushResult {
  const CustomPushResult({
    required this.tag,
    required this.overlay,
    required this.reused,
  });

  final String tag;
  final CustomOverlay overlay;
  final bool reused;
}

class NotifyPushResult {
  const NotifyPushResult({
    required this.tag,
    required this.overlay,
    required this.reused,
  });

  final String tag;
  final CustomNotify overlay;
  final bool reused;
}
