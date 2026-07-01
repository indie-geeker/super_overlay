part of 'overlay_manager.dart';

extension _OverlayManagerDismiss on OverlayManager {
  Future<void> _dismiss<T>({
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
    final records = _dialogQueue
        .where((record) => type == null || record.type == type)
        .where((record) => force || !record.permanent)
        .toList(growable: false);

    for (final record in records.reversed) {
      await _closeSingle<T>(
        tag: record.tag,
        result: result,
        force: force,
        type: record.type,
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
}
