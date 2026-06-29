import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../config/enum_config.dart';
import '../custom/custom_overlay.dart';
import '../data/show_param.dart';
import '../kit/super_overlay_entry.dart';
import '../kit/view_utils.dart';

enum OverlayCloseType { normal, mask, route, back }

class OverlayManager {
  OverlayManager._();

  static final OverlayManager instance = OverlayManager._();

  final Queue<_OverlayRecord> _dialogQueue = ListQueue<_OverlayRecord>();

  late SuperOverlayEntry entryLoading;
  BuildContext? contextCustom;
  BuildContext? contextAttach;
  BuildContext? contextNotify;
  BuildContext? contextToast;

  var _nextTagId = 0;

  void initialize() {
    _dialogQueue.clear();
    _nextTagId = 0;
    entryLoading = SuperOverlayEntry(builder: (_) => const SizedBox.shrink());
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

  CustomPushResult pushCustom(CustomOverlay overlay, ShowCustomParam param) {
    final overlayContext = contextCustom;
    if (overlayContext == null) {
      throw StateError(
        'SuperOverlay is not initialized. Use SuperOverlayInit.init() in MaterialApp.builder.',
      );
    }

    final tag = param.keepSingle
        ? param.tag ?? '_super_overlay_keep_single'
        : param.tag ?? '_super_overlay_${_nextTagId++}';

    if (param.keepSingle) {
      final existing = _findRecord(
        type: OverlayType.custom,
        tag: tag,
        force: true,
      );
      if (existing != null) {
        existing.permanent = param.permanent;
        _scheduleDisplayTimer(existing, param.displayTime);
        return CustomPushResult(
          tag: existing.tag,
          overlay: existing.overlay,
          reused: true,
        );
      }
    }

    final record = _OverlayRecord(
      overlay: overlay,
      type: OverlayType.custom,
      tag: tag,
      permanent: param.permanent,
    );
    _dialogQueue.addLast(record);
    _scheduleDisplayTimer(record, param.displayTime);

    ViewUtils.addSafeUse(() {
      overlayOf(
        overlayContext,
      ).insert(overlay.overlayEntry, below: entryLoading);
    });
    return CustomPushResult(tag: tag, overlay: overlay, reused: false);
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
    return _dialogQueue.any((record) => types.contains(record.type));
  }

  Future<void> dismiss<T>({
    DismissStatus status = DismissStatus.auto,
    String? tag,
    T? result,
    bool force = false,
    OverlayCloseType closeType = OverlayCloseType.normal,
  }) async {
    if (status == DismissStatus.auto ||
        status == DismissStatus.custom ||
        status == DismissStatus.dialog) {
      await _closeSingle<T>(
        tag: tag,
        result: result,
        force: force,
        type: OverlayType.custom,
        closeType: closeType,
      );
      return;
    }

    if (status == DismissStatus.allCustom ||
        status == DismissStatus.allDialog) {
      await _closeAll<T>(
        result: result,
        force: force,
        type: OverlayType.custom,
        closeType: closeType,
      );
    }
  }

  Future<void> _closeAll<T>({
    required T? result,
    required bool force,
    required OverlayType type,
    required OverlayCloseType closeType,
  }) async {
    while (_dialogQueue.any((record) => record.type == type)) {
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
    required OverlayType type,
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
      dismiss<void>(status: DismissStatus.custom, tag: record.tag);
    });
  }

  _OverlayRecord? _findRecord({
    required OverlayType type,
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
        if (record.tag == tag) {
          return record;
        }
      }
      return null;
    }

    if (force) {
      for (var index = records.length - 1; index >= 0; index--) {
        final record = records[index];
        if (record.permanent && record.type == type) {
          return record;
        }
      }
    }

    for (var index = records.length - 1; index >= 0; index--) {
      final record = records[index];
      if (record.type == type) {
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
