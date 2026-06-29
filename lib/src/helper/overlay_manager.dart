import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../config/enum_config.dart';
import '../custom/custom_loading.dart';
import '../custom/custom_overlay.dart';
import '../custom/toast_tool.dart';
import '../data/show_param.dart';
import '../kit/debounce_utils.dart';
import '../kit/super_overlay_entry.dart';
import '../kit/view_utils.dart';

enum OverlayCloseType { normal, mask, route, back }

class OverlayManager {
  OverlayManager._();

  static final OverlayManager instance = OverlayManager._();

  final Queue<_OverlayRecord> _dialogQueue = ListQueue<_OverlayRecord>();

  late SuperOverlayEntry entryLoading;
  late CustomLoading loadingOverlay;
  BuildContext? contextCustom;
  BuildContext? contextAttach;
  BuildContext? contextNotify;
  BuildContext? contextToast;

  var _nextTagId = 0;

  void initialize() {
    _dialogQueue.clear();
    ToastTool.instance.reset();
    DebounceUtils.instance.reset();
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
    );
  }

  CustomPushResult _pushDialog({
    required CustomOverlay overlay,
    required OverlayType type,
    required String? tag,
    required bool keepSingle,
    required bool permanent,
    required Duration? displayTime,
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
      return _dialogQueue.any((record) => record.tag == tag);
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
    return false;
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
}

class _OverlayRecord {
  _OverlayRecord({
    required this.overlay,
    required this.type,
    required this.tag,
    required this.permanent,
  });

  final CustomOverlay overlay;
  final OverlayType type;
  final String tag;
  bool permanent;
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
